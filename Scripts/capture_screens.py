#!/usr/bin/env python3
"""Capture every CoreTend screen for visual review (gate G1).

Installs the packaged app into a temporary HOME/store fixture, launches it once per
screen, language and appearance, captures only its window, then writes an HTML contact
sheet. No real HOME, store or Trash is touched and nothing is clicked. Captures are
written under Artifacts/ (git-ignored) unless --output says otherwise.

Needs Screen Recording permission for the process running this script, and, for the
Settings and command-palette shots, Accessibility permission for keystrokes.
"""

import argparse
import datetime
import html
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

DESTINATIONS = ["overview", "explore", "cleanup", "duplicates", "applications", "integrity", "performance", "record"]
LANGUAGES = ["fr", "en"]
APPEARANCES = ["light", "dark"]
# Extra surfaces reached from Overview: (name, onboarding completed?, keystroke after launch)
EXTRAS = [("onboarding", "0", None), ("settings", "1", ","), ("palette", "1", "k")]


def shots():
    """Every capture as (name, destination, onboarding_completed, keystroke, language, appearance)."""
    planned = []
    for name in DESTINATIONS:
        for language in LANGUAGES:
            for appearance in APPEARANCES:
                planned.append((name, name, "1", None, language, appearance))
    for name, onboarding, key in EXTRAS:
        for language in LANGUAGES:
            for appearance in APPEARANCES:
                planned.append((name, "overview", onboarding, key, language, appearance))
    return planned


def file_name(name, language, appearance):
    return f"{name}-{language}-{appearance}.png"


def contact_sheet(results, generated):
    """HTML page: one row per surface, one column per language/appearance pair."""
    columns = [(language, appearance) for language in LANGUAGES for appearance in APPEARANCES]
    rows = []
    for name in DESTINATIONS + [extra[0] for extra in EXTRAS]:
        cells = []
        for language, appearance in columns:
            status = results.get((name, language, appearance), "not run")
            image = file_name(name, language, appearance)
            if status == "ok":
                cells.append(f'<td><a href="{image}"><img src="{image}" alt="{html.escape(name)} {language} {appearance}" loading="lazy"></a></td>')
            else:
                cells.append(f'<td class="missing">{html.escape(status)}</td>')
        rows.append(f"<tr><th scope=\"row\">{html.escape(name)}</th>{''.join(cells)}</tr>")
    header = "".join(f"<th scope=\"col\">{language.upper()} · {appearance}</th>" for language, appearance in columns)
    return f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><title>CoreTend — captures G1</title>
<style>
body {{ font: 14px -apple-system, system-ui, sans-serif; margin: 24px; background: #f4f4f2; color: #1b1e22; }}
table {{ border-collapse: collapse; }} th, td {{ padding: 8px; vertical-align: top; text-align: left; }}
img {{ width: 320px; border: 1px solid #c9c9c4; border-radius: 6px; display: block; }}
.missing {{ color: #8a4b00; width: 320px; }}
</style></head><body>
<h1>CoreTend — captures pour la séance G1</h1>
<p>Générées le {html.escape(generated)} depuis un paquet local, dans un HOME et un store temporaires (état initial de chaque écran). Cliquer une capture pour la taille réelle.</p>
<table><thead><tr><th></th>{header}</tr></thead><tbody>
{chr(10).join(rows)}
</tbody></table></body></html>
"""


# --in-use: each destination opens a folder by itself (fixture-only CORETEND_TEST_SCAN_ROOT), so the
# captures show screens in use. Explore, Duplicates and Cleanup read a generated demo folder inside the
# fixture HOME; Applications and Integrity read /System/Applications (the same on every Mac, read only).
DEMO_FILES = {
    "Greenhouse/Photos/Spring garden.heic": 6, "Greenhouse/Photos/Seedlings macro.heic": 4,
    "Greenhouse/Photos/Glasshouse at dusk.jpg": 3, "Greenhouse/Photos/Tomato harvest.jpg": 2,
    "Greenhouse/Videos/Timelapse — first leaves.mov": 90, "Greenhouse/Videos/Garden tour.mp4": 55,
    "Greenhouse/Projects/Greenhouse plans.key": 42, "Greenhouse/Projects/Irrigation model.numbers": 7,
    "Greenhouse/Projects/Seed catalogue.pdf": 12, "Greenhouse/Music/Rain on glass.m4a": 9,
    "Greenhouse/Downloads/Planting guide.pdf": 12, "Greenhouse/Downloads/Garden app installer.dmg": 70,
    "Greenhouse/Downloads/Old photos.zip": 64, "Greenhouse/Downloads/Spring garden copy.heic": 6,
    "Greenhouse/Archive/Tomato harvest.jpg": 2, "Greenhouse/Archive/Timelapse — first leaves.mov": 90,
    "Library/Caches/com.example.browser/Cache.db": 38, "Library/Caches/com.example.browser/fsCachedData/a1": 14,
    "Library/Caches/com.example.photos/thumbnails.db": 22, "Library/Caches/com.example.music/artwork/cover-01": 6,
    "Library/Caches/com.example.maps/tiles.cache": 31,
}
# Exact copies (same bytes), so Duplicates finds real pairs.
DEMO_COPIES = {
    "Greenhouse/Downloads/Planting guide.pdf": "Greenhouse/Projects/Seed catalogue.pdf",
    "Greenhouse/Downloads/Spring garden copy.heic": "Greenhouse/Photos/Spring garden.heic",
    "Greenhouse/Archive/Tomato harvest.jpg": "Greenhouse/Photos/Tomato harvest.jpg",
    "Greenhouse/Archive/Timelapse — first leaves.mov": "Greenhouse/Videos/Timelapse — first leaves.mov",
}
IN_USE_ROOTS = {"explore": "Greenhouse", "duplicates": "Greenhouse", "cleanup": "Library/Caches",
                "applications": "/System/Applications", "integrity": "/System/Applications"}


def demo_fixture(home):
    for relative, megabytes in DEMO_FILES.items():
        if relative in DEMO_COPIES:
            continue
        path = home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "wb") as handle:
            for _ in range(megabytes):
                handle.write(os.urandom(1 << 20))
    for copy, source in DEMO_COPIES.items():
        target = home / copy
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((home / source).read_bytes())


def run(command, **kwargs):
    return subprocess.run(command, text=True, capture_output=True, check=False, **kwargs)


def build_helper(repo, work):
    helper = work / "capture_window_helper"
    result = run(["swiftc", "-O", str(repo / "Scripts/capture_window_helper.swift"), "-o", str(helper)])
    if result.returncode:
        sys.exit(f"Could not build the window helper:\n{result.stderr}")
    return helper


def package(repo, work):
    artifacts = work / "artifacts"
    environment = dict(os.environ, CORETEND_ARTIFACT_DIR=str(artifacts))
    result = run(["bash", str(repo / "Scripts/package_local.sh")], cwd=repo, env=environment)
    if result.returncode:
        sys.exit(f"Packaging failed:\n{result.stdout}\n{result.stderr}")
    return artifacts / "CoreTend.app"


def install(repo, app, home):
    (home / "Applications").mkdir(parents=True)
    result = run(["bash", str(repo / "Scripts/install_local.sh"), "--app", str(app), "--destination", str(home / "Applications")])
    if result.returncode:
        sys.exit(f"Fixture installation failed:\n{result.stderr}")
    return home / "Applications/CoreTend.app/Contents/MacOS/CoreTendApp"


def send_keystroke(pid, key):
    script = (f'tell application "System Events"\n set frontmost of (first process whose unix id is {pid}) to true\n'
              f' delay 0.4\n keystroke "{key}" using command down\nend tell')
    return run(["osascript", "-e", script])


def capture(executable, helper, fixture, shot, output, in_use=False):
    name, destination, onboarding, key, language, appearance = shot
    store = fixture / "store"
    environment = {
        "PATH": "/usr/bin:/bin",
        "HOME": str(fixture / "home"),
        "CFFIXED_USER_HOME": str(fixture / "home"),
        "TMPDIR": str(fixture / "tmp") + "/",
        "CORETEND_TEST_MODE": "1",
        "CORETEND_TEST_STORE_DIR": str(store),
        "CORETEND_TEST_ONBOARDING_COMPLETED": onboarding,
        "CORETEND_TEST_LANGUAGE": language,
        "CORETEND_TEST_APPEARANCE": appearance,
        "CORETEND_TEST_LAST_DESTINATION": destination,
    }
    if in_use:
        environment["CORETEND_TEST_WINDOW_SIZE"] = "1440x900"  # 2880 × 1800 px: the App Store's 16:10 size
    root = IN_USE_ROOTS.get(name) if in_use else None
    if root:
        environment["CORETEND_TEST_SCAN_ROOT"] = root if root.startswith("/") else str(fixture / "home" / root)
        if name == "cleanup":
            environment["CORETEND_TEST_CLEANUP_RULE"] = "cleanup.usercaches"
    process = subprocess.Popen([str(executable)], env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        window = None
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline and window is None:
            found = run([str(helper), "window", str(process.pid)])
            window = found.stdout.strip() if found.returncode == 0 else None
            if window is None:
                time.sleep(0.3)
        if window is None:
            return "window not found"
        if key:
            sent = send_keystroke(process.pid, key)
            if sent.returncode:
                return "keystroke refused (Accessibility permission?)"
        time.sleep(9 if root else 1.5)  # the first layout and transitions; a scan and its sizes when in use
        target = output / file_name(name, language, appearance)
        for attempt in range(3):
            # The window number can change while SwiftUI settles its first scene; look it up again.
            found = run([str(helper), "window", str(process.pid)])
            window = found.stdout.strip() if found.returncode == 0 else window
            shot_result = run(["screencapture", "-x", "-o", "-l", window, str(target)])
            if shot_result.returncode == 0 and target.exists():
                return "ok"
            time.sleep(1)
        return f"screencapture failed: {shot_result.stderr.strip()}"
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()


def main():
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--output", type=Path, default=repo / "Artifacts/Captures" / datetime.date.today().isoformat())
    parser.add_argument("--only", help="capture only this surface (e.g. overview, settings)")
    parser.add_argument("--in-use", action="store_true", help="open a demo folder in each destination (App Store captures)")
    arguments = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="coretend-captures-") as temporary:
        work = Path(temporary).resolve()
        helper = build_helper(repo, work)
        if run([str(helper), "preflight"]).returncode != 0:
            sys.exit("Screen Recording permission is missing for this terminal/agent. Grant it in System Settings › "
                     "Privacy & Security › Screen & System Audio Recording, restart the terminal, then rerun.")
        app = package(repo, work)
        fixture = work / "fixture"
        for directory in ("home", "store", "tmp"):
            (fixture / directory).mkdir(parents=True)
        executable = install(repo, app, fixture / "home")
        if arguments.in_use:
            demo_fixture(fixture / "home")
        output = arguments.output.resolve()
        output.mkdir(parents=True, exist_ok=True)
        results = {}
        for shot in shots():
            if arguments.only and shot[0] != arguments.only:
                continue
            status = capture(executable, helper, fixture, shot, output, arguments.in_use)
            results[(shot[0], shot[4], shot[5])] = status
            print(f"{status:<10} {file_name(shot[0], shot[4], shot[5])}")
        generated = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        (output / "index.html").write_text(contact_sheet(results, generated), encoding="utf-8")
    failed = [key for key, status in results.items() if status != "ok"]
    print(f"{len(results) - len(failed)}/{len(results)} captures; contact sheet: {output / 'index.html'}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
