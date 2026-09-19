#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
"""Builds the synthetic home the scan modules read in Visual Beta.

One home serves Cleanup, Explore and Duplicates: they scan the same tree and
each cares about a different property of it, so three separate fixtures would
be three things to keep consistent for no gain.

## Why APFS clones rather than sparse files

`SpaceLensEngine` sizes a file by `totalFileAllocatedSize`, falling back to
`fileSize`. A sparse file reports an allocated size near zero, so an Explore
fixture built from sparse files would draw a treemap of nothing — the fixture
would be testing the wrong number.

`cp -c` (clonefile) gives a file that reports its full logical *and* allocated
size while sharing its blocks with the original, so a tree that says it holds
40 GB costs about 90 MB of real disk. Clones of one source are also
byte-identical, which is what `DuplicateEngine` needs: it groups by size, then
partial hash, then full SHA-256, and only genuinely identical content forms a
group.

Deterministic: fixed names, fixed sizes, fixed modification dates seeded from a
constant. Two runs produce the same tree, so a capture taken today matches one
taken next week.
"""

import os
import shutil
import subprocess
import sys
import random
from pathlib import Path

# Fixed seed: the shuffle that spreads duplicates across folders must land the
# same way every run, or the Duplicates capture reorders between builds.
RNG = random.Random(20260919)

KB = 1024
MB = 1024 * KB

# The block pool. Every file in the tree is a clone of one of these, so real
# disk cost is the sum of this list and nothing more.
POOL_SIZES = {
    "xs": 4 * KB,
    "s": 96 * KB,
    "m": 2 * MB,
    "l": 24 * MB,
    "xl": 180 * MB,
}


def build_pool(root: Path) -> dict:
    """Random bytes, not zeros: a zero-filled file can be stored as a hole, and
    the allocated size this fixture depends on would collapse back to nothing.

    The pool lives *beside* the home, never inside it: nested, Explore charted
    it as a 216 MB folder named ".pool" and presented the fixture's own
    scaffolding as the user's data."""
    pool_dir = root.parent / (root.name + "-pool")
    pool_dir.mkdir(parents=True, exist_ok=True)
    pool = {}
    for name, size in POOL_SIZES.items():
        path = pool_dir / name
        if not path.exists() or path.stat().st_size != size:
            with open(path, "wb") as handle:
                handle.write(os.urandom(size))
        pool[name] = path
    return pool


def clone(src: Path, dst: Path, mtime_days_ago: float = 0):
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        dst.unlink()
    # -c asks for a clone and fails rather than silently copying, which is the
    # behaviour we want: a silent fallback to a real copy would write tens of
    # gigabytes to the developer's disk.
    subprocess.run(["cp", "-c", str(src), str(dst)], check=True)
    if mtime_days_ago:
        when = ANCHOR - mtime_days_ago * 86400
        os.utime(dst, (when, when))


# A fixed instant, so "modified 3 days ago" is stable across runs.
ANCHOR = 1789000000.0


def seed(home: Path):
    if home.exists():
        shutil.rmtree(home)
    home.mkdir(parents=True)
    pool = build_pool(home)

    # ---- Cleanup: categories, with a spread of sizes -------------------
    vendors = ["com.adobe.Photoshop", "com.apple.Safari", "com.google.Chrome",
               "com.figma.Desktop", "com.spotify.client", "com.slack.Slack",
               "com.docker.docker", "com.microsoft.VSCode", "org.mozilla.firefox",
               "com.jetbrains.intellij"]
    for index, vendor in enumerate(vendors):
        base = home / "Library/Caches" / vendor
        for n in range(18):
            size = "m" if n % 6 == 0 else ("s" if n % 2 else "xs")
            clone(pool[size], base / f"Cache-{n:03d}.db", mtime_days_ago=3 + index)
        clone(pool["l"], base / "Code Cache/index.blob", mtime_days_ago=2 + index)

    for n in range(14):
        name = ["Xcode_16.2.xip", "Docker.dmg", "node-v22.pkg", "Figma.zip",
                "backup-2025-11.tar.gz", "dataset.csv.zip", "Sketch.dmg"][n % 7]
        clone(pool["xl" if n % 4 == 0 else "l"],
              home / "Downloads" / f"{n:02d}-{name}", mtime_days_ago=20 + n * 4)

    for n in range(120):
        clone(pool["xs"], home / "Library/Logs/DiagnosticReports"
              / f"crash-2026-09-{n % 28 + 1:02d}-{n:03d}.ips", mtime_days_ago=n % 60)

    for project in ["CoreTend", "Portfolio", "StagePilot", "Legacy-iOS",
                    "Experiments", "ClientWork", "Prototype-3", "Archive-2024"]:
        base = home / "Library/Developer/Xcode/DerivedData" / f"{project}-abc{len(project)}def"
        clone(pool["xl"], base / "Build/Products/Debug/binary", mtime_days_ago=8)
        for n in range(9):
            clone(pool["m"], base / f"Index/DataStore/unit-{n}.store", mtime_days_ago=8)

    # Deliberately risky-looking: recent, in a protected-by-convention place.
    # Cleanup must show these as protected rather than offer them for removal.
    for name in ["thesis-final.docx", "signed-contract.pdf", "taxes-2025.numbers"]:
        clone(pool["s"], home / "Documents" / name, mtime_days_ago=1)

    # ---- Explore: depth, long paths, unbalanced branches ---------------
    deep = home / "Documents/Work/Clients/Northwind/2026/Q3/Deliverables/Final/Approved"
    for n in range(6):
        clone(pool["m"], deep / f"a-deliberately-long-file-name-for-path-truncation-{n}.key",
              mtime_days_ago=30 + n)
    # One very heavy leaf, so the treemap has something dominant to draw.
    for n in range(7):
        clone(pool["xl"], home / "Movies" / f"screen-recording-{n:02d}.mov",
              mtime_days_ago=12 + n * 3)
    # And one branch that is many tiny files rather than a few big ones — the
    # case where a treemap and a size list disagree about what matters.
    for n in range(400):
        clone(pool["xs"], home / f"Library/Application Support/Notes/attachments/n{n:04d}.dat",
              mtime_days_ago=n % 90)

    # ---- Duplicates: groups of 2, 3 and 10+, spread across folders -----
    folders = ["Pictures/Photos Library/originals", "Pictures/Screenshots",
               "Desktop/to-sort", "Documents/Archive/2024",
               "Downloads/from-phone", "Documents/Work/assets"]
    group_shapes = [2] * 14 + [3] * 8 + [4] * 4 + [11, 13]
    # Each group needs its OWN content, not just its own size.
    #
    # First attempt cloned straight from the shared pool, so every file of a
    # given size was byte-identical to every other — and DuplicateEngine,
    # correctly, reported three enormous groups instead of twenty-eight. The
    # fixture was testing the engine's honesty rather than the layout. Each
    # group now gets a distinct base (pool clone + a per-group tail), and the
    # group's copies are clones of that base.
    bases = home.parent / (home.name + "-pool") / "dup-bases"
    bases.mkdir(parents=True, exist_ok=True)
    for gi, count in enumerate(group_shapes):
        size = ["s", "m", "l"][gi % 3]
        base = bases / f"g{gi:02d}"
        if not base.exists():
            subprocess.run(["cp", "-c", str(pool[size]), str(base)], check=True)
            with open(base, "ab") as handle:
                handle.write(b"group-%04d" % gi + os.urandom(64))
        # Names are sometimes identical across folders and sometimes
        # near-identical, because both happen and the group has to be obvious
        # either way.
        for c in range(count):
            folder = folders[(gi + c) % len(folders)]
            name = f"IMG_{4000 + gi:04d}.heic" if c % 3 else f"IMG_{4000 + gi:04d} copy {c}.heic"
            clone(base, home / folder / name, mtime_days_ago=gi * 2 + c)

    return home


def main():
    if len(sys.argv) < 2:
        print("usage: seed-home.py <home-dir>", file=sys.stderr)
        return 2
    home = Path(sys.argv[1]).resolve()
    # Refuse anything that is not clearly a throwaway location. This script
    # deletes its target first.
    allowed = (str(home).startswith("/private/var/folders/")
               or str(home).startswith("/var/folders/")
               or str(home).startswith("/tmp/")
               or str(home).startswith("/private/tmp/"))
    if not allowed:
        print(f"refusing to seed outside a temporary root: {home}", file=sys.stderr)
        return 2
    seed(home)
    real = subprocess.run(["du", "-sh", str(home.parent / (home.name + "-pool"))],
                          capture_output=True, text=True).stdout.split()[0]
    files = sum(len(f) for _, _, f in os.walk(home))
    print(f"seeded {home} — {files} files, {real} of real blocks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
