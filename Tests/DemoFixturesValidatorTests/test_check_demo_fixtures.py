import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
CHECKER = REPO_ROOT / "Scripts" / "check-demo-fixtures.py"
CANONICAL = REPO_ROOT / "Resources" / "DemoFixtures" / "coretend-product.json"


class DemoFixtureValidatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads(CANONICAL.read_text(encoding="utf-8"))

    def run_checker(self, fixture_path):
        return subprocess.run(
            [sys.executable, str(CHECKER), str(fixture_path)],
            capture_output=True,
            text=True,
            check=False,
        )

    def run_mutation(self, mutate, *, allow_nan=False):
        document = json.loads(json.dumps(self.fixture))
        mutate(document)
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "fixture.json"
            path.write_text(
                json.dumps(document, allow_nan=allow_nan, ensure_ascii=False),
                encoding="utf-8",
            )
            return self.run_checker(path)

    def test_canonical_fixture_passes(self):
        result = self.run_checker(CANONICAL)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("privacy-safe example fixture", result.stdout)

    def test_personal_user_path_fails(self):
        synthetic_home = "/Users/" + "alice"
        result = self.run_mutation(
            lambda document: document["modules"][1]["data"]["items"][0].update(
                path=synthetic_home + "/Library/Caches/private"
            )
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(f"personal user path '{synthetic_home}' is forbidden", result.stderr)

    def test_email_and_secret_fail(self):
        def mutate(document):
            document["identity"]["contact"] = "owner@example.com"
            # Assemble the synthetic token at runtime so the test repository
            # never contains a literal that resembles a usable credential.
            document["identity"]["apiToken"] = "ghp_" + ("a" * 32)

        result = self.run_mutation(mutate)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("email addresses are forbidden", result.stderr)
        self.assertIn("secret-bearing keys are forbidden", result.stderr)
        self.assertIn("value resembles a secret", result.stderr)

    def test_total_mismatch_fails(self):
        result = self.run_mutation(
            lambda document: document["modules"][2]["data"].update(totalBytes=1)
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("total mismatch", result.stderr)

    def test_hidden_module_claimed_public_fails(self):
        result = self.run_mutation(
            lambda document: document["modules"][-1].update(id="similar-images", public=True)
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hidden module 'similar-images' cannot be claimed as public", result.stderr)

    def test_non_finite_number_fails(self):
        result = self.run_mutation(
            lambda document: document["modules"][1]["data"].update(totalBytes=float("nan")),
            allow_nan=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("non-finite JSON number", result.stderr)

    def test_retired_preview_mode_field_fails(self):
        result = self.run_mutation(
            lambda document: document["modules"][0]["data"].update(dryRunEnabled=True)
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("retired preview-mode data is forbidden", result.stderr)


if __name__ == "__main__":
    unittest.main()
