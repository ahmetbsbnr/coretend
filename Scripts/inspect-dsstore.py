#!/usr/bin/env python3
"""Read a .DS_Store and assert the window layout it records.

The layout is the only thing that makes a DMG look like an installer rather
than a folder, and it is invisible until a user mounts the image — so it has
to be asserted from the bytes, not eyeballed. Uses the same ds_store library
the build writes with, so this runs headless and in CI.

Exit status is 0 when every requested expectation holds, 1 otherwise, with the
mismatches printed. Called by Scripts/test-dmg-layout.sh.
"""

import argparse
import sys

from ds_store import DSStore


def parse_icon(spec):
    name, _, coords = spec.partition("=")
    x, _, y = coords.partition(",")
    return name, (int(x), int(y))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("dsstore")
    p.add_argument("--expect-icon", action="append", default=[],
                   metavar="NAME=X,Y", help="required icon centre, Finder coordinates")
    p.add_argument("--expect-icon-size", type=int)
    p.add_argument("--expect-window", metavar="WxH", help="content size in points")
    p.add_argument("--expect-view", help="four-character view style, e.g. icnv")
    p.add_argument("--expect-background-picture", action="store_true")
    args = p.parse_args()

    records = {}
    with DSStore.open(args.dsstore, "r") as store:
        for entry in store:
            records[(entry.filename, entry.code)] = entry.value

    def get(name, code):
        # ds_store yields codes as bytes; normalise so lookups are predictable.
        for (fn, c), value in records.items():
            code_str = c.decode() if isinstance(c, bytes) else str(c)
            if fn == name and code_str == code:
                return value
        return None

    problems = []

    for spec in args.expect_icon:
        name, want = parse_icon(spec)
        got = get(name, "Iloc")
        if got is None:
            problems.append(f"{name}: no Iloc record — the icon has no saved position")
        elif tuple(got)[:2] != want:
            problems.append(f"{name}: icon at {tuple(got)[:2]}, expected {want}")

    icvp = get(".", "icvp") or {}
    bwsp = get(".", "bwsp") or {}

    if args.expect_icon_size is not None:
        got = icvp.get("iconSize")
        if got is None:
            problems.append("icvp has no iconSize")
        elif int(got) != args.expect_icon_size:
            problems.append(f"icon size is {int(got)}, expected {args.expect_icon_size}")

    if args.expect_view:
        # The view style lives in icvl (a blob) and, for the window, in bwsp.
        got = bwsp.get("WindowState", {}).get("ViewStyle") if isinstance(bwsp.get("WindowState"), dict) else None
        icvl = get(".", "icvl")
        blob = icvl.decode("ascii", "replace") if isinstance(icvl, bytes) else ""
        if args.expect_view not in (got or "") and args.expect_view not in blob:
            problems.append(f"view style is {got or blob!r}, expected {args.expect_view}")

    if args.expect_window:
        want_w, _, want_h = args.expect_window.partition("x")
        bounds = bwsp.get("WindowBounds")
        if not bounds:
            problems.append("bwsp has no WindowBounds — the window has no saved size")
        else:
            # "{{x, y}, {w, h}}"
            nums = [int(float(n)) for n in
                    bounds.replace("{", " ").replace("}", " ").replace(",", " ").split()]
            if len(nums) < 4:
                problems.append(f"unparseable WindowBounds: {bounds!r}")
            else:
                w, h = nums[2], nums[3]
                if (w, h) != (int(want_w), int(want_h)):
                    problems.append(f"window is {w}x{h}, expected {want_w}x{want_h}")

    if args.expect_background_picture:
        # backgroundType 2 means "picture"; the alias must actually be there.
        if int(icvp.get("backgroundType", 0)) != 2:
            problems.append(f"backgroundType is {icvp.get('backgroundType')}, expected 2 (picture)")
        if not (icvp.get("backgroundImageAlias") or icvp.get("backgroundImageBookmark")):
            problems.append("no background image alias recorded — the picture would not be shown")

    for key, expected in (("showIconPreview", False), ("labelOnBottom", True)):
        if key in icvp and bool(icvp[key]) != expected:
            problems.append(f"{key} is {icvp[key]}, expected {expected}")

    if problems:
        print("inspect-dsstore: layout does not match the intended design:")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print(f"inspect-dsstore: layout OK "
          f"(icons {[parse_icon(s)[1] for s in args.expect_icon]}, "
          f"size {args.expect_icon_size}, window {args.expect_window})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
