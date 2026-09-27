#!/usr/bin/env python3
import os
import subprocess
import tempfile
from pathlib import Path


def run(script: Path, home: Path, app: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["HOME"] = str(home)
    return subprocess.run(
        ["bash", str(script), "--app", str(app), *arguments],
        text=True, capture_output=True, env=environment, check=False,
    )


def touch(path: Path, contents: str = "fixture") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents)


def main() -> None:
    script = Path(__file__).with_name("uninstall_local.sh")
    with tempfile.TemporaryDirectory(prefix="coretend-uninstall-test-") as temporary:
        root = Path(temporary)
        home = root / "home"
        app = home / "Applications" / "CoreTend.app"
        support = home / "Library" / "Application Support" / "CoreTend-Reconstruction"
        preferences = home / "Library" / "Preferences" / "local.coretend.reconstruction.plist"
        legacy_support = home / "Library" / "Application Support" / "MacCareLocal"
        legacy_preferences = home / "Library" / "Preferences" / "local.maccare.app.plist"
        touch(app / "Contents" / "Info.plist", "bundle fixture")
        touch(app / "Contents" / "MacOS" / "CoreTendApp", "executable fixture")
        touch(support / "records.sqlite")
        touch(preferences, "current preferences")
        touch(legacy_support / "legacy.sqlite")
        touch(legacy_preferences, "legacy preferences")

        preview = run(script, home, app)
        assert preview.returncode == 0, preview.stderr
        assert "dry-run" in preview.stdout
        assert app.exists() and support.exists() and preferences.exists() and legacy_support.exists() and legacy_preferences.exists()

        preserved = run(script, home, app, "--keep-data", "--yes")
        assert preserved.returncode == 0, preserved.stderr
        assert not app.exists() and support.exists() and preferences.exists()

        touch(app / "Contents" / "Info.plist", "bundle fixture")
        touch(app / "Contents" / "MacOS" / "CoreTendApp", "executable fixture")
        current_only = run(script, home, app, "--remove-all", "--yes")
        assert current_only.returncode == 0, current_only.stderr
        assert not app.exists() and not support.exists()
        assert not preferences.exists()
        assert legacy_support.exists() and legacy_preferences.exists(), "legacy data must stay by default"

        touch(app / "Contents" / "Info.plist", "bundle fixture")
        touch(app / "Contents" / "MacOS" / "CoreTendApp", "executable fixture")
        touch(support / "records.sqlite")
        opted_in = run(script, home, app, "--remove-all", "--include-legacy", "--yes")
        assert opted_in.returncode == 0, opted_in.stderr
        assert not app.exists() and not support.exists()
        assert not legacy_support.exists() and not legacy_preferences.exists()

        unsafe_app = root / "Outside.app"
        touch(unsafe_app / "Contents" / "Info.plist")
        touch(unsafe_app / "Contents" / "MacOS" / "CoreTendApp")
        linked_app = home / "Applications" / "CoreTend.app"
        linked_app.parent.mkdir(parents=True, exist_ok=True)
        linked_app.symlink_to(unsafe_app)
        refused = run(script, home, linked_app, "--remove-all", "--yes")
        assert refused.returncode != 0
        assert unsafe_app.exists(), "symlink target must remain untouched"

        linked_library_home = root / "linked-library-home"
        linked_library_home.mkdir()
        outside_library = root / "outside-library"
        outside_support = outside_library / "Application Support" / "CoreTend-Reconstruction"
        touch(outside_support / "records.sqlite", "outside fixture")
        (linked_library_home / "Library").symlink_to(outside_library)
        linked_app_inside_home = linked_library_home / "Applications" / "CoreTend.app"
        touch(linked_app_inside_home / "Contents" / "Info.plist")
        touch(linked_app_inside_home / "Contents" / "MacOS" / "CoreTendApp")
        ancestor_refused = run(script, linked_library_home, linked_app_inside_home, "--remove-all", "--yes")
        assert ancestor_refused.returncode != 0, "symlinked Library ancestor must block destructive mode"
        assert (linked_app_inside_home / "Contents" / "Info.plist").read_text() == "fixture"
        assert (outside_support / "records.sqlite").read_text() == "outside fixture"

    print("Local uninstaller passed isolated dry-run, opt-in legacy removal, and symlink refusal fixtures.")


if __name__ == "__main__":
    main()
