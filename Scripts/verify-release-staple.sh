#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Verifies that the *published* signed artifacts are the ones a user can
# actually open — not merely that they were signed at some point.
#
# Why this exists (regression guard, v1.0.0 / v1.2.0-beta.1):
#   sign-and-notarize.sh built the ZIP from the app *before* stapling, because
#   that same ZIP is the notarization submission payload. The staple was then
#   applied to build/CoreTend.app and the ZIP was never regenerated, so the
#   published ZIP shipped an app with no stapled ticket. Such an app still
#   opens on a Mac that can reach Apple's notarization service, which is why
#   it passed every online check — but on an offline Mac, or behind a proxy
#   that blocks the Gatekeeper ticket lookup, macOS reports
#   "CoreTend.app is damaged and can't be opened". The DMG was stapled and was
#   therefore fine, which is what made the failure look intermittent.
#
# The gate is deliberately staple-centric: stapling is the only property that
# makes an artifact openable with no network. codesign/spctl are checked too,
# but a passing spctl on a connected machine proves nothing about staples.
#
# Usage: Scripts/verify-release-staple.sh <version>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Usage: $0 <version>}"
ZIP="Release/CoreTend-${VERSION}-arm64.zip"
DMG="Release/CoreTend-${VERSION}-arm64.dmg"

fail() { echo "verify-release-staple.sh: FAIL — $1"; exit 1; }

for f in "$ZIP" "$DMG"; do
  [ -f "$f" ] || fail "$f not found. Run Scripts/sign-and-notarize.sh $VERSION <profile> first."
done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "== DMG: signature =="
codesign --verify --strict --verbose=2 "$DMG" || fail "$DMG has an invalid signature."

echo "== DMG: notarization ticket stapled =="
xcrun stapler validate "$DMG" >/dev/null 2>&1 \
  || fail "$DMG has no stapled ticket. Re-run sign-and-notarize.sh."

echo "== ZIP: extracting the app that users actually receive =="
ditto -x -k "$ZIP" "$WORK/zip" || fail "$ZIP could not be expanded."
APP="$WORK/zip/CoreTend.app"
[ -d "$APP" ] || fail "$ZIP does not contain CoreTend.app at its root."

echo "== ZIP app: signature =="
codesign --verify --deep --strict --verbose=2 "$APP" \
  || fail "the app inside $ZIP has an invalid signature."

echo "== ZIP app: notarization ticket stapled =="
xcrun stapler validate "$APP" >/dev/null 2>&1 || fail \
  "the app inside $ZIP has NO stapled ticket.
  This is the v1.0.0 regression: the published ZIP was built before stapling.
  It opens on a connected Mac but fails with \"CoreTend.app is damaged\"
  offline or behind a proxy that blocks Apple's ticket lookup.
  Fix: regenerate the ZIP from the stapled bundle (sign-and-notarize.sh does
  this after 'Stapling the notarized app')."

echo "== Gatekeeper assessment (informational: requires network) =="
spctl --assess --type exec --verbose "$APP" 2>&1 | sed 's/^/    /' || true
spctl --assess --type open --context context:primary-signature --verbose "$DMG" 2>&1 | sed 's/^/    /' || true

echo "verify-release-staple.sh: OK — ZIP and DMG are signed and stapled."
