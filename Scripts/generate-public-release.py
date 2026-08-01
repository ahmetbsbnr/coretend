#!/usr/bin/env python3
"""Validate the tracked published release and emit path-free public metadata.

This is deliberately an offline gate.  The tracked configuration records what
GitHub serves; this script turns that reviewed record into the two small files
the website and updater may publish.  The currently published rc.3 evidence is
pinned below.  A future, unpinned release must be accompanied by both local
artifacts so their bytes, sizes, and SHA-256 values can be checked before any
output is written.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, Mapping, Optional, Sequence, Tuple
from urllib.parse import quote, urlsplit


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = REPOSITORY_ROOT / "Configuration" / "published-release.json"
PRODUCT = "CoreTend"
REPOSITORY_URL = "https://github.com/ahmetbsbnr/coretend"
SUPPORTED_ARCHITECTURE = "arm64"
SUPPORTED_MINIMUM_MACOS = "14.0"

# Independent audit evidence for the release that was publicly inspected on
# 2026-08-01.  These values are validation pins, not a second source used to
# generate output.  Changing the tracked manifest alone therefore cannot make
# a different rc.3 checksum public.
PINNED_RELEASE_EVIDENCE: Mapping[str, Mapping[str, Mapping[str, Any]]] = {
    "0.9.1-rc.3": {
        "dmg": {
            "sha256": "2960293a278f81be602aebb84ad6582d41f118635bbbca4517853bb68831ee71",
            "size": 4_686_642,
        },
        "zip": {
            "sha256": "28114f0a352abe340bb83cd61c84dedcb3cb0b8e031a12ae7a1a4e306e4db173",
            "size": 2_828_017,
        },
    }
}

ALLOWED_SOURCE_KEYS = {
    "_comment",
    "schemaVersion",
    "product",
    "version",
    "channel",
    "prerelease",
    "tag",
    "sourceCommit",
    "releaseURL",
    "repositoryURL",
    "dmgName",
    "dmgURL",
    "dmgSHA256",
    "dmgSize",
    "zipName",
    "zipURL",
    "zipSHA256",
    "zipSize",
    "signed",
    "notarized",
    "minimumMacOS",
    "architecture",
    "publishedAt",
}

REQUIRED_SOURCE_KEYS = ALLOWED_SOURCE_KEYS - {"_comment"}
VERSION_RE = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-(rc|beta)\.(0|[1-9][0-9]*))?$"
)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SOURCE_COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")

FORBIDDEN_TEXT = (
    (re.compile(r"clamav", re.IGNORECASE), "legacy ClamAV reference"),
    (re.compile(r"(?:^|[/\\])Users[/\\]", re.IGNORECASE), "personal user path"),
    (re.compile(r"file://", re.IGNORECASE), "local file URL"),
    (re.compile(r"(?:localhost|127\.0\.0\.1)(?::[0-9]+)?", re.IGNORECASE), "preview host"),
    (re.compile(r"(?:^|[\s'\"])(?:\.\.?[/\\])"), "relative filesystem path"),
    (
        re.compile(
            r"(?:^|[\s'\"])(?:Configuration|Documentation|Scripts|Release|Website|Site|public|dist|out)[/\\]",
            re.IGNORECASE,
        ),
        "internal repository path",
    ),
    (re.compile(r"(?:^|/)(?:_references|_backups)(?:/|$)", re.IGNORECASE), "private workspace path"),
    (re.compile(r"\.html(?:$|[?#/\s])", re.IGNORECASE), "HTML implementation path"),
)


class ReleaseValidationError(ValueError):
    """The tracked release cannot safely be exposed as public metadata."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ReleaseValidationError(message)


def _strings(value: Any, location: str = "source") -> Iterable[Tuple[str, str]]:
    if isinstance(value, str):
        yield location, value
    elif isinstance(value, Mapping):
        for key, child in value.items():
            yield from _strings(child, f"{location}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from _strings(child, f"{location}[{index}]")


def _reject_forbidden_text(value: Any) -> None:
    for location, text in _strings(value):
        for pattern, reason in FORBIDDEN_TEXT:
            if pattern.search(text):
                raise ReleaseValidationError(f"{location} contains a {reason}")


def _require_string(source: Mapping[str, Any], key: str) -> str:
    value = source.get(key)
    _require(isinstance(value, str) and bool(value), f"{key} must be a non-empty string")
    return value


def _require_bool(source: Mapping[str, Any], key: str) -> bool:
    value = source.get(key)
    _require(type(value) is bool, f"{key} must be a boolean")
    return value


def _require_positive_int(source: Mapping[str, Any], key: str) -> int:
    value = source.get(key)
    _require(type(value) is int and value > 0, f"{key} must be a positive integer")
    return value


def _validate_digest(value: str, key: str) -> str:
    _require(bool(SHA256_RE.fullmatch(value)), f"{key} must be a lowercase SHA-256")
    # Obvious placeholders must never survive merely because they have the
    # right width.  Real proof comes from a pinned audit or matching artifact.
    _require(len(set(value)) >= 10, f"{key} is placeholder-like, not a credible SHA-256")
    return value


def _canonical_asset_url(tag: str, name: str) -> str:
    return f"{REPOSITORY_URL}/releases/download/{quote(tag, safe='-._~')}/{quote(name, safe='-._~')}"


def _validate_https_url(value: str, key: str) -> None:
    parsed = urlsplit(value)
    _require(parsed.scheme == "https", f"{key} must use HTTPS")
    _require(bool(parsed.netloc), f"{key} must have a host")
    _require(not parsed.username and not parsed.password, f"{key} must not contain credentials")
    _require(not parsed.query and not parsed.fragment, f"{key} must not contain a query or fragment")


def _validate_artifact_name(name: str, expected: str, key: str) -> None:
    _require(name == expected, f"{key} must be exactly {expected!r}")
    _require(Path(name).name == name and "/" not in name and "\\" not in name, f"{key} must be a basename")


def _file_sha256(file_path: Path) -> str:
    digest = hashlib.sha256()
    with file_path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _verify_artifact(source: Mapping[str, Any], prefix: str, artifact_path: Path) -> None:
    expected_name = _require_string(source, f"{prefix}Name")
    _require(artifact_path.is_file(), f"{prefix} artifact does not exist: {artifact_path}")
    _require(artifact_path.name == expected_name, f"{prefix} artifact basename must be {expected_name!r}")
    actual_size = artifact_path.stat().st_size
    expected_size = _require_positive_int(source, f"{prefix}Size")
    _require(actual_size == expected_size, f"{prefix} artifact size mismatch: expected {expected_size}, got {actual_size}")
    actual_digest = _file_sha256(artifact_path)
    expected_digest = _require_string(source, f"{prefix}SHA256")
    _require(actual_digest == expected_digest, f"{prefix} artifact SHA-256 mismatch")


def validate_source(
    source: Mapping[str, Any],
    dmg_artifact: Optional[Path] = None,
    zip_artifact: Optional[Path] = None,
) -> Dict[str, Any]:
    """Return a normalized source or raise before any public file is written."""

    _require(isinstance(source, Mapping), "source must be a JSON object")
    unknown = set(source) - ALLOWED_SOURCE_KEYS
    missing = REQUIRED_SOURCE_KEYS - set(source)
    _require(not unknown, f"source contains unreviewed fields: {', '.join(sorted(unknown))}")
    _require(not missing, f"source is missing fields: {', '.join(sorted(missing))}")
    _reject_forbidden_text(source)

    _require(source.get("schemaVersion") == 1, "schemaVersion must be 1")
    _require(source.get("product") == PRODUCT, f"product must be {PRODUCT!r}")

    version = _require_string(source, "version")
    version_match = VERSION_RE.fullmatch(version)
    _require(bool(version_match), "version must be CoreTend SemVer (stable, rc.N, or beta.N)")
    prerelease_kind = version_match.group(4) if version_match else None
    expected_channel = {"rc": "release-candidate", "beta": "beta"}.get(prerelease_kind, "stable")
    expected_prerelease = prerelease_kind is not None
    _require(source.get("tag") == f"v{version}", "tag must be exactly 'v' plus version")
    _require(source.get("channel") == expected_channel, f"channel must be {expected_channel!r} for {version}")
    _require(_require_bool(source, "prerelease") is expected_prerelease, "prerelease disagrees with version")

    architecture = _require_string(source, "architecture")
    _require(architecture == SUPPORTED_ARCHITECTURE, f"architecture must be {SUPPORTED_ARCHITECTURE!r}")
    minimum_macos = _require_string(source, "minimumMacOS")
    _require(minimum_macos == SUPPORTED_MINIMUM_MACOS, f"minimumMacOS must be {SUPPORTED_MINIMUM_MACOS!r}")

    signed = _require_bool(source, "signed")
    notarized = _require_bool(source, "notarized")
    _require(not signed, "this direct-distribution gate currently requires signed=false")
    _require(not notarized, "this direct-distribution gate currently requires notarized=false")

    _require(source.get("repositoryURL") == REPOSITORY_URL, "repositoryURL must be the canonical CoreTend repository")
    _validate_https_url(_require_string(source, "repositoryURL"), "repositoryURL")
    tag = _require_string(source, "tag")
    expected_release_url = f"{REPOSITORY_URL}/releases/tag/{quote(tag, safe='-._~')}"
    release_url = _require_string(source, "releaseURL")
    _validate_https_url(release_url, "releaseURL")
    _require(release_url == expected_release_url, "releaseURL does not match repository and tag")

    source_commit = _require_string(source, "sourceCommit")
    _require(bool(SOURCE_COMMIT_RE.fullmatch(source_commit)), "sourceCommit must be a lowercase 40-character Git SHA")
    published_at = _require_string(source, "publishedAt")
    try:
        parsed_published_at = datetime.fromisoformat(published_at.replace("Z", "+00:00"))
    except ValueError as error:
        raise ReleaseValidationError("publishedAt must be an ISO-8601 timestamp") from error
    _require(published_at.endswith("Z") and parsed_published_at.tzinfo is not None, "publishedAt must be UTC and end in Z")

    expected_names = {
        "dmg": f"CoreTend-{version}-{architecture}-unsigned.dmg",
        "zip": f"CoreTend-{version}-{architecture}-unsigned.zip",
    }
    for prefix in ("dmg", "zip"):
        name = _require_string(source, f"{prefix}Name")
        _validate_artifact_name(name, expected_names[prefix], f"{prefix}Name")
        url = _require_string(source, f"{prefix}URL")
        _validate_https_url(url, f"{prefix}URL")
        _require(url == _canonical_asset_url(tag, name), f"{prefix}URL does not match repository, tag, and asset name")
        _validate_digest(_require_string(source, f"{prefix}SHA256"), f"{prefix}SHA256")
        _require_positive_int(source, f"{prefix}Size")

    pinned = PINNED_RELEASE_EVIDENCE.get(version)
    if pinned is not None:
        for prefix in ("dmg", "zip"):
            _require(source[f"{prefix}SHA256"] == pinned[prefix]["sha256"], f"{prefix}SHA256 disagrees with pinned {version} audit evidence")
            _require(source[f"{prefix}Size"] == pinned[prefix]["size"], f"{prefix}Size disagrees with pinned {version} audit evidence")
    else:
        _require(
            dmg_artifact is not None and zip_artifact is not None,
            "un-pinned release: provide both --dmg-artifact and --zip-artifact to prove checksums",
        )

    if dmg_artifact is not None:
        _verify_artifact(source, "dmg", dmg_artifact)
    if zip_artifact is not None:
        _verify_artifact(source, "zip", zip_artifact)

    return dict(source)


def public_manifest(source: Mapping[str, Any]) -> Dict[str, Any]:
    """Keep only public updater/site fields; never forward comments or paths."""

    return {
        "schemaVersion": 2,
        "product": PRODUCT,
        "version": source["version"],
        "channel": source["channel"],
        "prerelease": source["prerelease"],
        "releaseTag": source["tag"],
        "sourceCommit": source["sourceCommit"],
        "releaseURL": source["releaseURL"],
        "repositoryURL": source["repositoryURL"],
        "publishedAt": source["publishedAt"],
        "architecture": source["architecture"],
        "minimumMacOS": source["minimumMacOS"],
        "signed": source["signed"],
        "notarized": source["notarized"],
        "dmgName": source["dmgName"],
        "dmgURL": source["dmgURL"],
        "dmgSHA256": source["dmgSHA256"],
        "dmgSize": source["dmgSize"],
        "zipName": source["zipName"],
        "zipURL": source["zipURL"],
        "zipSHA256": source["zipSHA256"],
        "zipSize": source["zipSize"],
    }


def render_outputs(source: Mapping[str, Any]) -> Tuple[bytes, bytes]:
    manifest = public_manifest(source)
    _reject_forbidden_text(manifest)
    latest = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    latest_digest = hashlib.sha256(latest).hexdigest()
    sums = (
        f"{source['zipSHA256']}  {source['zipName']}\n"
        f"{source['dmgSHA256']}  {source['dmgName']}\n"
        f"{latest_digest}  latest.json\n"
    ).encode("ascii")
    _reject_forbidden_text(sums.decode("ascii"))
    return latest, sums


def _atomic_write(destination: Path, data: bytes) -> None:
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{destination.name}.", dir=destination.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, destination)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def generate(
    source_path: Path,
    output_directory: Path,
    dmg_artifact: Optional[Path] = None,
    zip_artifact: Optional[Path] = None,
) -> Tuple[Path, Path]:
    try:
        raw_source = json.loads(source_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ReleaseValidationError(f"cannot read source JSON: {error}") from error
    source = validate_source(raw_source, dmg_artifact=dmg_artifact, zip_artifact=zip_artifact)
    latest, sums = render_outputs(source)

    try:
        output_directory.mkdir(parents=True, exist_ok=True)
    except OSError as error:
        raise ReleaseValidationError(f"cannot create output directory: {error}") from error
    _require(output_directory.is_dir(), "output path must be a directory")
    latest_path = output_directory / "latest.json"
    sums_path = output_directory / "SHA256SUMS"
    _atomic_write(latest_path, latest)
    _atomic_write(sums_path, sums)
    return latest_path, sums_path


def parse_args(arguments: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_directory", type=Path, help="directory that receives latest.json and SHA256SUMS")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE, help="tracked release source")
    parser.add_argument("--dmg-artifact", type=Path, help="optional local DMG proof; mandatory for an un-pinned release")
    parser.add_argument("--zip-artifact", type=Path, help="optional local ZIP proof; mandatory for an un-pinned release")
    return parser.parse_args(arguments)


def main(arguments: Optional[Sequence[str]] = None) -> int:
    options = parse_args(arguments)
    try:
        latest_path, sums_path = generate(
            options.source,
            options.output_directory,
            dmg_artifact=options.dmg_artifact,
            zip_artifact=options.zip_artifact,
        )
    except ReleaseValidationError as error:
        print(f"public release gate: FAIL: {error}", file=sys.stderr)
        return 1
    print(f"public release gate: OK: {latest_path}")
    print(f"public release gate: OK: {sums_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
