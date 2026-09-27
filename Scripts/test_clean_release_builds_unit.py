import tempfile
import unittest
from pathlib import Path

from Scripts import test_clean_release_builds as build_smoke


class ScratchPathOwnershipTests(unittest.TestCase):
    def test_failed_competing_link_creation_preserves_existing_scratch_link(self) -> None:
        self.assertTrue(
            hasattr(build_smoke, "temporary_scratch_link"),
            "build smoke must own and scope its scratch symlink cleanup",
        )
        with tempfile.TemporaryDirectory(prefix="coretend-scratch-link-test-") as temporary:
            root = Path(temporary)
            existing_scratch = root / "existing"
            competing_scratch = root / "competing"
            existing_scratch.mkdir()
            competing_scratch.mkdir()
            stable_path = root / "stable"
            stable_path.symlink_to(existing_scratch, target_is_directory=True)

            with self.assertRaises(FileExistsError):
                with build_smoke.temporary_scratch_link(stable_path, competing_scratch):
                    self.fail("a competing run must not take an occupied stable path")

            self.assertTrue(stable_path.is_symlink())
            self.assertEqual(stable_path.resolve(), existing_scratch.resolve())

    def test_cleanup_removes_own_link_but_preserves_replacement(self) -> None:
        self.assertTrue(
            hasattr(build_smoke, "temporary_scratch_link"),
            "build smoke must own and scope its scratch symlink cleanup",
        )
        with tempfile.TemporaryDirectory(prefix="coretend-scratch-link-test-") as temporary:
            root = Path(temporary)
            first_scratch = root / "first"
            replacement_scratch = root / "replacement"
            first_scratch.mkdir()
            replacement_scratch.mkdir()
            stable_path = root / "stable"

            with build_smoke.temporary_scratch_link(stable_path, first_scratch):
                self.assertEqual(stable_path.resolve(), first_scratch.resolve())
            self.assertFalse(stable_path.exists())
            self.assertFalse(stable_path.is_symlink())

            with build_smoke.temporary_scratch_link(stable_path, first_scratch):
                stable_path.unlink()
                stable_path.symlink_to(replacement_scratch, target_is_directory=True)

            self.assertTrue(stable_path.is_symlink())
            self.assertEqual(stable_path.resolve(), replacement_scratch.resolve())


if __name__ == "__main__":
    unittest.main()
