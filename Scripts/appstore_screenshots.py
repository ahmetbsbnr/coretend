#!/usr/bin/env python3
"""Pick the App Store screenshots (2880 × 1800) from an in-use capture run, in listing order.

    python3 Scripts/capture_screens.py --in-use --output Artifacts/Captures/<date>-in-use
    python3 Scripts/appstore_screenshots.py Artifacts/Captures/<date>-in-use

Writes Artifacts/AppStore/screenshots/<language>/NN-<surface>.png and refuses any image that is
not exactly 2880 × 1800, the Mac App Store's 16:10 size.
"""
import shutil
import subprocess
import sys
from pathlib import Path

ORDER = ["overview", "explore", "duplicates", "cleanup", "applications", "integrity", "performance", "onboarding"]


def size(image: Path) -> tuple[int, int]:
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(image)], capture_output=True, text=True, check=True).stdout
    values = [int(line.split()[-1]) for line in out.splitlines() if "pixel" in line]
    return values[0], values[1]


def main() -> int:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = Path(sys.argv[1])
    target = Path(__file__).resolve().parents[1] / "Artifacts/AppStore/screenshots"
    problems = []
    for language in ("en", "fr"):
        out = target / language
        shutil.rmtree(out, ignore_errors=True)
        out.mkdir(parents=True)
        for index, surface in enumerate(ORDER, start=1):
            image = source / f"{surface}-{language}-dark.png"
            if not image.is_file():
                problems.append(f"missing {image.name}")
                continue
            if size(image) != (2880, 1800):
                problems.append(f"{image.name} is {size(image)}, not 2880 × 1800")
                continue
            shutil.copyfile(image, out / f"{index:02d}-{surface}.png")
    if problems:
        print("\n".join(problems))
        return 1
    print(f"{len(ORDER)} screenshots per language in {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
