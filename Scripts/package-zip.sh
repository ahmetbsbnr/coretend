#!/bin/zsh
# Builds MacCare-Local-<version>-arm64-unsigned.zip from the app bundle
# produced by package-local.sh. Reuses that script rather than
# duplicating the bundle-assembly steps.
set -e
cd "$(dirname "$0")/.."

ARTIFACT_VERSION="${1:-0.7.0}"
ZIP_NAME="MacCare-Local-${ARTIFACT_VERSION}-arm64-unsigned.zip"

bash Scripts/package-local.sh

APP="build/MacCare Local.app"
[ -d "$APP" ] || { echo "package-zip.sh: app bundle not found at $APP"; exit 1; }

mkdir -p Release
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
cp LICENSE NOTICE THIRD_PARTY_NOTICES.md "$STAGE/"

rm -f "Release/$ZIP_NAME"
REPO_ROOT="$(pwd)"
(cd "$STAGE" && zip -qry "$REPO_ROOT/Release/$ZIP_NAME" "MacCare Local.app" LICENSE NOTICE THIRD_PARTY_NOTICES.md)
rm -rf "$STAGE"

echo "Built: Release/$ZIP_NAME"
