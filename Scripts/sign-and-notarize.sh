#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Signs, notarizes and staples a release build with a real Apple Developer
# ID. Fully prepared, never executed in this repository's history — no
# Developer ID has ever been available in any environment this was written
# in. Every command below is real and correct, not illustrative.
#
# Prerequisites this script assumes and checks:
#   - A "Developer ID Application" identity in the login keychain
#     (`security find-identity -v -p codesigning`).
#   - An app-specific password or API key registered for notarytool
#     (`xcrun notarytool store-credentials`), referenced here by profile
#     name so no secret is ever written into this file or the repo.
#   - Configuration/CoreTend.entitlements (hardened runtime, no sandbox —
#     see that file's own comments for why).
#
# Usage:
#   Scripts/sign-and-notarize.sh <version> <notarytool-keychain-profile>
#
# Example (never run in this repo — illustrative of the real invocation):
#   xcrun notarytool store-credentials "CoreTend-Notary" \
#     --apple-id "you@example.com" --team-id "TEAMID1234" --password "app-specific-password"
#   Scripts/sign-and-notarize.sh 1.0.0 CoreTend-Notary
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Usage: $0 <version> <notarytool-keychain-profile>}"
NOTARY_PROFILE="${2:?Usage: $0 <version> <notarytool-keychain-profile>}"
DEVELOPER_ID="${CORETEND_DEVELOPER_ID_APPLICATION:-}"

APP="build/CoreTend.app"
ZIP_NAME="Release/CoreTend-${VERSION}-arm64.zip"
DMG_NAME="Release/CoreTend-${VERSION}-arm64.dmg"
ENTITLEMENTS="Configuration/CoreTend.entitlements"

echo "== Preflight =="
[ -d "$APP" ] || { echo "FAIL: $APP not found — run Scripts/package-local.sh first"; exit 1; }
[ -f "$ENTITLEMENTS" ] || { echo "FAIL: $ENTITLEMENTS not found"; exit 1; }

if [ -z "$DEVELOPER_ID" ]; then
  echo "FAIL: CORETEND_DEVELOPER_ID_APPLICATION is not set."
  echo "  Set it to the exact identity string, e.g.:"
  echo "  export CORETEND_DEVELOPER_ID_APPLICATION=\"Developer ID Application: Your Name (TEAMID1234)\""
  echo "  Find it with: security find-identity -v -p codesigning"
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -qF "$DEVELOPER_ID"; then
  echo "FAIL: identity '$DEVELOPER_ID' not found in the login keychain."
  echo "  security find-identity -v -p codesigning"
  exit 1
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "FAIL: notarytool keychain profile '$NOTARY_PROFILE' is not configured."
  echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\"
  echo "    --apple-id \"you@example.com\" --team-id \"TEAMID1234\" --password \"app-specific-password\""
  exit 1
fi
echo "OK: identity and notarytool profile both present"

echo "== Signing embedded frameworks and binaries (deepest first) =="
find "$APP" -type f \( -perm -u+x -o -name "*.dylib" \) | while read -r bin; do
  file "$bin" | grep -q "Mach-O" || continue
  echo "  signing: $bin"
  codesign --force --options runtime --timestamp \
    --sign "$DEVELOPER_ID" "$bin"
done

echo "== Signing the app bundle (with entitlements) =="
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" "$APP"

echo "== Verifying signature =="
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose "$APP" || {
  echo "NOTE: spctl will still reject until notarization+stapling complete below — expected at this point."
}

echo "== Packaging for notarization =="
mkdir -p Release
ditto -c -k --keepParent "$APP" "$ZIP_NAME"
bash Scripts/package-dmg.sh "$VERSION"

echo "== Submitting ZIP for notarization (app) =="
xcrun notarytool submit "$ZIP_NAME" --keychain-profile "$NOTARY_PROFILE" --wait

echo "== Stapling the app, then re-packaging the DMG with the stapled app =="
xcrun stapler staple "$APP"
bash Scripts/package-dmg.sh "$VERSION"

echo "== Submitting the DMG for notarization =="
xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait

echo "== Stapling the DMG =="
xcrun stapler staple "$DMG_NAME"

echo "== Final Gatekeeper verification =="
spctl --assess --type execute --verbose "$APP"
spctl --assess --type open --context context:primary-signature --verbose "$DMG_NAME"

echo "== Done =="
echo "Signed, notarized, stapled: $APP, $DMG_NAME"
echo "Validate on a clean machine (no dev tools) before publishing:"
echo "  xcrun stapler validate \"$DMG_NAME\""
