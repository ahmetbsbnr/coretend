import tempfile
import unittest
from pathlib import Path

from Scripts import test_clean_release_builds as build_smoke


class ScratchPathOwnershipTests(unittest.TestCase):
    def test_reset_clears_only_owned_scratch_contents(self) -> None:
        self.assertTrue(hasattr(build_smoke, "reset_scratch_directory"))
        with tempfile.TemporaryDirectory(prefix="coretend-scratch-link-test-") as temporary:
            root = Path(temporary)
            scratch = root / "scratch"
            scratch.mkdir()
            (scratch / "build-output").write_text("temporary")
            neighbor = root / "keep.txt"
            neighbor.write_text("preserve")

            build_smoke.reset_scratch_directory(scratch, root)

            self.assertEqual(list(scratch.iterdir()), [])
            self.assertEqual(neighbor.read_text(), "preserve")

    def test_reset_rejects_symlink_and_path_outside_owned_root(self) -> None:
        self.assertTrue(hasattr(build_smoke, "reset_scratch_directory"))
        with tempfile.TemporaryDirectory(prefix="coretend-scratch-link-test-") as temporary:
            root = Path(temporary) / "owned"
            root.mkdir()
            outside = Path(temporary) / "outside"
            outside.mkdir()
            (outside / "keep.txt").write_text("preserve")
            link = root / "scratch-link"
            link.symlink_to(outside, target_is_directory=True)

            with self.assertRaises(RuntimeError):
                build_smoke.reset_scratch_directory(link, root)
            with self.assertRaises(RuntimeError):
                build_smoke.reset_scratch_directory(outside, root)
            self.assertEqual((outside / "keep.txt").read_text(), "preserve")


if __name__ == "__main__":
    unittest.main()
