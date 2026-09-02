#!/usr/bin/env python3
"""Hermetic regression tests for generate-public-release.py."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any, Dict, Optional, Tuple


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
GATE_PATH = REPOSITORY_ROOT / "Scripts" / "generate-public-release.py"
TRACKED_SOURCE = REPOSITORY_ROOT / "Configuration" / "published-release.json"

SPEC = importlib.util.spec_from_file_location("public_release_gate", GATE_PATH)
assert SPEC and SPEC.loader
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)


class PublicReleaseGateTests(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="coretend-public-release-test-")
        self.root = Path(self.temporary.name)
        self.current = json.loads(TRACKED_SOURCE.read_text(encoding="utf-8"))

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_gate(
        self,
        source: Dict[str, Any],
        *,
        dmg: Optional[Path] = None,
        zip_file: Optional[Path] = None,
        output_name: str = "output",
    ) -> Tuple[subprocess.CompletedProcess[str], Path]:
        source_path = self.root / f"{output_name}-published-release.json"
        source_path.write_text(json.dumps(source, indent=2) + "\n", encoding="utf-8")
        output = self.root / output_name
        command = [sys.executable, str(GATE_PATH), str(output), "--source", str(source_path)]
        if dmg is not None:
            command.extend(("--dmg-artifact", str(dmg)))
        if zip_file is not None:
            command.extend(("--zip-artifact", str(zip_file)))
        result = subprocess.run(command, text=True, capture_output=True, check=False)
        return result, output

    def assert_rejected(self, source: Dict[str, Any], expected: str) -> None:
        result, output = self.run_gate(source)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(expected, result.stderr)
        self.assertFalse((output / "latest.json").exists(), "validation failure wrote a partial manifest")
        self.assertFalse((output / "SHA256SUMS").exists(), "validation failure wrote partial checksums")

    def test_current_release_generates_exact_public_facts_without_internal_fields(self) -> None:
        result, output = self.run_gate(self.current)
        self.assertEqual(result.returncode, 0, result.stderr)
        latest_bytes = (output / "latest.json").read_bytes()
        latest = json.loads(latest_bytes)
        self.assertEqual(latest["version"], self.current["version"])
        self.assertEqual(latest["releaseTag"], self.current["tag"])
        self.assertEqual(latest["architecture"], "arm64")
        self.assertEqual(latest["minimumMacOS"], "14.0")
        self.assertIs(latest["signed"], self.current["signed"])
        self.assertIs(latest["notarized"], self.current["notarized"])
        self.assertEqual(latest["dmgURL"], self.current["dmgURL"])
        self.assertEqual(latest["dmgSHA256"], self.current["dmgSHA256"])
        self.assertNotIn("_comment", latest)
        self.assertNotIn("releaseNotes", latest)
        self.assertNotIn("generatedBy", latest)

        combined = latest_bytes.decode("utf-8") + (output / "SHA256SUMS").read_text(encoding="ascii")
        for forbidden in ("ClamAV", "Documentation/", "Configuration/", "Scripts/", "Release/", ".html", "/Users/"):
            self.assertNotIn(forbidden, combined)

        sums = (output / "SHA256SUMS").read_text(encoding="ascii").splitlines()
        self.assertEqual(sums[0], f"{self.current['zipSHA256']}  {self.current['zipName']}")
        self.assertEqual(sums[1], f"{self.current['dmgSHA256']}  {self.current['dmgName']}")
        self.assertEqual(sums[2], f"{hashlib.sha256(latest_bytes).hexdigest()}  latest.json")

    def test_generation_is_byte_reproducible(self) -> None:
        first_result, first = self.run_gate(self.current, output_name="first")
        second_result, second = self.run_gate(self.current, output_name="second")
        self.assertEqual(first_result.returncode, 0, first_result.stderr)
        self.assertEqual(second_result.returncode, 0, second_result.stderr)
        self.assertEqual((first / "latest.json").read_bytes(), (second / "latest.json").read_bytes())
        self.assertEqual((first / "SHA256SUMS").read_bytes(), (second / "SHA256SUMS").read_bytes())

    def test_future_release_requires_and_verifies_both_artifacts(self) -> None:
        future = copy.deepcopy(self.current)
        future.update(
            version="1.0.0-rc.1",
            tag="v1.0.0-rc.1",
            sourceCommit="1234567890abcdef1234567890abcdef12345678",
            releaseURL="https://github.com/ahmetbsbnr/coretend/releases/tag/v1.0.0-rc.1",
            publishedAt="2026-08-01T12:00:00Z",
            # This fixture exercises the un-pinned-checksum path, which is
            # independent of signing; keep it a consistent unsigned release.
            signed=False,
            notarized=False,
            dmgName="CoreTend-1.0.0-rc.1-arm64-unsigned.dmg",
            dmgURL="https://github.com/ahmetbsbnr/coretend/releases/download/v1.0.0-rc.1/CoreTend-1.0.0-rc.1-arm64-unsigned.dmg",
            zipName="CoreTend-1.0.0-rc.1-arm64-unsigned.zip",
            zipURL="https://github.com/ahmetbsbnr/coretend/releases/download/v1.0.0-rc.1/CoreTend-1.0.0-rc.1-arm64-unsigned.zip",
        )
        dmg = self.root / future["dmgName"]
        zip_file = self.root / future["zipName"]
        dmg.write_bytes(b"hermetic future dmg fixture\n")
        zip_file.write_bytes(b"hermetic future zip fixture\n")
        future["dmgSHA256"] = hashlib.sha256(dmg.read_bytes()).hexdigest()
        future["dmgSize"] = dmg.stat().st_size
        future["zipSHA256"] = hashlib.sha256(zip_file.read_bytes()).hexdigest()
        future["zipSize"] = zip_file.stat().st_size

        missing_result, _ = self.run_gate(future, output_name="missing-proof")
        self.assertNotEqual(missing_result.returncode, 0)
        self.assertIn("provide both", missing_result.stderr)

        result, output = self.run_gate(future, dmg=dmg, zip_file=zip_file, output_name="proved")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((output / "latest.json").read_text())["version"], "1.0.0-rc.1")

    def test_local_artifact_mismatch_is_rejected(self) -> None:
        dmg = self.root / self.current["dmgName"]
        dmg.write_bytes(b"not the published disk image")
        result, output = self.run_gate(self.current, dmg=dmg)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("size mismatch", result.stderr)
        self.assertFalse((output / "latest.json").exists())

    def test_placeholder_checksum_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.current)
        invalid["dmgSHA256"] = "0" * 64
        self.assert_rejected(invalid, "placeholder-like")

    def test_tag_version_divergence_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.current)
        invalid["tag"] = "v0.9.1-rc.2"
        self.assert_rejected(invalid, "tag must be exactly")

    def test_unverified_architecture_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.current)
        invalid["architecture"] = "universal"
        self.assert_rejected(invalid, "architecture must be")

    def test_unverified_macos_minimum_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.current)
        invalid["minimumMacOS"] = "13.0"
        self.assert_rejected(invalid, "minimumMacOS must be")

    def test_signed_but_not_notarized_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.current)
        invalid["signed"] = True
        invalid["notarized"] = False
        self.assert_rejected(invalid, "signed and notarized must agree")

    def test_notarized_but_not_signed_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.current)
        invalid["signed"] = False
        invalid["notarized"] = True
        self.assert_rejected(invalid, "signed and notarized must agree")

    def test_noncanonical_asset_url_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.current)
        invalid["dmgURL"] = "https://example.com/CoreTend.dmg"
        self.assert_rejected(invalid, "dmgURL does not match")

    def test_internal_path_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.current)
        invalid["_comment"] = "Generated from Documentation/private-release.json"
        self.assert_rejected(invalid, "internal repository path")

    def test_clamav_reference_is_rejected(self) -> None:
        invalid = copy.deepcopy(self.current)
        invalid["_comment"] = "Legacy ClamAV release"
        self.assert_rejected(invalid, "legacy ClamAV reference")

    def test_unreviewed_field_cannot_leak_into_public_output(self) -> None:
        invalid = copy.deepcopy(self.current)
        invalid["releaseNotes"] = "Documentation/Release/private.md"
        self.assert_rejected(invalid, "unreviewed fields")


if __name__ == "__main__":
    unittest.main(verbosity=2)
