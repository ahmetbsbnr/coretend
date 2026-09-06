#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Signs, notarizes and staples a release build with a real Apple Developer
# ID. First run for real on 2026-08-31 (0.9.1-rc.5) — the Developer ID
# Application identity "Ahmet BASBUNAR (NSCUV5G738)" was issued that day.
#
# Prerequisites this script assumes and checks:
#   - A "Developer ID Application" identity in the login keychain
#     (`security find-identity -v -p codesigning`).
#   - An app-specific password or App Store Connect API key registered for
#     notarytool (`xcrun notarytool store-credentials`), referenced here by
#     profile name so no secret is ever written into this file or the repo.
#   - Configuration/CoreTend.entitlements (hardened runtime, no sandbox —
#     see that file's own comments for why).
#
# Usage:
#   Scripts/sign-and-notarize.sh <version> <notarytool-keychain-profile>
#
# Real invocation used for 0.9.1-rc.5:
#   xcrun notarytool store-credentials "CoreTend-Notary" \
#     --key Configuration/DeveloperID/AuthKey_XXXXXXXXXX.p8 \
#     --key-id XXXXXXXXXX --issuer <issuer-uuid>
#   export CORETEND_DEVELOPER_ID_APPLICATION="Developer ID Application: Ahmet BASBUNAR (NSCUV5G738)"
#   Scripts/sign-and-notarize.sh 0.9.1-rc.5 CoreTend-Notary
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Usage: $0 <version> <notarytool-keychain-profile>}"
NOTARY_PROFILE="${2:?Usage: $0 <version> <notarytool-keychain-profile>}"
DEVELOPER_ID="${CORETEND_DEVELOPER_ID_APPLICATION:-}"

APP="build/CoreTend.app"
ZIP_NAME="Release/CoreTend-${VERSION}-arm64.zip"
DMG_NAME="Release/CoreTend-${VERSION}-arm64.dmg"
ENTITLEMENTS="Configuration/CoreTend.entitlements"
WIDGET_ENTITLEMENTS="Configuration/CoreTendWidget.entitlements"
WIDGET_APPEX="$APP/Contents/PlugIns/CoreTendWidget.appex"
FINDER_ENTITLEMENTS="Configuration/CoreTendFinder.entitlements"
FINDER_APPEX="$APP/Contents/PlugIns/CoreTendFinder.appex"

echo "== Preflight =="
# The shipping .app (with the embedded WidgetKit extension and the App
# Intents metadata bundle) is produced by Scripts/build-xcode.sh, which
# copies it to build/CoreTend.app. Scripts/package-local.sh is a fast,
# widget-less SwiftPM build for local dev only and must NOT be the input
# here — it has no Contents/PlugIns.
[ -d "$APP" ] || { echo "FAIL: $APP not found — run Scripts/build-xcode.sh first"; exit 1; }
[ -f "$ENTITLEMENTS" ] || { echo "FAIL: $ENTITLEMENTS not found"; exit 1; }
[ -f "$WIDGET_ENTITLEMENTS" ] || { echo "FAIL: $WIDGET_ENTITLEMENTS not found"; exit 1; }
[ -f "$FINDER_ENTITLEMENTS" ] || { echo "FAIL: $FINDER_ENTITLEMENTS not found"; exit 1; }
[ -d "$WIDGET_APPEX" ] || {
  echo "FAIL: $WIDGET_APPEX not found — this .app was not built by Scripts/build-xcode.sh."
  echo "  (Scripts/package-local.sh cannot embed the widget; SwiftPM does not build .appex bundles.)"
  exit 1
}
[ -d "$FINDER_APPEX" ] || {
  echo "FAIL: $FINDER_APPEX not found — this .app was not built by Scripts/build-xcode.sh."
  echo "  (The Finder Sync extension is an Xcode app-extension target; SwiftPM cannot produce it.)"
  exit 1
}
[ -d "$APP/Contents/Resources/Metadata.appintents" ] || {
  echo "FAIL: $APP/Contents/Resources/Metadata.appintents missing — App Intents metadata was not emitted."
  exit 1
}

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

echo "== Signing loose embedded Mach-O binaries (deepest first) =="
# Skips the three bundle executables (both appex and the host) — those are
# signed as bundles below, in the correct nested order.
find "$APP" -type f \( -perm -u+x -o -name "*.dylib" \) \
  ! -path "*/CoreTendWidget.appex/Contents/MacOS/*" \
  ! -path "*/CoreTendFinder.appex/Contents/MacOS/*" \
  ! -path "$APP/Contents/MacOS/*" | while read -r bin; do
  file "$bin" | grep -q "Mach-O" || continue
  echo "  signing: $bin"
  codesign --force --options runtime --timestamp \
    --sign "$DEVELOPER_ID" "$bin"
done

# Nested signing order: every extension bundle first (each with ITS OWN
# entitlements), then the host .app last. Signing the host seals
# CodeResources over the already-signed appex bundles, so no appex is ever
# re-signed afterwards.
#
#   CoreTendFinder.appex   — App Sandbox only (URL handoff; no App Group)
#   CoreTendWidget.appex   — App Sandbox + the shared App Group
#   CoreTend.app (host)    — hardened runtime + the same App Group, no sandbox
#
# NOTE on App Groups + Developer ID: the shared group
# `group.com.ahmetbsbnr.coretend` (used ONLY by the widget, not the Finder
# extension) must be registered on the Apple Developer account for a
# Developer ID (non-App-Store) distribution to be accepted by notarization
# with that entitlement. This has not been exercised in a real notarization
# run yet — see Documentation/SIGNING_NOTARIZATION.md.
echo "== Signing the Finder Sync extension (App Sandbox only) =="
codesign --force --options runtime --timestamp \
  --entitlements "$FINDER_ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" "$FINDER_APPEX"

echo "== Signing the WidgetKit extension (App Sandbox + App Group) =="
codesign --force --options runtime --timestamp \
  --entitlements "$WIDGET_ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" "$WIDGET_APPEX"

echo "== Signing the host app bundle (hardened runtime + App Group) =="
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" "$APP"

echo "== Verifying signatures (host and both nested extensions) =="
codesign --verify --deep --strict --verbose=2 "$APP"
codesign --verify --strict --verbose=2 "$WIDGET_APPEX"
codesign --verify --strict --verbose=2 "$FINDER_APPEX"
codesign --display --entitlements :- "$WIDGET_APPEX" | grep -q "group.com.ahmetbsbnr.coretend" \
  && echo "  OK: widget carries the shared App Group entitlement" \
  || { echo "  FAIL: widget lost its App Group entitlement"; exit 1; }
codesign --display --entitlements :- "$FINDER_APPEX" | python3 -c '
import plistlib, sys
# Read the pipe fully first: plistlib.load() seeks the stream (Python >= 3.14),
# which fails on a non-seekable stdin pipe. Same assertion, seek-free.
assert plistlib.loads(sys.stdin.buffer.read()) == {"com.apple.security.app-sandbox": True}, "Finder entitlements must be exactly sandbox-only"
print("  OK: Finder extension entitlements exactly sandbox-only")'
spctl --assess --type execute --verbose "$APP" || {
  echo "NOTE: spctl will still reject until notarization+stapling complete below — expected at this point."
}

# Order matters: the notarization ticket is bound to the exact CDHash of the
# bundle that was submitted. Anything that re-signs build/CoreTend.app between
# "submit" and "staple" (e.g. a DMG build that rebuilds the app) invalidates
# the pairing. So: ZIP -> submit -> staple the *same* bundle -> only then build
# the DMG from it, and never rebuild the app inside package-dmg.sh.
echo "== Packaging the signed app for notarization =="
mkdir -p Release
ditto -c -k --keepParent "$APP" "$ZIP_NAME"

echo "== Submitting the app for notarization =="
xcrun notarytool submit "$ZIP_NAME" --keychain-profile "$NOTARY_PROFILE" --wait

echo "== Stapling the notarized app =="
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "== Building the DMG from the signed, stapled app (no rebuild) =="
CORETEND_SKIP_APP_BUILD=1 bash Scripts/package-dmg.sh "$VERSION"
UNSIGNED_DMG="Release/CoreTend-${VERSION}-arm64-unsigned.dmg"
[ -f "$UNSIGNED_DMG" ] || { echo "FAIL: $UNSIGNED_DMG not produced by package-dmg.sh"; exit 1; }
cp "$UNSIGNED_DMG" "$DMG_NAME"

echo "== Signing the DMG =="
codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG_NAME"

echo "== Submitting the DMG for notarization =="
xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait

echo "== Stapling the DMG =="
xcrun stapler staple "$DMG_NAME"
xcrun stapler validate "$DMG_NAME"

echo "== Final Gatekeeper verification =="
spctl --assess --type execute --verbose "$APP"
spctl --assess --type open --context context:primary-signature --verbose "$DMG_NAME"

echo "== Done =="
echo "Signed, notarized, stapled: $APP, $DMG_NAME"
echo "SHA-256:"
shasum -a 256 "$ZIP_NAME" "$DMG_NAME"
echo "Validate on a clean machine (no dev tools) before publishing:"
echo "  xcrun stapler validate \"$DMG_NAME\""
