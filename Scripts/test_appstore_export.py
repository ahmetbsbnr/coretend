"""Exercise App Store export orchestration with fake packaging and Xcode, without signing/network."""
import os
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class AppStoreExportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="coretend-export-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "Scripts").mkdir()
        shutil.copy2(ROOT / "Scripts/appstore_export.sh", self.root / "Scripts/appstore_export.sh")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.write_command("make", '''#!/bin/bash
set -eu
mkdir -p Artifacts/CoreTend.app/Contents
printf '<plist version="1.0"><dict/></plist>' > Artifacts/CoreTend.app/Contents/Info.plist
printf 'package\n' >> "$EXPORT_TEST_CALLS"
''')
        self.write_command("xcodebuild", '''#!/bin/bash
set -eu
printf 'export\n' >> "$EXPORT_TEST_CALLS"
while [[ $# -gt 0 ]]; do
 case "$1" in
  -archivePath) archive="$2"; shift 2;;
  -exportOptionsPlist) options="$2"; shift 2;;
  -exportPath) output="$2"; shift 2;;
  *) shift;;
 esac
done
mkdir -p "$output"
cp "$options" "$output/options-observed.plist"
printf '%s\n' "$archive" >> "$EXPORT_TEST_ARCHIVES"
printf '%s\n' "$options" >> "$EXPORT_TEST_OPTIONS"
exit "${EXPORT_TEST_STATUS:-0}"
''')
        self.environment = os.environ.copy()
        for key in ("CORETEND_ASC_KEY_PATH", "CORETEND_ASC_KEY_ID", "CORETEND_ASC_ISSUER", "CORETEND_BUILD"):
            self.environment.pop(key, None)
        self.environment.update({
            "PATH": str(self.bin) + ":/usr/bin:/bin",
            "HOME": str(self.root / "home"),
            "TMPDIR": str(self.root) + "/",
            "EXPORT_TEST_CALLS": str(self.root / "calls"),
            "EXPORT_TEST_ARCHIVES": str(self.root / "archives"),
            "EXPORT_TEST_OPTIONS": str(self.root / "options"),
        })

    def write_command(self, name, source):
        command = self.bin / name
        command.write_text(source)
        command.chmod(0o755)

    def run_export(self, mode="export", **environment):
        return subprocess.run(["/bin/bash", "Scripts/appstore_export.sh", mode], cwd=self.root,
                              env=self.environment | environment, capture_output=True, text=True)

    def test_failed_export_can_be_retried_without_overwriting_archive(self):
        first = self.run_export(EXPORT_TEST_STATUS="70")
        self.assertEqual(first.returncode, 70, first.stderr)
        first_archive = Path((self.root / "archives").read_text().splitlines()[0])
        first_bytes = (first_archive / "Info.plist").read_bytes()
        second = self.run_export()
        self.assertEqual(second.returncode, 0, second.stderr)
        archives = (self.root / "archives").read_text().splitlines()
        self.assertEqual(len(set(archives)), 2)
        self.assertEqual((first_archive / "Info.plist").read_bytes(), first_bytes)

    def test_export_and_upload_use_explicit_destinations(self):
        for mode in ("export", "upload"):
            with self.subTest(mode=mode):
                result = self.run_export(mode, CORETEND_BUILD="202" if mode == "upload" else "201")
                self.assertEqual(result.returncode, 0, result.stderr)
                with (self.root / "Artifacts/AppStore" / ("202" if mode == "upload" else "201") / "options-observed.plist").open("rb") as stream:
                    options = plistlib.load(stream)
                self.assertEqual(options["destination"], mode)
                self.assertEqual(options["method"], "app-store-connect")
                self.assertFalse(options["manageAppVersionAndBuildNumber"])

    def test_incomplete_authentication_fails_before_packaging(self):
        result = self.run_export(CORETEND_ASC_KEY_PATH="/not-read/key.p8")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "calls").exists())

    def test_invalid_build_fails_before_packaging(self):
        for build in ("../other", "<bad>", "0"):
            with self.subTest(build=build):
                result = self.run_export(CORETEND_BUILD=build)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.root / "calls").exists())

    def test_temporary_export_options_are_removed(self):
        result = self.run_export(EXPORT_TEST_STATUS="70")
        self.assertEqual(result.returncode, 70, result.stderr)
        options = Path((self.root / "options").read_text().strip())
        self.assertFalse(options.exists())
        self.assertFalse(options.parent.exists())

    def test_invalid_mode_fails_without_side_effects(self):
        result = self.run_export("publish")
        self.assertEqual(result.returncode, 64)
        self.assertFalse((self.root / "calls").exists())


if __name__ == "__main__":
    unittest.main()
