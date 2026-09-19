#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
"""A realistic application inventory: ~100 bundles, not six.

Six applications validate nothing about a table. They fit on one screen with no
scrolling, sorting is indistinguishable from not sorting, search always matches
everything, and the layout's real problem — what a dense list of long names and
long paths does to the columns — never appears.

Produces the same `<store>/ApplicationFixtures` layout `seed-apps.sh` does, so
`AppDiscovery` reads it unchanged. Bundles are cloned from a small block pool
(see seed-home.py for why clones rather than sparse files), so an inventory
reporting ~90 GB costs about 200 MB of real disk.
"""

import os
import shutil
import subprocess
import sys
import random
from pathlib import Path

RNG = random.Random(20260919)
KB, MB = 1024, 1024 * 1024
ANCHOR = 1789000000.0

# Kept small on purpose. The pool is the only real disk this fixture costs, and
# an inventory does not need a 900 MB block to prove a table sorts by size — the
# spread between rows is what matters, not the absolute ceiling.
POOL = {"xs": 256 * KB, "s": 4 * MB, "m": 24 * MB, "l": 90 * MB, "xl": 300 * MB}

# Apple applications live in /Applications too and are a different kind of row:
# the product must never offer to remove them, so they have to be in the fixture
# for that behaviour to be visible at all.
APPLE = ["Safari", "Mail", "Calendar", "Notes", "Reminders", "Photos", "Music",
         "Podcasts", "TV", "News", "Stocks", "Maps", "Messages", "FaceTime",
         "Contacts", "Freeform", "Shortcuts", "Books", "Home", "Weather",
         "Preview", "TextEdit", "Terminal", "Xcode", "Keynote", "Pages", "Numbers"]

THIRD_PARTY = [
    ("Figma", "com.figma.Desktop"), ("Slack", "com.tinyspeck.slackmacgap"),
    ("Blender", "org.blenderfoundation.blender"), ("Zoom", "us.zoom.xos"),
    ("Pixelmator Pro", "com.pixelmatorteam.pixelmator.x"),
    ("Visual Studio Code", "com.microsoft.VSCode"), ("Docker", "com.docker.docker"),
    ("Spotify", "com.spotify.client"), ("Discord", "com.hnc.Discord"),
    ("Notion", "notion.id"), ("Obsidian", "md.obsidian"), ("Linear", "com.linear"),
    ("1Password", "com.1password.1password"), ("Rectangle", "com.knollsoft.Rectangle"),
    ("IINA", "com.colliderli.iina"), ("Transmit", "com.panic.Transmit"),
    ("Nova", "com.panic.Nova"), ("Sketch", "com.bohemiancoding.sketch3"),
    ("Affinity Photo", "com.seriflabs.affinityphoto"),
    ("DaVinci Resolve", "com.blackmagic-design.DaVinciResolve"),
    ("OBS Studio", "com.obsproject.obs-studio"), ("Handbrake", "fr.handbrake.HandBrake"),
    ("Postico", "at.eggerapps.Postico"), ("TablePlus", "com.tinyapp.TablePlus"),
    ("Proxyman", "com.proxyman.NSProxy"), ("Paw", "com.luckymarmot.Paw"),
    ("Kaleidoscope", "app.kaleidoscope"), ("Tower", "com.fournova.Tower3"),
    ("Fork", "com.DanPristupov.Fork"), ("Cyberduck", "ch.sudo.cyberduck"),
    ("Alfred", "com.runningwithcrayons.Alfred"), ("Raycast", "com.raycast.macos"),
    ("CleanShot X", "pl.maketheweb.cleanshotx"), ("Bartender", "com.surteesstudios.Bartender"),
    ("iStat Menus", "com.bjango.istatmenus"), ("Little Snitch", "at.obdev.littlesnitch"),
    ("Arc", "company.thebrowser.Browser"), ("Firefox", "org.mozilla.firefox"),
    ("Google Chrome", "com.google.Chrome"), ("Brave Browser", "com.brave.Browser"),
]

SUFFIXES = ["Helper", "Updater", "Agent", "Installer", "Uninstaller"]


def build_pool(root: Path) -> dict:
    pool_dir = root / ".pool"
    pool_dir.mkdir(parents=True, exist_ok=True)
    pool = {}
    for name, size in POOL.items():
        path = pool_dir / name
        if not path.exists() or path.stat().st_size != size:
            with open(path, "wb") as handle:
                handle.write(os.urandom(size))
        pool[name] = path
    return pool


PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>{name}</string>
<key>CFBundleIdentifier</key><string>{bundle}</string>
<key>CFBundleShortVersionString</key><string>{version}</string>
<key>CFBundleExecutable</key><string>{exe}</string>
</dict></plist>
"""


def make_app(apps_dir: Path, pool: dict, name: str, bundle: str, version: str,
             size_key: str, days_ago: float):
    contents = apps_dir / f"{name}.app" / "Contents"
    (contents / "MacOS").mkdir(parents=True, exist_ok=True)
    (contents / "Resources").mkdir(parents=True, exist_ok=True)
    exe = name.replace(" ", "")
    (contents / "Info.plist").write_text(
        PLIST.format(name=name, bundle=bundle, version=version, exe=exe))
    target = contents / "MacOS" / exe
    if target.exists():
        target.unlink()
    subprocess.run(["cp", "-c", str(pool[size_key]), str(target)], check=True)
    # A unique tail per bundle. Without it every app cloned from one pool file
    # reports byte-identical size, and a capture showed twenty rows all reading
    # "25.2 MB" — which makes the Size column look broken rather than sorted.
    # Appending breaks the clone for the appended blocks only, so the cost is
    # the tail, not the file.
    tail = RNG.randrange(64 * KB, 9 * MB)
    with open(target, "ab") as handle:
        handle.write(os.urandom(tail))
    os.chmod(target, 0o755)
    when = ANCHOR - days_ago * 86400
    os.utime(contents / f"../", (when, when))
    os.utime(apps_dir / f"{name}.app", (when, when))


def seed(store: Path):
    fx = store / "ApplicationFixtures"
    if fx.exists():
        shutil.rmtree(fx)
    for sub in ["Applications", "Home/Applications", "Home/Library/Application Support",
                "Home/Library/Caches", "Home/Library/Preferences", "SystemLibrary", "Caskroom"]:
        (fx / sub).mkdir(parents=True, exist_ok=True)
    pool = build_pool(fx)
    apps = fx / "Applications"

    made = 0
    for index, name in enumerate(APPLE):
        make_app(apps, pool, name, f"com.apple.{name.replace(' ', '').lower()}",
                 "26.0", "xl" if name == "Xcode" else ("m" if index % 4 == 0 else "s"),
                 days_ago=index % 30)
        made += 1

    for index, (name, bundle) in enumerate(THIRD_PARTY):
        size = ["s", "m", "l", "m", "s", "xs"][index % 6]
        make_app(apps, pool, name, bundle, f"{2 + index % 9}.{index % 13}.{index % 7}",
                 size, days_ago=index * 1.5)
        made += 1
        # Associated data, so the inspector has something real to list and the
        # "remove with its files" figure is not always the bundle size alone.
        if index % 3 == 0:
            support = fx / "Home/Library/Application Support" / name
            support.mkdir(parents=True, exist_ok=True)
            subprocess.run(["cp", "-c", str(pool["m"]), str(support / "data.db")], check=True)
        if index % 4 == 1:
            cache = fx / "Home/Library/Caches" / bundle
            cache.mkdir(parents=True, exist_ok=True)
            subprocess.run(["cp", "-c", str(pool["s"]), str(cache / "Cache.db")], check=True)
        (fx / "Home/Library/Preferences" / f"{bundle}.plist").touch()

    # Auxiliary bundles: the rows a person is most likely to misread as
    # removable applications.
    for index, (name, bundle) in enumerate(THIRD_PARTY[:18]):
        suffix = SUFFIXES[index % len(SUFFIXES)]
        make_app(apps, pool, f"{name} {suffix}", f"{bundle}.{suffix.lower()}",
                 "1.0", "xs", days_ago=index * 2)
        made += 1

    # A handful in ~/Applications rather than /Applications, so the Source
    # column has more than one value to sort by.
    for index, (name, bundle) in enumerate(THIRD_PARTY[20:32]):
        make_app(fx / "Home/Applications", pool, name + " Beta", bundle + ".beta",
                 "0.9", "s", days_ago=index)
        made += 1

    # Long names, because the Name column has to cope with them and a fixture
    # of tidy nine-character names proves it does not.
    for index, long_name in enumerate([
        "A Very Long Application Name That Someone Actually Shipped",
        "Enterprise Resource Planning Client (Legacy Edition)",
        "Screen Recording and Annotation Studio Professional",
    ]):
        make_app(apps, pool, long_name, f"com.example.long{index}", "1.0", "xs",
                 days_ago=index * 10)
        made += 1

    return fx, made


def main():
    if len(sys.argv) < 2:
        print("usage: seed-apps-large.py <store-dir>", file=sys.stderr)
        return 2
    store = Path(sys.argv[1]).resolve()
    if not (str(store).startswith("/private/var/folders/")
            or str(store).startswith("/var/folders/")
            or str(store).startswith("/tmp/")
            or str(store).startswith("/private/tmp/")):
        print(f"refusing to seed outside a temporary root: {store}", file=sys.stderr)
        return 2
    fx, made = seed(store)
    real = subprocess.run(["du", "-sh", str(fx / ".pool")],
                          capture_output=True, text=True).stdout.split()[0]
    print(f"seeded {fx} — {made} applications, {real} of real blocks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
