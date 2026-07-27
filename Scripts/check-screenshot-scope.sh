#!/bin/sh
# Fails packaging if any tracked screenshot exceeds the approved app-window
# frame, matches a known full-screen desktop resolution, or is not listed
# in Documentation/VisualAudit/SCREENSHOT_MANIFEST.json. Prevents a repeat of
# the 2026-07-20 incident where a full-desktop capture (2880x1800, containing
# other apps and private window content) was committed as a "menu bar" shot.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

MANIFEST="Documentation/VisualAudit/SCREENSHOT_MANIFEST.json"
SCREENSHOT_DIR="Documentation/VisualAudit/After"

if ! command -v python3 >/dev/null 2>&1; then
  echo "check-screenshot-scope.sh: python3 not found, cannot validate manifest" >&2
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: $MANIFEST is missing." >&2
  exit 1
fi

fail=0

for f in "$SCREENSHOT_DIR"/*.png; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  w=$(sips -g pixelWidth "$f" | tail -1 | awk '{print $2}')
  h=$(sips -g pixelHeight "$f" | tail -1 | awk '{print $2}')

  result=$(MANIFEST="$MANIFEST" BASE="$base" W="$w" H="$h" python3 <<'PYEOF'
import json, os, sys

manifest = json.load(open(os.environ["MANIFEST"]))
base = os.environ["BASE"]
w = int(os.environ["W"])
h = int(os.environ["H"])

entry = next((e for e in manifest["entries"] if e["file"] == base), None)
if entry is None:
    print(f"FAIL: {base} ({w}x{h}) is not listed in SCREENSHOT_MANIFEST.json — not explicitly approved.")
    sys.exit(1)

if entry["width"] != w or entry["height"] != h:
    print(f"FAIL: {base} is {w}x{h}, manifest expects {entry['width']}x{entry['height']} — frame changed since approval.")
    sys.exit(1)

max_w = manifest.get("maxWidth", 2000)
max_h = manifest.get("maxHeight", 1500)
if w > max_w or h > max_h:
    print(f"FAIL: {base} ({w}x{h}) exceeds the approved app-window ceiling ({max_w}x{max_h}).")
    sys.exit(1)

for (dw, dh) in manifest.get("disallowedFullScreenResolutions", []):
    if (w, h) == (dw, dh) or (h, w) == (dw, dh):
        print(f"FAIL: {base} ({w}x{h}) matches a known full-screen desktop resolution — looks like a desktop capture, not a window capture.")
        sys.exit(1)

print(f"OK: {base} ({w}x{h}) matches its approved manifest entry.")
sys.exit(0)
PYEOF
) || fail=1
  echo "$result"
done

if [ "$fail" -ne 0 ]; then
  echo "check-screenshot-scope.sh: FAILED"
  exit 1
fi
echo "check-screenshot-scope.sh: PASSED"
