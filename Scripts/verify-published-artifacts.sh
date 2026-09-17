#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Verifies the bytes a user will actually download — fetched back from the
# GitHub release, not read from the build workspace.
#
# Why the distinction matters: every check CoreTend ran before v1.0.1 examined
# artifacts sitting in dist/ on the builder. That proves what was built. It does
# not prove what was uploaded: a truncated upload, a mismatched asset, a
# re-signed copy or an asset attached to the wrong release all survive a
# workspace-only check. This downloads and re-verifies instead, and is meant to
# run while the release is still a DRAFT, so a failure means nothing was ever
# public.
#
# Usage:
#   Scripts/verify-published-artifacts.sh <version> [--repo owner/name]
#
# Requires: gh (authenticated), minisign, and macOS for the Gatekeeper checks.
set -uo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: Scripts/verify-published-artifacts.sh <version> [--repo owner/name]}"
VERSION="${VERSION#v}"
REPO="${CORETEND_REPO:-ahmetbsbnr/coretend}"
[ "${2:-}" = "--repo" ] && REPO="${3:?--repo needs a value}"
TAG="v$VERSION"

fail=0
ok()   { printf '  OK   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
note() { printf '       %s\n' "$1"; }
head_() { printf '\n== %s ==\n' "$1"; }

WORK=$(mktemp -d)
MOUNT=""
cleanup() {
  [ -n "$MOUNT" ] && hdiutil detach "$MOUNT" -quiet 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

EXPECTED_TEAM="NSCUV5G738"
EXPECTED_BUNDLE_ID="com.ahmetbsbnr.coretend"
EXPECTED_ARCH="arm64"

head_ "Downloading the published assets for $TAG"
if ! gh release download "$TAG" -R "$REPO" --dir "$WORK" --clobber >/dev/null 2>&1; then
  echo "  FAIL could not download release $TAG from $REPO"
  echo "       Expected: a release (draft or published) carrying every declared asset."
  echo "       Fix: check 'gh release view $TAG -R $REPO'."
  exit 1
fi
ok "downloaded $(find "$WORK" -maxdepth 1 -type f | wc -l | tr -d ' ') asset(s)"

ZIP="$WORK/CoreTend-${VERSION}-arm64.zip"
DMG="$WORK/CoreTend-${VERSION}-arm64.dmg"
SUMS="$WORK/SHA256SUMS"

head_ "Every declared asset is present"
for f in "$ZIP" "$DMG" "$SUMS" "$WORK/latest.json" "$WORK/minisign.pub" \
         "$WORK/coretend-${VERSION}-sbom.spdx.json"; do
  if [ -s "$f" ]; then ok "$(basename "$f")"; else
    bad "$(basename "$f") is missing or empty in the published release"
    note "Fix: the release job's file list and this check disagree — reconcile them."
  fi
done

head_ "Checksums match the downloaded bytes"
if [ -s "$SUMS" ]; then
  if (cd "$WORK" && shasum -a 256 -c SHA256SUMS >/dev/null 2>&1); then
    ok "SHA256SUMS verifies against the downloaded files"
  else
    bad "SHA256SUMS does NOT verify against the downloaded files"
    (cd "$WORK" && shasum -a 256 -c SHA256SUMS 2>&1 | grep -v ': OK$' | sed 's/^/       /')
    note "Expected: the published hashes describe the published bytes."
    note "This is what a truncated or replaced upload looks like. Do not publish."
  fi
fi

head_ "Minisign signatures verify with the key this version requires"
EXPECTED_KEY=$(/usr/bin/python3 Scripts/resolve-minisign-key.py "$VERSION" 2>/dev/null)
if [ -z "$EXPECTED_KEY" ]; then
  bad "no Minisign key is registered for version $VERSION"
  note "Fix: add it to Configuration/minisign-keys.json."
else
  ok "version $VERSION must verify with $EXPECTED_KEY"
  PUB_FILE=$(/usr/bin/python3 Scripts/resolve-minisign-key.py "$VERSION" --pub 2>/dev/null)
  # Verify against the key the REGISTRY names, not the key shipped in the
  # release: an attacker-or-mistake-supplied minisign.pub would otherwise
  # verify its own signatures happily.
  PUB_LINE=$(sed -n 2p "$PUB_FILE")
  shopt -s nullglob
  sigs=("$WORK"/*.minisig)
  shopt -u nullglob
  if [ "${#sigs[@]}" -eq 0 ]; then
    bad "the release carries no .minisig signatures at all"
  else
    for sig in "${sigs[@]}"; do
      target="${sig%.minisig}"
      if [ ! -f "$target" ]; then
        bad "$(basename "$sig") signs $(basename "$target"), which is not in the release"
        continue
      fi
      if minisign -Vm "$target" -P "$PUB_LINE" >/dev/null 2>&1; then
        ok "$(basename "$target") verifies with $EXPECTED_KEY"
      else
        bad "$(basename "$target") does NOT verify with $EXPECTED_KEY"
        note "Expected: every signature made by the key Configuration/minisign-keys.json names."
        note "Fix: do not publish. Investigate which key signed it before changing anything."
      fi
    done
  fi

  # The key file shipped for users' convenience must be the same key.
  if [ -s "$WORK/minisign.pub" ]; then
    if [ "$(sed -n 2p "$WORK/minisign.pub")" = "$PUB_LINE" ]; then
      ok "the minisign.pub attached to the release is $EXPECTED_KEY"
    else
      bad "the minisign.pub attached to the release is NOT the key this version requires"
      note "Users verifying with the attached key would be verifying against the wrong key."
    fi
  fi
fi

head_ "The DMG a user opens"
if [ -s "$DMG" ]; then
  if codesign --verify --strict --verbose=2 "$DMG" >/dev/null 2>&1; then
    ok "DMG signature is valid"
  else
    bad "DMG signature is invalid"
  fi
  if xcrun stapler validate "$DMG" >/dev/null 2>&1; then
    ok "DMG carries a stapled notarization ticket"
  else
    bad "DMG has no stapled ticket — it would need the network to open"
  fi
  if spctl --assess --type open --context context:primary-signature "$DMG" >/dev/null 2>&1; then
    ok "Gatekeeper accepts the DMG"
  else
    bad "Gatekeeper rejects the DMG"
  fi

  MOUNT=$(hdiutil attach -nobrowse -readonly "$DMG" 2>/dev/null | tail -1 | sed 's/.*\(\/Volumes\/.*\)/\1/')
  if [ -z "$MOUNT" ] || [ ! -d "$MOUNT" ]; then
    bad "the DMG does not mount"
  else
    ok "DMG mounts at $MOUNT"
    APP="$MOUNT/CoreTend.app"
    if [ -d "$APP" ]; then
      ok "CoreTend.app is present inside the DMG"
      PLIST="$APP/Contents/Info.plist"
      GOT_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null)
      GOT_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST" 2>/dev/null)
      GOT_ARCH=$(lipo -archs "$APP/Contents/MacOS/CoreTend" 2>/dev/null)

      [ "$GOT_VERSION" = "$VERSION" ] && ok "app version is $VERSION" || {
        bad "app version mismatch"; note "Expected: $VERSION   Found: ${GOT_VERSION:-<none>}"; }
      [ "$GOT_ID" = "$EXPECTED_BUNDLE_ID" ] && ok "bundle id is $EXPECTED_BUNDLE_ID" || {
        bad "bundle id mismatch"; note "Expected: $EXPECTED_BUNDLE_ID   Found: ${GOT_ID:-<none>}"; }
      [ "$GOT_ARCH" = "$EXPECTED_ARCH" ] && ok "architecture is $EXPECTED_ARCH" || {
        bad "architecture mismatch"; note "Expected: $EXPECTED_ARCH   Found: ${GOT_ARCH:-<none>}"; }

      SIG=$(codesign -dvv "$APP" 2>&1)
      echo "$SIG" | grep -q "flags=0x10000(runtime)" \
        && ok "hardened runtime is enabled" || bad "hardened runtime is NOT enabled"
      echo "$SIG" | grep -q "Authority=Developer ID Application" \
        && ok "signed by a Developer ID Application identity" || bad "not Developer ID signed"
      echo "$SIG" | grep -q "TeamIdentifier=$EXPECTED_TEAM" \
        && ok "Team ID is $EXPECTED_TEAM" || {
          bad "Team ID mismatch"; note "Expected: $EXPECTED_TEAM"; }

      codesign --verify --deep --strict "$APP" >/dev/null 2>&1 \
        && ok "app signature verifies (deep, strict)" || bad "app signature does not verify"
      xcrun stapler validate "$APP" >/dev/null 2>&1 \
        && ok "app carries a stapled ticket" || bad "app has NO stapled ticket"
      spctl --assess --type exec "$APP" >/dev/null 2>&1 \
        && ok "Gatekeeper accepts the app" || bad "Gatekeeper rejects the app"

      # The v1.0.0 defect: signed, notarized, stapled — and it did not launch.
      if bash Scripts/test-app-launch.sh "$APP" >/dev/null 2>&1; then
        ok "the app actually launches"
      else
        bad "the app does NOT launch"
        note "This is the v1.0.0 failure: every signature check passes and users still"
        note "cannot open it. Run Scripts/test-app-launch.sh \"$APP\" for the output."
      fi
    else
      bad "CoreTend.app is missing from the DMG"
    fi
  fi
fi

head_ "The ZIP a user downloads"
if [ -s "$ZIP" ]; then
  ditto -x -k "$ZIP" "$WORK/zx" >/dev/null 2>&1
  ZAPP="$WORK/zx/CoreTend.app"
  if [ -d "$ZAPP" ]; then
    ok "CoreTend.app is present in the ZIP"
    codesign --verify --deep --strict "$ZAPP" >/dev/null 2>&1 \
      && ok "ZIP app signature verifies" || bad "ZIP app signature does not verify"
    xcrun stapler validate "$ZAPP" >/dev/null 2>&1 \
      && ok "ZIP app carries a stapled ticket" || {
        bad "the app inside the ZIP has NO stapled ticket"
        note "This is the v1.0.0 ZIP defect: it opens only on a Mac that can reach"
        note "Apple's notary service, and reports 'damaged' offline."; }
  else
    bad "the ZIP does not contain CoreTend.app at its root"
  fi
fi

head_ "No build junk or secrets rode along"
for pattern in '*.p8' '*.key' '*.pem' '*.p12' '.env*'; do
  found=$(find "$WORK" -name "$pattern" 2>/dev/null | head -3)
  if [ -n "$found" ]; then
    bad "a credential-shaped file is present in the release: $pattern"
    echo "$found" | sed 's/^/       /'
  fi
done
[ "$fail" -eq 0 ] && ok "no credential-shaped files among the published assets"

printf '\n'
if [ "$fail" -ne 0 ]; then
  echo "verify-published-artifacts: $fail check(s) FAILED for $TAG — do not publish."
  exit 1
fi
echo "verify-published-artifacts: every check passed for $TAG."
