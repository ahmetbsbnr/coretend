#!/bin/zsh
# Builds MacCare-Local-<version>-arm64-unsigned.dmg: plain functional DMG
# with the .app, an /Applications shortcut, and license files. No custom
# background art (no guaranteed display available to author one safely).
set -e
cd "$(dirname "$0")/.."

ARTIFACT_VERSION="${1:-0.7.0}"
DMG_NAME="MacCare-Local-${ARTIFACT_VERSION}-arm64-unsigned.dmg"

bash Scripts/package-local.sh

APP="build/MacCare Local.app"
[ -d "$APP" ] || { echo "package-dmg.sh: app bundle not found at $APP"; exit 1; }

mkdir -p Release
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp LICENSE NOTICE THIRD_PARTY_NOTICES.md "$STAGE/"

rm -f "Release/$DMG_NAME"
hdiutil create -volname "MacCare Local" -srcfolder "$STAGE" -ov -format UDZO "Release/$DMG_NAME"
rm -rf "$STAGE"

echo "Built: Release/$DMG_NAME"
