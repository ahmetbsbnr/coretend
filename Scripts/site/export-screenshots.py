#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
"""
Mechanical screenshot exporter for the CoreTend website.

Reads Website/screenshots.json. For every entry with a `source` set, produces
the two web variants named in `web1x` / `web2x`:

  web2x  ->  1600 px wide WebP
  web1x  ->   800 px wide WebP

Rules:
  - deterministic (fixed cwebp quality)
  - never upscale — if the source is narrower than the target, keep source width
  - preserve aspect ratio (cwebp `-resize W 0`)
  - strip all metadata (`-metadata none`)
  - fail clearly on a missing / unreadable source
  - stable output paths (exactly the manifest's `web1x` / `web2x`)

It does NOT capture anything and it does NOT set `approved`. Capture and
approval remain HUMAN ASSET REVIEW REQUIRED.

Usage:
  Scripts/site/export-screenshots.py [--only <id-substring>] [--dry-run]
"""
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SITE = os.path.join(ROOT, "Website")
MANIFEST = os.path.join(SITE, "screenshots.json")
Q2X, Q1X = "78", "74"          # keep in sync with Website/SCREENSHOT_GUIDE.md


def src_width(path):
    # Width probe via sips (always present on macOS) or PIL; no ImageMagick dep.
    try:
        w = subprocess.check_output(
            ["sips", "-g", "pixelWidth", path], text=True, stderr=subprocess.DEVNULL)
        for ln in w.splitlines():
            if "pixelWidth:" in ln:
                return int(ln.split(":")[1].strip())
    except Exception:
        pass
    try:
        from PIL import Image
        with Image.open(path) as im:
            return im.width
    except Exception:
        return None


def export_one(src_abs, out_abs, target_w, quality, dry):
    w = src_width(src_abs)
    resize_w = target_w if (w is None or w >= target_w) else w
    out_dir = os.path.dirname(out_abs)
    if not dry:
        os.makedirs(out_dir, exist_ok=True)
    cmd = ["cwebp", "-quiet", "-q", quality, "-metadata", "none",
           "-resize", str(resize_w), "0", src_abs, "-o", out_abs]
    print(f"  {'DRY ' if dry else ''}{os.path.relpath(out_abs, SITE)}  "
          f"<- {os.path.relpath(src_abs, ROOT)}  (w={resize_w}"
          f"{' , source ' + str(w) + 'px — no upscale' if w and w < target_w else ''})")
    if not dry:
        subprocess.check_call(cmd)


def main(argv):
    only = None
    dry = "--dry-run" in argv
    if "--only" in argv:
        only = argv[argv.index("--only") + 1]

    if not shutil.which("cwebp"):
        print("export-screenshots.py: FAIL — cwebp not installed (brew install webp)")
        return 1
    if not os.path.exists(MANIFEST):
        print(f"export-screenshots.py: FAIL — {MANIFEST} missing")
        return 1

    doc = json.load(open(MANIFEST, encoding="utf-8"))
    done = skipped = 0
    problems = []
    for e in doc.get("screenshots", []):
        sid = e.get("id", "<no id>")
        if only and only not in sid:
            continue
        src = e.get("source")
        if not src:
            skipped += 1
            continue
        src_abs = os.path.join(ROOT, src)
        if not os.path.exists(src_abs):
            problems.append(f"{sid}: source {src!r} does not exist")
            continue
        w2, w1 = e.get("web2x"), e.get("web1x")
        if not w2 or not w1:
            problems.append(f"{sid}: has a source but web1x/web2x is not defined")
            continue
        print(sid)
        try:
            export_one(src_abs, os.path.join(SITE, w2), 1600, Q2X, dry)
            export_one(src_abs, os.path.join(SITE, w1), 800, Q1X, dry)
            done += 1
        except subprocess.CalledProcessError as exc:
            problems.append(f"{sid}: cwebp failed ({exc})")

    if problems:
        print("export-screenshots.py: FAIL")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"export-screenshots.py: OK — {done} exported, {skipped} pending "
          f"(source:null, HUMAN ASSET REVIEW REQUIRED){' [dry-run]' if dry else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
