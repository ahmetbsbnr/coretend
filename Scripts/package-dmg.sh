#!/bin/zsh
# Builds CoreTend-<version>-arm64-unsigned.dmg: the .app, an /Applications
# shortcut, the Living System background, and a volume icon.
#
# The window layout — icon view, window bounds, background picture, icon
# coordinates — lives in a .DS_Store. This used to be written by driving the
# Finder over AppleScript, which meant the build depended on a graphical
# session and an Automation/TCC grant. When that grant was missing the layout
# pass failed and the DMG shipped unstyled; 0.9.1-rc.2 went out that way.
#
# It is now written directly by dmgbuild (ds_store + mac_alias). No Finder, no
# osascript, no TCC, no GUI. The build is reproducible in a non-interactive
# shell and in CI, and Scripts/test-dmg-layout.sh verifies the result.
#
# No privileged helper, no install script, no user data — a DMG is a folder.
set -e
cd "$(dirname "$0")/.."

ARTIFACT_VERSION="${1:-0.8.1}"
DMG_NAME="CoreTend-${ARTIFACT_VERSION}-arm64-unsigned.dmg"
VOLNAME="CoreTend ${ARTIFACT_VERSION}"

bash Scripts/package-local.sh

APP="build/CoreTend.app"
[ -d "$APP" ] || { echo "package-dmg.sh: app bundle not found at $APP"; exit 1; }

BG_SRC="Resources/Brand/Generated/DMG-Background.png"
BG_SRC_2X="Resources/Brand/Generated/DMG-Background@2x.png"
ICON_SRC="Resources/Brand/Generated/AppIcon.icns"

for asset in "$BG_SRC" "$BG_SRC_2X"; do
  if [ ! -f "$asset" ]; then
    echo "package-dmg.sh: FAILED — $asset missing."
    echo "  Run: swift Resources/Brand/Sources/generate-brand-assets.swift"
    exit 1
  fi
done

# One TIFF carrying both the 600x400 and the 1200x800 representation, so the
# window looks right on Retina and non-Retina without Finder picking a file.
# tiffutil ships with macOS; this needs no session and no permission.
BG_TIFF="$(mktemp -d)/dmg-background.tiff"
tiffutil -cathidpicheck "$BG_SRC" "$BG_SRC_2X" -out "$BG_TIFF" >/dev/null

# dmgbuild and its two libraries are pure Python. A private venv keeps the
# build off whatever happens to be in the ambient site-packages, so a clean
# clone and a developer machine produce the same image.
VENV="${CORETEND_PACKAGING_VENV:-.build/packaging-venv}"
if [ ! -x "$VENV/bin/dmgbuild" ]; then
  echo "package-dmg.sh: provisioning packaging venv at $VENV"
  mkdir -p "$(dirname "$VENV")"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q --disable-pip-version-check \
    -r Scripts/requirements-packaging.txt
fi

mkdir -p Release
rm -f "Release/$DMG_NAME"

# dmgbuild reads these through the settings file. Passing them in the
# environment keeps the settings file free of repository-relative paths, so it
# also works when the build runs from somewhere else.
export CORETEND_APP="$PWD/$APP"
export CORETEND_DMG_BACKGROUND="$BG_TIFF"
[ -f "$ICON_SRC" ] && export CORETEND_VOLUME_ICON="$PWD/$ICON_SRC"

# --no-hidpi: the TIFF already carries both representations, so dmgbuild must
# pass it through rather than rebuild it from a single resolution.
"$VENV/bin/dmgbuild" --no-hidpi -s Scripts/dmg-settings.py "$VOLNAME" "Release/$DMG_NAME"
rm -rf "$(dirname "$BG_TIFF")"

# The layout is the point of this script, so its absence is a build failure,
# never a warning. ALLOW_UNSTYLED_DMG exists for local diagnosis only and is
# refused for any release build (see Scripts/build-release.sh).
zsh Scripts/test-dmg-layout.sh "Release/$DMG_NAME" "$VOLNAME"

echo "Built: Release/$DMG_NAME"
