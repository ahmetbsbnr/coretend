#!/usr/bin/env python3
"""Launch an app bundle executable with HOME and SQLite fully fixture-scoped."""

import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def main():
    repo = Path(__file__).resolve().parents[1]
    executable = Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else repo / ".build/debug/CoreTendApp"
    if len(sys.argv) > 2 or not executable.is_file() or not os.access(executable, os.X_OK):
        print(f"Usage: {Path(sys.argv[0]).name} [executable]; executable must exist", file=sys.stderr)
        return 64

    with tempfile.TemporaryDirectory(prefix="coretend-app-runtime-") as temporary:
        fixture = Path(temporary)
        temp_directory = fixture / "tmp"
        home = temp_directory / "home"
        store = temp_directory / "store"
        bundle = fixture / "CoreTend.app"
        contents = bundle / "Contents"
        macos = contents / "MacOS"
        for directory in (temp_directory, home, store, macos):
            directory.mkdir(parents=True, exist_ok=True)
        bundle_executable = macos / "CoreTendApp"
        shutil.copy2(executable, bundle_executable)
        bundle_executable.chmod(0o755)
        with (contents / "Info.plist").open("wb") as stream:
            plistlib.dump({
                "CFBundleExecutable": "CoreTendApp",
                "CFBundleIdentifier": "local.coretend.runtime-fixture",
                "CFBundleName": "CoreTend",
                "CFBundlePackageType": "APPL",
                "LSMinimumSystemVersion": "14.0",
            }, stream)

        environment = os.environ.copy()
        environment.update({
            "HOME": str(home),
            "CFFIXED_USER_HOME": str(home),
            "TMPDIR": str(temp_directory),
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": str(store),
        })
        process = subprocess.Popen(
            [str(bundle_executable)],
            cwd=fixture,
            env=environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            deadline = time.monotonic() + 8
            database = store / "CoreTend-Reconstruction" / "records.sqlite"
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    stderr = process.stderr.read() if process.stderr else ""
                    print(f"App exited before opening its fixture store (status {process.returncode}): {stderr}", file=sys.stderr)
                    return 1
                time.sleep(0.1)
            if not database.is_file():
                print("App did not create SQLite beneath the explicit fixture store.", file=sys.stderr)
                return 1
            if process.poll() is not None:
                print(f"App exited after opening its fixture store (status {process.returncode}).", file=sys.stderr)
                return 1
            print("App bundle executable stayed running and created SQLite only under isolated fixture store.")
            return 0
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
            if process.stderr:
                process.stderr.close()


if __name__ == "__main__":
    raise SystemExit(main())
