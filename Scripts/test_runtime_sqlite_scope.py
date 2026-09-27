import tempfile
import unittest
from pathlib import Path

from Scripts.test_app_runtime_isolation import sqlite_artifacts_outside_store


class RuntimeSQLiteScopeTests(unittest.TestCase):
    def test_accepts_database_and_sidecars_under_fixture_store(self):
        with tempfile.TemporaryDirectory(prefix="coretend-runtime-scope-") as temporary:
            fixture = Path(temporary)
            store = fixture / "store"
            store.mkdir()
            (store / "records.sqlite").touch()
            (store / "records.sqlite-wal").touch()
            (store / "records.sqlite-shm").touch()

            self.assertEqual(sqlite_artifacts_outside_store(fixture, store), [])

    def test_rejects_sqlite_database_or_sidecar_outside_store(self):
        with tempfile.TemporaryDirectory(prefix="coretend-runtime-scope-") as temporary:
            fixture = Path(temporary)
            store = fixture / "store"
            store.mkdir()
            outside = fixture / "home" / "Library" / "Caches"
            outside.mkdir(parents=True)
            stray = outside / "cache.db-journal"
            stray.touch()

            self.assertEqual(sqlite_artifacts_outside_store(fixture, store), [stray.resolve()])


if __name__ == "__main__":
    unittest.main()
