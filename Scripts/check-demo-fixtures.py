#!/usr/bin/env python3
"""Validate CoreTend's versioned, privacy-safe product demo fixture."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


EXPECTED_PUBLIC_MODULES = (
    "dashboard",
    "storage",
    "space-lens",
    "duplicates",
    "applications",
    "integrity",
    "activity",
    "settings",
)

HIDDEN_MODULES = {
    "smart-care",
    "performance",
    "my-clutter",
    "similar-images",
    "cloud-cleanup",
    "favorites-recents",
}

DASHBOARD_WORKFLOWS = {
    "storage",
    "space-lens",
    "duplicates",
    "applications",
    "integrity",
    "activity",
}

EMAIL_RE = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,63}\b", re.IGNORECASE)
USER_PATH_RE = re.compile(r"(?<![A-Za-z0-9_])/Users/([^/\s\"']+)")
SECRET_PATTERNS = (
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bghp_[A-Za-z0-9]{20,}\b"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"),
)
SENSITIVE_KEYS = {
    "apikey",
    "apitoken",
    "accesstoken",
    "authtoken",
    "clientsecret",
    "password",
    "passphrase",
    "privatekey",
    "refreshtoken",
    "secret",
    "token",
}
RETIRED_PREVIEW_KEYS = {
    "dryrun",
    "dryrunenabled",
    "dryrundefault",
    "simulatedfreedbytes",
}


class DuplicateKeyError(ValueError):
    pass


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_nonfinite_constant(value: str) -> None:
    raise ValueError(f"non-finite JSON number: {value}")


def load_fixture(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as fixture_file:
        return json.load(
            fixture_file,
            object_pairs_hook=_unique_object,
            parse_constant=_reject_nonfinite_constant,
        )


class FixtureValidator:
    def __init__(self, source: Path) -> None:
        self.source = source
        self.errors: list[str] = []
        self.modules: dict[str, dict[str, Any]] = {}

    def error(self, path: str, message: str) -> None:
        self.errors.append(f"{path}: {message}")

    def mapping(self, value: Any, path: str) -> dict[str, Any] | None:
        if not isinstance(value, dict):
            self.error(path, "expected an object")
            return None
        return value

    def array(self, value: Any, path: str) -> list[Any] | None:
        if not isinstance(value, list):
            self.error(path, "expected an array")
            return None
        return value

    def integer(self, obj: dict[str, Any], key: str, path: str, minimum: int = 0) -> int | None:
        value = obj.get(key)
        if type(value) is not int:
            self.error(f"{path}.{key}", "expected an integer")
            return None
        if value < minimum:
            self.error(f"{path}.{key}", f"must be at least {minimum}")
            return None
        return value

    def boolean(self, obj: dict[str, Any], key: str, path: str) -> bool | None:
        value = obj.get(key)
        if type(value) is not bool:
            self.error(f"{path}.{key}", "expected a boolean")
            return None
        return value

    def text(self, obj: dict[str, Any], key: str, path: str) -> str | None:
        value = obj.get(key)
        if not isinstance(value, str) or not value.strip():
            self.error(f"{path}.{key}", "expected a non-empty string")
            return None
        return value

    def check_total(self, obj: dict[str, Any], key: str, expected: int, path: str) -> None:
        actual = self.integer(obj, key, path)
        if actual is not None and actual != expected:
            self.error(f"{path}.{key}", f"total mismatch: expected {expected}, found {actual}")

    def validate(self, document: Any) -> list[str]:
        self.scan_private_data(document, "$")
        root = self.mapping(document, "$")
        if root is None:
            return self.errors

        if root.get("schemaVersion") != 2:
            self.error("$.schemaVersion", "expected schema version 2")
        if root.get("fixtureId") != "coretend-product-example-v2":
            self.error("$.fixtureId", "must identify the version-2 CoreTend product example")
        if root.get("fixtureKind") != "example":
            self.error("$.fixtureKind", "must be 'example'")

        labels = self.mapping(root.get("labels"), "$.labels")
        if labels is not None:
            if labels.get("en") != "Example product data":
                self.error("$.labels.en", "must explicitly label the fixture as example data")
            if labels.get("fr") != "Données produit d’exemple":
                self.error("$.labels.fr", "must explicitly label the fixture as example data")

        identity = self.mapping(root.get("identity"), "$.identity")
        if identity is not None and identity.get("homePath") != "/Users/demo":
            self.error("$.identity.homePath", "the only allowed fixture home is /Users/demo")

        modules = self.array(root.get("modules"), "$.modules")
        if modules is None:
            return self.errors

        ordered_ids: list[str] = []
        for index, raw_module in enumerate(modules):
            module_path = f"$.modules[{index}]"
            module = self.mapping(raw_module, module_path)
            if module is None:
                continue
            module_id = self.text(module, "id", module_path)
            is_public = self.boolean(module, "public", module_path)
            is_example = self.boolean(module, "example", module_path)
            if module_id is None:
                continue
            ordered_ids.append(module_id)
            if module_id in self.modules:
                self.error(f"{module_path}.id", f"duplicate module id '{module_id}'")
            else:
                self.modules[module_id] = module
            if module_id in HIDDEN_MODULES and is_public is True:
                self.error(f"{module_path}.public", f"hidden module '{module_id}' cannot be claimed as public")
            if is_example is not True:
                self.error(f"{module_path}.example", "public fixture modules must be marked as examples")
            title = self.mapping(module.get("title"), f"{module_path}.title")
            if title is not None:
                self.text(title, "en", f"{module_path}.title")
                self.text(title, "fr", f"{module_path}.title")
            self.validate_sample_label(module, module_path)

        if tuple(ordered_ids) != EXPECTED_PUBLIC_MODULES:
            self.error(
                "$.modules",
                "public module order must be exactly: " + ", ".join(EXPECTED_PUBLIC_MODULES),
            )

        for module_id in EXPECTED_PUBLIC_MODULES:
            module = self.modules.get(module_id)
            if module is None:
                self.error("$.modules", f"missing public module '{module_id}'")
            elif module.get("public") is not True:
                self.error(f"$.modules.{module_id}.public", "expected true for a public destination")

        self.validate_dashboard()
        self.validate_storage()
        self.validate_space_lens()
        self.validate_duplicates()
        self.validate_applications()
        self.validate_integrity()
        self.validate_activity()
        self.validate_settings()
        return self.errors

    def scan_private_data(self, value: Any, path: str) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                normalized_key = re.sub(r"[^a-z0-9]", "", key.lower())
                if normalized_key in RETIRED_PREVIEW_KEYS:
                    self.error(f"{path}.{key}", "retired preview-mode data is forbidden")
                if normalized_key in SENSITIVE_KEYS and child not in (None, "", False):
                    self.error(f"{path}.{key}", "secret-bearing keys are forbidden in demo fixtures")
                self.scan_private_data(child, f"{path}.{key}")
        elif isinstance(value, list):
            for index, child in enumerate(value):
                self.scan_private_data(child, f"{path}[{index}]")
        elif isinstance(value, str):
            for match in USER_PATH_RE.finditer(value):
                if match.group(1) != "demo":
                    self.error(path, f"personal user path '/Users/{match.group(1)}' is forbidden")
            if EMAIL_RE.search(value):
                self.error(path, "email addresses are forbidden in demo fixtures")
            if any(pattern.search(value) for pattern in SECRET_PATTERNS):
                self.error(path, "value resembles a secret")
        elif isinstance(value, float) and not math.isfinite(value):
            self.error(path, "non-finite numeric values are forbidden")

    def validate_sample_label(self, module: dict[str, Any], path: str) -> None:
        label = self.mapping(module.get("sampleLabel"), f"{path}.sampleLabel")
        if label is None:
            return
        if label.get("en") != "Example data":
            self.error(f"{path}.sampleLabel.en", "must be 'Example data'")
        if label.get("fr") != "Données d’exemple":
            self.error(f"{path}.sampleLabel.fr", "must be 'Données d’exemple'")

    def data_for(self, module_id: str) -> dict[str, Any] | None:
        module = self.modules.get(module_id)
        if module is None:
            return None
        return self.mapping(module.get("data"), f"$.modules.{module_id}.data")

    def validate_dashboard(self) -> None:
        data = self.data_for("dashboard")
        if data is None:
            return
        self.integer(data, "freeBytes", "$.modules.dashboard.data")
        if self.boolean(data, "trashEnabled", "$.modules.dashboard.data") is not True:
            self.error("$.modules.dashboard.data.trashEnabled", "the example must show recoverable Trash actions")
        workflows = self.array(data.get("workflowDestinations"), "$.modules.dashboard.data.workflowDestinations")
        if workflows is not None:
            if not all(isinstance(workflow, str) for workflow in workflows):
                self.error("$.modules.dashboard.data.workflowDestinations", "workflow ids must be strings")
            elif set(workflows) != DASHBOARD_WORKFLOWS:
                self.error("$.modules.dashboard.data.workflowDestinations", "must match the six real Dashboard workflow tiles")

    def validate_storage(self) -> None:
        data = self.data_for("storage")
        if data is None:
            return
        items = self.array(data.get("items"), "$.modules.storage.data.items")
        if items is None:
            return
        if not items:
            self.error("$.modules.storage.data.items", "Storage requires example findings")
        total = 0
        selected = 0
        for index, raw_item in enumerate(items):
            path = f"$.modules.storage.data.items[{index}]"
            item = self.mapping(raw_item, path)
            if item is None:
                continue
            size = self.integer(item, "sizeBytes", path)
            preselected = self.boolean(item, "preselected", path)
            if size is not None:
                total += size
                if preselected is True:
                    selected += size
        self.check_total(data, "totalBytes", total, "$.modules.storage.data")
        self.check_total(data, "selectedBytes", selected, "$.modules.storage.data")

    def validate_space_lens(self) -> None:
        data = self.data_for("space-lens")
        if data is None:
            return
        children = self.array(data.get("children"), "$.modules.space-lens.data.children")
        if children is None:
            return
        if not children:
            self.error("$.modules.space-lens.data.children", "Space Lens requires example children")
        total = 0
        for index, raw_child in enumerate(children):
            path = f"$.modules.space-lens.data.children[{index}]"
            child = self.mapping(raw_child, path)
            if child is None:
                continue
            size = self.integer(child, "sizeBytes", path)
            if size is not None:
                total += size
        self.check_total(data, "totalBytes", total, "$.modules.space-lens.data")

    def validate_duplicates(self) -> None:
        data = self.data_for("duplicates")
        if data is None:
            return
        groups = self.array(data.get("groups"), "$.modules.duplicates.data.groups")
        if groups is None:
            return
        if not groups:
            self.error("$.modules.duplicates.data.groups", "Duplicates requires example groups")
        total = 0
        reclaimable = 0
        seen_ids: set[str] = set()
        for index, raw_group in enumerate(groups):
            path = f"$.modules.duplicates.data.groups[{index}]"
            group = self.mapping(raw_group, path)
            if group is None:
                continue
            group_id = self.text(group, "id", path)
            if group_id in seen_ids:
                self.error(f"{path}.id", f"duplicate group id '{group_id}'")
            elif group_id is not None:
                seen_ids.add(group_id)
            copy_size = self.integer(group, "copySizeBytes", path, minimum=1)
            copies = self.integer(group, "copies", path, minimum=2)
            files = self.array(group.get("files"), f"{path}.files")
            if files is not None and copies is not None and len(files) != copies:
                self.error(f"{path}.files", f"expected {copies} file rows, found {len(files)}")
            keepers = 0
            if files is not None:
                for file_index, raw_file in enumerate(files):
                    file_path = f"{path}.files[{file_index}]"
                    file_item = self.mapping(raw_file, file_path)
                    if file_item is not None and self.boolean(file_item, "keeper", file_path) is True:
                        keepers += 1
            if keepers != 1:
                self.error(f"{path}.files", f"exactly one keeper is required, found {keepers}")
            if copy_size is None or copies is None:
                continue
            expected_total = copy_size * copies
            expected_reclaimable = copy_size * (copies - 1)
            self.check_total(group, "totalBytes", expected_total, path)
            self.check_total(group, "reclaimableBytes", expected_reclaimable, path)
            total += expected_total
            reclaimable += expected_reclaimable
        self.check_total(data, "totalBytes", total, "$.modules.duplicates.data")
        self.check_total(data, "reclaimableBytes", reclaimable, "$.modules.duplicates.data")

    def validate_applications(self) -> None:
        data = self.data_for("applications")
        if data is None:
            return
        apps = self.array(data.get("installedApps"), "$.modules.applications.data.installedApps")
        leftovers = self.array(data.get("leftovers"), "$.modules.applications.data.leftovers")
        if apps is None or leftovers is None:
            return
        if not apps:
            self.error("$.modules.applications.data.installedApps", "Applications requires installed-app examples")
        if not leftovers:
            self.error("$.modules.applications.data.leftovers", "Applications requires a conservative leftover example")
        total = 0
        for index, raw_app in enumerate(apps):
            path = f"$.modules.applications.data.installedApps[{index}]"
            app = self.mapping(raw_app, path)
            if app is None:
                continue
            app_size = self.integer(app, "appSizeBytes", path)
            associated = self.array(app.get("associatedItems"), f"{path}.associatedItems")
            associated_total = 0
            if associated is not None:
                for item_index, raw_item in enumerate(associated):
                    item_path = f"{path}.associatedItems[{item_index}]"
                    item = self.mapping(raw_item, item_path)
                    if item is None:
                        continue
                    size = self.integer(item, "sizeBytes", item_path)
                    if size is not None:
                        associated_total += size
            if app_size is not None:
                app_total = app_size + associated_total
                self.check_total(app, "totalBytes", app_total, path)
                total += app_total
        for index, raw_leftover in enumerate(leftovers):
            path = f"$.modules.applications.data.leftovers[{index}]"
            leftover = self.mapping(raw_leftover, path)
            if leftover is None:
                continue
            size = self.integer(leftover, "sizeBytes", path)
            if size is not None:
                total += size
            if self.boolean(leftover, "preselected", path) is not False:
                self.error(f"{path}.preselected", "heuristic leftovers must never be preselected")
        self.check_total(data, "totalBytes", total, "$.modules.applications.data")

    def validate_integrity(self) -> None:
        data = self.data_for("integrity")
        if data is None:
            return
        downloads = self.array(data.get("downloads"), "$.modules.integrity.data.downloads")
        total = 0
        if downloads is not None:
            if not downloads:
                self.error("$.modules.integrity.data.downloads", "Integrity requires Download-provenance examples")
            for index, raw_download in enumerate(downloads):
                path = f"$.modules.integrity.data.downloads[{index}]"
                download = self.mapping(raw_download, path)
                if download is None:
                    continue
                size = self.integer(download, "sizeBytes", path)
                if size is not None:
                    total += size
        self.check_total(data, "totalBytes", total, "$.modules.integrity.data")
        inspected = self.mapping(data.get("inspectedApplication"), "$.modules.integrity.data.inspectedApplication")
        if inspected is not None:
            signature_tier = self.text(inspected, "signatureTier", "$.modules.integrity.data.inspectedApplication")
            if signature_tier is not None and signature_tier not in {"appleSigned", "teamSigned", "adHocOrUnsigned"}:
                self.error("$.modules.integrity.data.inspectedApplication.signatureTier", "unsupported code-sign tier")
            if inspected.get("notarization") != "not-inspected":
                self.error("$.modules.integrity.data.inspectedApplication.notarization", "CoreTend does not inspect notarization")

    def validate_activity(self) -> None:
        data = self.data_for("activity")
        if data is None:
            return
        records = self.array(data.get("records"), "$.modules.activity.data.records")
        if records is None:
            return
        if not records:
            self.error("$.modules.activity.data.records", "Activity requires example records")
        total = 0
        freed = 0
        item_count = 0
        ids: set[str] = set()
        for index, raw_record in enumerate(records):
            path = f"$.modules.activity.data.records[{index}]"
            record = self.mapping(raw_record, path)
            if record is None:
                continue
            record_id = self.text(record, "id", path)
            if record_id in ids:
                self.error(f"{path}.id", f"duplicate activity id '{record_id}'")
            elif record_id is not None:
                ids.add(record_id)
            kind = self.text(record, "kind", path)
            if kind not in {"scan", "cleanup", "error"}:
                self.error(f"{path}.kind", "fixture may only demonstrate currently produced activity kinds")
            date = self.text(record, "date", path)
            if date is not None:
                try:
                    datetime.fromisoformat(date.replace("Z", "+00:00"))
                except ValueError:
                    self.error(f"{path}.date", "expected an ISO-8601 timestamp")
            record_bytes = self.integer(record, "bytes", path)
            count = self.integer(record, "itemCount", path)
            if record_bytes is not None:
                total += record_bytes
                if kind == "cleanup":
                    freed += record_bytes
            if count is not None:
                item_count += count
        self.check_total(data, "totalBytes", total, "$.modules.activity.data")
        self.check_total(data, "freedBytes", freed, "$.modules.activity.data")
        self.check_total(data, "itemCount", item_count, "$.modules.activity.data")

        dashboard = self.data_for("dashboard")
        if dashboard is not None:
            latest_ref = self.text(dashboard, "latestActivityRef", "$.modules.dashboard.data")
            if latest_ref is not None and latest_ref not in ids:
                self.error("$.modules.dashboard.data.latestActivityRef", "must reference an example Activity record")

    def validate_settings(self) -> None:
        data = self.data_for("settings")
        if data is None:
            return
        if self.boolean(data, "telemetryEnabled", "$.modules.settings.data") is not False:
            self.error("$.modules.settings.data.telemetryEnabled", "CoreTend has no telemetry")
        if self.boolean(data, "accountRequired", "$.modules.settings.data") is not False:
            self.error("$.modules.settings.data.accountRequired", "CoreTend has no account requirement")
        updater = self.mapping(data.get("updater"), "$.modules.settings.data.updater")
        if updater is None:
            return
        if updater.get("manifestURL") != "https://coretend.ahmetbsbnr.com/latest.json":
            self.error("$.modules.settings.data.updater.manifestURL", "must match the real static updater manifest")
        if updater.get("checkMode") != "manual":
            self.error("$.modules.settings.data.updater.checkMode", "automatic checks are not currently wired")
        for key in ("downloadsAutomatically", "installsAutomatically"):
            if self.boolean(updater, key, "$.modules.settings.data.updater") is not False:
                self.error(f"$.modules.settings.data.updater.{key}", "the updater does not download or install")


def validate_path(path: Path) -> list[str]:
    try:
        document = load_fixture(path)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        return [f"$: invalid fixture: {error}"]
    return FixtureValidator(path).validate(document)


def main(argv: list[str] | None = None) -> int:
    repo_root = Path(__file__).resolve().parent.parent
    default_fixture = repo_root / "Resources" / "DemoFixtures" / "coretend-product.json"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixtures", nargs="*", type=Path, default=[default_fixture])
    args = parser.parse_args(argv)

    failed = False
    for fixture in args.fixtures:
        errors = validate_path(fixture)
        if errors:
            failed = True
            print(f"FAIL: {fixture}", file=sys.stderr)
            for error in errors:
                print(f"  - {error}", file=sys.stderr)
        else:
            print(f"OK: {fixture} is a coherent, privacy-safe example fixture")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
