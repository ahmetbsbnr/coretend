#!/bin/zsh
# Builds CoreTend-<version>-arm64-unsigned.dmg: the .app, an /Applications
# shortcut, the licence files, a Living System background, and a volume icon.
#
# What is and is not automated here, and why:
#
#   Background image and volume icon are written directly into the staged
#   volume — no GUI involved, so they are reliable in any environment.
#
#   Icon *positions* and window geometry live in a .DS_Store, which only the
#   Finder writes. Driving the Finder needs a session with automation
#   permission granted, which a build script cannot assume. So the layout pass
#   is attempted, bounded by a timeout, and its failure is reported rather than
#   silently producing a DMG that looks finished. The DMG is fully functional
#   either way: drag-and-drop works with or without a saved window layout.
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

mkdir -p Release
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp LICENSE NOTICE THIRD_PARTY_NOTICES.md "$STAGE/"

# Background: a hidden folder, so it never shows up as a file to drag.
if [ -f "$BG_SRC" ]; then
  mkdir -p "$STAGE/.background"
  cp "$BG_SRC" "$STAGE/.background/background.png"
  [ -f "$BG_SRC_2X" ] && cp "$BG_SRC_2X" "$STAGE/.background/background@2x.png"
else
  echo "package-dmg.sh: WARNING — $BG_SRC missing; run the brand asset generator"
fi

# Volume icon. Needs the custom-icon bit set on the volume root, which
# SetFile provides when the developer tools are present.
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$STAGE/.VolumeIcon.icns"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$STAGE" || echo "package-dmg.sh: WARNING — could not set the custom-icon bit"
  else
    echo "package-dmg.sh: note — SetFile unavailable, volume icon may not display"
  fi
fi

RW_DMG=$(mktemp -u)/rw.dmg
mkdir -p "$(dirname "$RW_DMG")"
rm -f "Release/$DMG_NAME"

# Read-write image first, so the layout pass has something to write into.
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -ov \
  -fs HFS+ -format UDRW "$RW_DMG" >/dev/null

MOUNT_DIR=$(mktemp -d)
hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -noverify >/dev/null

layout_applied="no"
if [ -f "$MOUNT_DIR/.background/background.png" ]; then
  # Bounded: if the Finder is unavailable or unapproved, this must not hang a
  # build. 25 s is far longer than the Finder needs when it does work.
  set +e
  osascript -e "
    tell application \"Finder\"
      tell disk \"$VOLNAME\"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 140, 800, 540}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 96
        set background picture of opts to file \".background:background.png\"
        set position of item \"CoreTend.app\" of container window to {150, 200}
        set position of item \"Applications\" of container window to {450, 200}
        close
        open
        update without registering applications
        delay 1
        close
      end tell
    end tell
  " >/dev/null 2>&1 &
  osa_pid=$!
  waited=0
  while kill -0 "$osa_pid" 2>/dev/null && [ "$waited" -lt 25 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  if kill -0 "$osa_pid" 2>/dev/null; then
    kill -9 "$osa_pid" 2>/dev/null || true
    echo "package-dmg.sh: BLOCKED_ENVIRONMENT — the Finder layout pass timed out."
    echo "  The DMG is functional (background and icon are embedded); only the"
    echo "  saved icon positions are missing. See Documentation/VISUAL_QA.md."
  else
    wait "$osa_pid" 2>/dev/null
    if [ $? -eq 0 ]; then
      layout_applied="yes"
    else
      echo "package-dmg.sh: BLOCKED_ENVIRONMENT — the Finder refused the layout pass"
      echo "  (most likely automation permission). The DMG is still functional."
    fi
  fi
  set -e
fi

sync
hdiutil detach "$MOUNT_DIR" >/dev/null || hdiutil detach "$MOUNT_DIR" -force >/dev/null
rmdir "$MOUNT_DIR" 2>/dev/null || true

# Compress to the shippable read-only image.
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "Release/$DMG_NAME" >/dev/null
rm -rf "$(dirname "$RW_DMG")" "$STAGE"

echo "Built: Release/$DMG_NAME (window layout applied: $layout_applied)"
