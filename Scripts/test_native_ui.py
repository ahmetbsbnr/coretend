#!/usr/bin/env python3
"""Accessibility-driven UI smoke and safe-action tests against an isolated app fixture."""

from __future__ import annotations

import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

import capture_screens


DESTINATIONS = {
    "Overview": "overview",
    "Explore": "explore",
    "Cleanup": "cleanup",
    "Duplicates": "duplicates",
    "Applications": "applications",
    "Integrity": "integrity",
    "Performance": "performance",
    "Record": "record",
}


def run(args, **kwargs):
    return subprocess.run(args, capture_output=True, text=True, check=False, **kwargs)


def fixture_bundle(path: Path, name: str, identifier: str):
    contents = path / "Contents"
    contents.mkdir(parents=True, exist_ok=True)
    info = {"CFBundleName": name, "CFBundleIdentifier": identifier,
            "CFBundlePackageType": "APPL", "CFBundleExecutable": name,
            "CFBundleShortVersionString": "1.0"}
    (contents / "Info.plist").write_bytes(plistlib.dumps(info))
    binary = contents / name
    binary.write_bytes(b"fixture executable")


def fixture_data(home: Path):
    plot = home / "Greenhouse"
    (plot / "Projects").mkdir(parents=True)
    (plot / "Projects" / "Plan.txt").write_text("fixture plan\n" * 1200)
    shutil.copy2(plot / "Projects" / "Plan.txt", plot / "Plan copy.txt")
    (plot / "Incomplete.download").write_text("unfinished fixture download")

    caches = home / "Library/Caches/com.example.fixture"
    caches.mkdir(parents=True)
    (caches / "cache-entry.bin").write_bytes(b"fixture cache\n" * 1000)

    applications = home / "Applications"
    fixture_bundle(applications / "Fixture App.app", "Fixture App", "org.example.fixture-app")
    fixture_bundle(plot / "App Store.app", "App Store", "org.example.fixture-store")

    agents = home / "LaunchAgents"
    agents.mkdir()
    (agents / "org.example.fixture.plist").write_bytes(plistlib.dumps({
        "Label": "org.example.fixture", "ProgramArguments": ["/fixture/agent"]
    }))
    return plot, caches, applications


def elements(node):
    return [node] + [child for item in node.get("children", []) for child in elements(item)]


def name(node):
    return node["title"] or node["description"] or node.get("placeholder", "")


class Driver:
    def __init__(self, binary: Path, pid: int):
        self.binary = binary
        self.pid = pid

    def call(self, *args, expect=True):
        result = run([str(self.binary), *args[:1], str(self.pid), *args[1:]])
        if expect and result.returncode:
            raise AssertionError(result.stderr.strip() or result.stdout.strip())
        return result

    def tree(self):
        result = self.call("dump")
        return json.loads(result.stdout)

    def click(self, title: str, index: int = 0):
        last_error = None
        for attempt in range(4):
            result = self.call("press", title, str(index), expect=False)
            if result.returncode == 0:
                return
            last_error = result.stderr.strip() or result.stdout.strip()
            if "-25205" not in last_error:
                break
            if not any(name(node) == title for node in elements(self.tree())):
                return
            time.sleep(0.25 * (attempt + 1))
        visible = [(node["role"], name(node)) for node in elements(self.tree()) if name(node)]
        raise AssertionError(f"{last_error}; visible={visible[-20:]}")

    def set_value(self, title: str, value: str):
        self.call("set", title, value)

    def wait(self, predicate, description: str, timeout=12):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            snapshot = self.tree()
            if predicate(elements(snapshot)):
                return snapshot
            time.sleep(0.25)
        final = self.tree()
        visible = [(node["role"], name(node)) for node in elements(final) if name(node)]
        raise AssertionError(f"Timed out waiting for {description}; visible: {visible[:80]}")


class Session:
    def __init__(self, executable: Path, helper: Path, base: Path, destination: str,
                 scan_kind: str | None = None, cleanup_rule: str | None = None):
        self.root = base / ("session-" + destination + "-" + uuid.uuid4().hex[:8])
        self.tmp = self.root / "tmp"
        self.home, self.store = (self.tmp / name for name in ("home", "store"))
        for directory in (self.home, self.store):
            directory.mkdir(parents=True)
        if scan_kind:
            plot, caches, applications = fixture_data(self.home)
            scan_root = {"plot": plot, "caches": caches, "applications": applications}[scan_kind]
        else:
            scan_root = None
        self.trash = self.store / "FixtureTrash"
        environment = {
            "PATH": "/usr/bin:/bin", "HOME": str(self.home), "CFFIXED_USER_HOME": str(self.home),
            "TMPDIR": str(self.tmp) + "/", "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": str(self.store), "CORETEND_TEST_TRASH_DIR": str(self.trash),
            "CORETEND_TEST_ONBOARDING_COMPLETED": "1", "CORETEND_TEST_LANGUAGE": "en",
            "CORETEND_TEST_APPEARANCE": "dark", "CORETEND_TEST_LAST_DESTINATION": destination,
        }
        if scan_root:
            environment["CORETEND_TEST_SCAN_ROOT"] = str(scan_root)
        if cleanup_rule:
            environment["CORETEND_TEST_CLEANUP_RULE"] = cleanup_rule
        self.stderr_path = self.root / "app-stderr.log"
        for launch_attempt in range(3):
            mode = "w" if launch_attempt == 0 else "a"
            self.stderr_handle = self.stderr_path.open(mode)
            self.process = subprocess.Popen([str(executable)], env=environment,
                                            stdout=subprocess.DEVNULL, stderr=self.stderr_handle)
            self.driver = Driver(helper, self.process.pid)
            run(["osascript", "-e", f'tell application "System Events" to tell (first process whose unix id is {self.process.pid}) to set frontmost to true'])
            deadline = time.monotonic() + 15
            next_activation = 0.0
            while time.monotonic() < deadline:
                if self.process.poll() is not None:
                    raise AssertionError(f"app exited during launch: {self.process.returncode}")
                result = self.driver.call("dump", expect=False)
                if result.returncode == 0:
                    try:
                        tree = json.loads(result.stdout)
                        if any(node["role"] == "AXWindow" for node in elements(tree)):
                            break
                    except json.JSONDecodeError:
                        pass
                if time.monotonic() >= next_activation:
                    run(["osascript", "-e", f'tell application "System Events" to tell (first process whose unix id is {self.process.pid}) to set frontmost to true'])
                    next_activation = time.monotonic() + 1.0
                time.sleep(0.25)
            else:
                self.process.terminate()
                self.process.wait(timeout=5)
                self.stderr_handle.close()
                if launch_attempt == 2:
                    raise AssertionError(f"app window not accessible: {result.stderr.strip()}; "
                                         f"stderr={self.stderr_path.read_text()}")
                continue
            break

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=5)
        self.stderr_handle.close()
        time.sleep(0.4)


def assert_labels(nodes, labels, context):
    buttons = {name(item) for item in nodes if item["role"] == "AXButton" and item["enabled"]}
    missing = sorted(set(labels) - buttons)
    if missing:
        found = [(name(item), item["enabled"])
                 for item in nodes if item["role"] == "AXButton"]
        raise AssertionError(f"{context}: missing enabled buttons {missing}; found {found}")


def main():
    repo = Path(__file__).resolve().parents[1]
    report = []
    with tempfile.TemporaryDirectory(prefix="coretend-ui-tests-") as temporary:
        base = Path(temporary).resolve()
        helper = base / "NativeUITestDriver"
        compiled = run(["swiftc", "-O", str(repo / "Scripts/NativeUITestDriver.swift"),
                        "-framework", "ApplicationServices", "-o", str(helper)])
        if compiled.returncode:
            raise SystemExit(f"Could not compile UI driver: {compiled.stderr}")

        app = capture_screens.package(repo, base)
        bootstrap = base / "bootstrap"
        bootstrap_home = bootstrap / "home"
        bootstrap_home.mkdir(parents=True)
        executable = capture_screens.install(repo, app, bootstrap_home)

        # Real sidebar buttons: all eight destinations must expose their own root and heading.
        navigation = Session(executable, helper, base, "overview")
        try:
            nav = navigation.driver
            initial = nav.tree()
            assert_labels(elements(initial), ["Go to or open…", "Overview", "Explore", "Cleanup",
                                               "Duplicates", "Applications", "Integrity", "Performance",
                                               "Record", "Settings"], "sidebar")
            for title, destination in DESTINATIONS.items():
                nav.click(title)
                snapshot = nav.wait(
                    lambda nodes, expected=destination: any(
                        node["role"] == "AXScrollArea" and node["identifier"] == f"destination-{expected}"
                        for node in nodes), f"{destination} route")
                if not any(node["role"] == "AXHeading" and name(node) == title
                           for node in elements(snapshot)):
                    raise AssertionError(f"{destination}: page title is absent after clicking sidebar button")
                report.append(f"sidebar.{destination}: PASS")

            nav.click("Settings")
            settings = nav.wait(lambda nodes: any(node["role"] == "AXButton" and name(node) == "Done" for node in nodes),
                                "Settings sheet")
            assert_labels(elements(settings), ["Done", "General", "Access", "Privacy", "Data"], "settings tabs")
            toggle = next((node for node in elements(settings) if "greenhouse live" in name(node).lower()), None)
            if toggle is not None:
                nav.click(name(toggle))
                nav.click(name(toggle))
            nav.click("Access")
            access = nav.wait(lambda nodes: any(node["role"] == "AXButton" and name(node) == "Add excluded folder…" for node in nodes),
                              "Settings access tab")
            nav.click("Add excluded folder…")
            time.sleep(0.3)
            run(["osascript", "-e", f'tell application "System Events" to tell (first process whose unix id is {navigation.process.pid}) to key code 53'])
            nav.click("Privacy")
            nav.wait(lambda nodes: any(node["role"] == "AXHeading" and "signature" in name(node).lower() for node in nodes),
                     "Settings privacy tab")
            nav.click("Preview export…")
            preview = nav.wait(lambda nodes: any(node["role"] == "AXButton" and name(node) == "Cancel" for node in nodes),
                               "diagnostic preview")
            nav.click("Cancel")
            nav.click("Data")
            data_tab = nav.wait(lambda nodes: any(node["role"] == "AXButton" and name(node) == "Choose a 1.x copy…" for node in nodes),
                                "Settings data tab")
            nav.click("Save recent files from Explore")
            nav.click("Save recent files from Explore")
            nav.click("Done")
            report.append("settings.tabs-toggle-folder-picker-private-preview: PASS")

            nav.click("Go to or open…")
            palette = nav.wait(lambda nodes: any(node["role"] in {"AXTextField", "AXSearchField"} for node in nodes), "command palette")
            text_fields = [node for node in elements(palette) if node["role"] in {"AXTextField", "AXSearchField"}]
            if not text_fields:
                raise AssertionError("command palette search field is absent")
            nav.set_value(name(text_fields[0]), "Record")
            nav.click("Record")
            nav.wait(lambda nodes: any(node["role"] == "AXScrollArea" and node["identifier"] == "destination-record"
                                       for node in nodes), "palette result navigation")
            report.append("palette.search-and-open: PASS")
        finally:
            navigation.close()

        # Each data-changing test gets its own HOME, store and reversible fixture Trash.
        module_roots = {
            "overview": None,
            "explore": "plot",
            "cleanup": "caches",
            "duplicates": "plot",
            "applications": "applications",
            "integrity": "plot",
            "performance": None,
            "record": None,
        }
        cleanup_rules = {"cleanup": "cleanup.usercaches"}

        expected = {
            "overview": ["Refresh measurements", "Refresh"],
            "explore": ["Choose another folder"],
            "cleanup": ["User caches, Files under ~/Library/Caches., Low risk", "Select the rule’s folder", "Inspect selected rule"],
            "duplicates": ["Choose another folder"],
            "applications": ["Choose another folder"],
            "integrity": ["Choose another app"],
            "performance": ["Refresh measurements", "Clear performance history…"],
            "record": [],
        }

        for destination, root in module_roots.items():
            print(f"running module.{destination}", flush=True)
            session = Session(executable, helper, base, destination, root, cleanup_rules.get(destination))
            try:
                plot = session.home / "Greenhouse"
                caches = session.home / "Library/Caches/com.example.fixture"
                driver = session.driver
                snapshot = driver.wait(lambda nodes, expected=destination: any(
                    node["role"] == "AXScrollArea" and node["identifier"] == f"destination-{expected}" for node in nodes),
                    f"{destination} root")
                time.sleep(1.4)
                snapshot = driver.tree()
                nodes = elements(snapshot)
                assert_labels(nodes, expected[destination], destination)
                destination_root = next(node for node in nodes
                                        if node["role"] == "AXScrollArea"
                                        and node["identifier"] == f"destination-{destination}")
                content_nodes = elements(destination_root)
                unnamed_buttons = [(node["role"], node["identifier"], node["title"], node["description"])
                                   for node in content_nodes
                                   if node["role"] == "AXButton" and node["enabled"] and not name(node)]
                if unnamed_buttons:
                    raise AssertionError(f"{destination}: enabled content buttons have no accessible name: {unnamed_buttons}")
                content_headings = [node for node in content_nodes if node["role"] == "AXHeading"]
                if not content_headings or any(not name(node) for node in content_headings):
                    raise AssertionError(f"{destination}: content blocks need named AX headings")

                # Destructive confirmations are exercised through their safe cancel branch.
                if destination in {"performance", "record"}:
                    clear = "Clear performance history…" if destination == "performance" else "Clear history…"
                    clear_node = next((x for x in nodes if x["role"] == "AXButton" and name(x) == clear), None)
                    if clear_node is None:
                        raise AssertionError(f"{destination}: missing clear control")
                    if destination == "record":
                        if clear_node["enabled"]:
                            driver.click(clear)
                            dialog = driver.wait(lambda n: any(x["role"] == "AXButton" and name(x) == "Clear history" for x in n),
                                                 "record clear confirmation")
                            driver.click("Cancel")
                    else:
                        driver.click(clear)
                        dialog = driver.wait(lambda n: any(x["role"] == "AXButton" and name(x) == "Clear readings" for x in n),
                                             "performance clear confirmation")
                        driver.click("Cancel")
                if destination == "cleanup":
                    driver.click("Inspect selected rule")
                    result = driver.wait(lambda n: any("cache-entry.bin" in name(x) for x in n),
                                         "cleanup fixture result")
                    driver.click(next(name(x) for x in elements(result) if "cache-entry.bin" in name(x)))
                    driver.wait(lambda n: any(x["role"] == "AXButton" and name(x) == "Review 1 item" for x in n),
                                "cleanup review action")
                    driver.click("Review 1 item")
                    dialog = driver.wait(lambda n: any(x["role"] == "AXButton" and name(x) == "Move to Trash" for x in n),
                                         "cleanup confirmation")
                    driver.click("Cancel")
                    if not caches.joinpath("cache-entry.bin").exists():
                        raise AssertionError("cleanup cancel changed fixture source")
                    report.append("cleanup.selection-review-cancel: PASS")
                if destination == "explore":
                    result = driver.wait(lambda n: any("Plan copy.txt. Source:" in name(x) for x in n),
                                         "explore fixture result")
                    row = next(name(x) for x in elements(result) if "Plan copy.txt. Source:" in name(x))
                    driver.click(row)
                    driver.wait(lambda n: any(x["role"] == "AXButton" and name(x) == "Review 1 item" for x in n),
                                "explore selection review")
                    driver.click("Review 1 item")
                    driver.wait(lambda n: any(x["role"] == "AXButton" and name(x) == "Move files to Trash" for x in n),
                                "explore delete confirmation")
                    driver.wait(lambda n: any(x["role"] == "AXButton" and name(x) == "Cancel" for x in n),
                                "explore cancel action")
                    driver.click("Cancel")
                    if not plot.joinpath("Plan copy.txt").exists():
                        raise AssertionError("explore cancel changed fixture source")
                if destination == "duplicates":
                    result = driver.wait(lambda n: any("Plan.txt" == name(x) for x in n), "duplicate group")
                    row = next(name(x) for x in elements(result) if name(x) == "Plan.txt")
                    driver.click(row)
                    driver.wait(lambda n: any(x["role"] == "AXButton" and name(x) == "Review 1 item" for x in n),
                                "duplicate selection review")
                    driver.click("Review 1 item")
                    driver.wait(lambda n: any(x["role"] == "AXButton" and name(x) == "Move copies to Trash" for x in n),
                                "duplicate confirmation")
                    driver.click("Cancel")
                    if not plot.joinpath("Plan copy.txt").exists():
                        raise AssertionError("duplicate cancel changed fixture source")
                if destination == "record":
                    driver.click("Export…")
                    time.sleep(0.3)
                    run(["osascript", "-e", f'tell application "System Events" to tell (first process whose unix id is {session.process.pid}) to key code 53'])
                report.append(f"module.{destination}.buttons-and-blocks: PASS "
                              f"({sum(node['role'] == 'AXButton' for node in content_nodes)} buttons, "
                              f"{len(content_headings)} headings)")
            finally:
                session.close()

        print("\n".join(report))
        print(f"Native UI fixture matrix passed: {len(report)} checkpoints. Destructive confirmations were cancelled; no move was accepted.")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
