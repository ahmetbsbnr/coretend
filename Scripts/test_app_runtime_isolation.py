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

try:
    from .runtime_network_scope import internet_socket_processes
except ImportError:
    from runtime_network_scope import internet_socket_processes


def sqlite_artifacts_outside_store(fixture, store):
    fixture = Path(fixture).resolve()
    store = Path(store).resolve()
    database_suffixes = tuple(
        extension + journal
        for extension in (".sqlite", ".sqlite3", ".db")
        for journal in ("", "-wal", "-shm", "-journal")
    )
    outside = []
    for path in fixture.rglob("*"):
        if not path.is_file() or not path.name.lower().endswith(database_suffixes):
            continue
        resolved = path.resolve()
        try:
            resolved.relative_to(store)
        except ValueError:
            outside.append(resolved)
    return sorted(set(outside))


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

        installed_bundle = home / "Applications" / "CoreTend.app"
        installed_executable = installed_bundle / "Contents" / "MacOS" / "CoreTendApp"
        (home / "Applications").mkdir(parents=True)
        installation = subprocess.run(
            ["bash", str(repo / "Scripts/install_local.sh"), "--app", str(bundle), "--destination", str(home / "Applications")],
            cwd=fixture,
            capture_output=True,
            text=True,
            check=False,
        )
        if installation.returncode != 0:
            print(f"Fixture app installation failed: {installation.stderr}", file=sys.stderr)
            return 1
        if not installed_executable.is_file():
            print("Runtime smoke must launch the app from its temporary installed location.", file=sys.stderr)
            return 1

        environment = os.environ.copy()
        environment.update({
            "HOME": str(home),
            "CFFIXED_USER_HOME": str(home),
            "TMPDIR": str(temp_directory),
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": str(store),
        })
        process = subprocess.Popen(
            [str(installed_executable)],
            cwd=fixture,
            env=environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            deadline = time.monotonic() + 8
            next_socket_sample = time.monotonic()
            socket_samples = 0
            database = store / "CoreTend-Reconstruction" / "records.sqlite"
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    stderr = process.stderr.read() if process.stderr else ""
                    print(f"App exited before opening its fixture store (status {process.returncode}): {stderr}", file=sys.stderr)
                    return 1
                time.sleep(0.1)
                if database.is_file() and time.monotonic() >= next_socket_sample:
                    socket_processes = internet_socket_processes(process.pid)
                    if socket_processes:
                        print(f"Release app owns Internet sockets during isolated idle runtime: {sorted(socket_processes)}", file=sys.stderr)
                        return 1
                    socket_samples += 1
                    next_socket_sample = time.monotonic() + 0.5
            if not database.is_file():
                print("App did not create SQLite beneath the explicit fixture store.", file=sys.stderr)
                return 1
            unexpected_databases = sqlite_artifacts_outside_store(fixture, store)
            if unexpected_databases:
                paths = ", ".join(str(path) for path in unexpected_databases)
                print(f"SQLite artifacts appeared outside the explicit fixture store: {paths}", file=sys.stderr)
                return 1
            if process.poll() is not None:
                print(f"App exited after opening its fixture store (status {process.returncode}).", file=sys.stderr)
                return 1
            if socket_samples < 8:
                print(f"Expected at least 8 runtime Internet-socket samples, observed {socket_samples}.", file=sys.stderr)
                return 1
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)
            unexpected_databases = sqlite_artifacts_outside_store(fixture, store)
            if unexpected_databases:
                paths = ", ".join(str(path) for path in unexpected_databases)
                print(f"SQLite artifacts appeared outside the fixture store after app shutdown: {paths}", file=sys.stderr)
                return 1
            removal = subprocess.run(
                ["bash", str(repo / "Scripts/uninstall_local.sh"), "--app", str(installed_bundle), "--keep-data", "--yes"],
                cwd=fixture,
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )
            if removal.returncode != 0:
                print(f"Fixture app removal failed: {removal.stderr}", file=sys.stderr)
                return 1
            if installed_bundle.exists() or not database.is_file():
                print("Uninstall must remove only the installed app and preserve fixture data.", file=sys.stderr)
                return 1
            print(f"Installed app launched with no Internet sockets in {socket_samples} samples, then removed; fixture SQLite data stayed under the isolated store.")
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
