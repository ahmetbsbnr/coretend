#!/bin/zsh
# Verifies that a built DMG actually carries its window layout, and that the
# volume contains exactly what a user should see.
#
# 0.9.1-rc.2 shipped with no .DS_Store: the background and icon positions were
# silently absent, so the volume opened as a default Finder window with loose
# licence files in it. Every assertion below exists because that shipped.
#
# Reads the .DS_Store with the same ds_store library the build writes it with,
# so the check needs no Finder and runs in CI.
set -e -o pipefail
cd "$(dirname "$0")/.."

DMG="${1:?usage: test-dmg-layout.sh <dmg> [volume-name]}"
VOLNAME="${2:-}"

[ -f "$DMG" ] || { echo "test-dmg-layout: no such DMG: $DMG"; exit 1; }

fail() { echo "test-dmg-layout: FAIL — $1"; exit 1; }
pass() { echo "  ok: $1"; }

echo "test-dmg-layout: $DMG"

# The release scripts must not have regressed to driving the Finder.
# Comments are allowed to mention osascript — the history of why it is gone is
# worth keeping. Only actual code counts, so strip comment lines first.
for script in Scripts/package-dmg.sh Scripts/package-local.sh Scripts/build-release.sh; do
  [ -f "$script" ] || continue
  if sed 's/#.*//' "$script" | grep -qE "osascript|tell application \"Finder\""; then
    fail "$script still calls osascript/Finder; packaging must be non-interactive"
  fi
done
pass "no Finder or AppleScript dependency in the packaging scripts"

hdiutil verify "$DMG" >/dev/null 2>&1 || fail "hdiutil verify rejected the image"
pass "hdiutil verify"

MOUNT=$(mktemp -d)
hdiutil attach "$DMG" -mountpoint "$MOUNT" -nobrowse -noverify -readonly >/dev/null
cleanup() { hdiutil detach "$MOUNT" >/dev/null 2>&1 || hdiutil detach "$MOUNT" -force >/dev/null 2>&1; rmdir "$MOUNT" 2>/dev/null || true; }
trap cleanup EXIT

[ -d "$MOUNT/CoreTend.app" ] || fail "CoreTend.app missing from the volume"
pass "CoreTend.app present"

[ -L "$MOUNT/Applications" ] || fail "/Applications symlink missing from the volume"
[ "$(readlink "$MOUNT/Applications")" = "/Applications" ] || fail "Applications link does not point at /Applications"
pass "Applications symlink"

# dmgbuild stores the picture as a hidden file at the volume root rather than
# in a .background folder. Either is invisible to the user; what matters is
# that it exists and is the right size.
BG_ON_VOLUME=""
for candidate in "$MOUNT/.background.tiff" "$MOUNT/.background.png" "$MOUNT/.background/background.png"; do
  [ -f "$candidate" ] && { BG_ON_VOLUME="$candidate"; break; }
done
[ -n "$BG_ON_VOLUME" ] || fail "no background image on the volume"
pass "background image embedded ($(basename "$BG_ON_VOLUME"))"

DIMS=$(sips -g pixelWidth -g pixelHeight "$BG_ON_VOLUME" | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')
[ "$DIMS" = "600x400" ] || fail "background base representation is $DIMS, expected 600x400"
pass "background base representation is 600x400"

# The Retina representation has to be in the same TIFF, or the window is soft
# on every Retina display — which is every Mac this build supports.
TIFF_INFO=$(tiffutil -info "$BG_ON_VOLUME" 2>/dev/null || true)
REPS=$(printf '%s\n' "$TIFF_INFO" | grep -c "^Directory at" || true)
[ "${REPS:-0}" -ge 2 ] || fail "background has ${REPS:-0} representation(s); expected a 600x400 + 1200x800 HiDPI TIFF"
printf '%s\n' "$TIFF_INFO" | grep -q "Image Width: 1200 Image Length: 800" \
  || fail "background has no 1200x800 representation; Retina displays would render it soft"
pass "background carries both 600x400 and 1200x800 representations"

[ -f "$MOUNT/.DS_Store" ] || fail ".DS_Store missing — the window layout would not appear for the user"
pass ".DS_Store present"

# Only CoreTend.app and Applications may be visible. Dotfiles are fine: they
# are the layout and the background, which the user never sees.
VISIBLE=$(ls "$MOUNT" | sort | tr '\n' ' ')
[ "$VISIBLE" = "Applications CoreTend.app " ] || fail "unexpected visible files on the volume: $VISIBLE"
pass "only CoreTend.app and Applications are visible"

for stray in README README.md LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
  [ -e "$MOUNT/$stray" ] && fail "$stray must not sit on the volume root"
done
pass "no licence or readme clutter on the volume root"

# Licences still have to ship — sealed inside the bundle, before signing.
for lic in LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
  [ -f "$MOUNT/CoreTend.app/Contents/Resources/$lic" ] || fail "$lic missing from the app bundle"
done
pass "licence texts sealed inside the bundle"

codesign --verify --deep --strict "$MOUNT/CoreTend.app" 2>/dev/null \
  || fail "the bundle signature is broken (something was added after codesign)"
pass "bundle signature intact"

# Now the layout itself, read straight out of the .DS_Store.
VENV="${CORETEND_PACKAGING_VENV:-.build/packaging-venv}"
if [ ! -x "$VENV/bin/python" ]; then
  mkdir -p "$(dirname "$VENV")"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q --disable-pip-version-check -r Scripts/requirements-packaging.txt
fi

"$VENV/bin/python" Scripts/inspect-dsstore.py "$MOUNT/.DS_Store" \
  --expect-icon "CoreTend.app=170,215" \
  --expect-icon "Applications=430,215" \
  --expect-icon-size 104 \
  --expect-window 600x400 \
  --expect-view icnv \
  --expect-background-picture \
  || fail "the recorded window layout does not match the intended design"
pass "window bounds, view style, icon size and icon coordinates"

echo "test-dmg-layout: PASS"
