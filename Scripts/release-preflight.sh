#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Release preflight — everything that can be checked BEFORE a real Developer ID
# signing run, without signing, notarising, or touching any credential.
#
# Three independent sections, each with its own verdict:
#
#   1. BUNDLE STATIC AUDIT     scans a built CoreTend.app for machine paths,
#                              account names, secrets, test fixtures, and
#                              stray QA/debug resources. Reusable during the
#                              final signing pass.
#   2. APP GROUP CONFIG        the App Group entitlement wiring in the tracked
#                              .entitlements files (host + widget have it,
#                              Finder does not). This proves LOCAL config only
#                              — Apple Developer portal registration is a
#                              separate EXTERNAL check this script cannot do.
#   3. SIGNING TOOLCHAIN       Developer ID identity present, notarytool
#                              keychain profile resolves, and every CLI the
#                              signing pipeline needs is on PATH. Submits
#                              nothing; prints no secret.
#
# Usage:
#   Scripts/release-preflight.sh [path-to-CoreTend.app]
#
# Default app path is build/CoreTend.app (the Scripts/build-xcode.sh output).
# Section 1 is skipped with a NOTE if no .app is present, so the entitlement
# and toolchain sections still run in a fresh checkout.
#
# Exit code is non-zero if any real check FAILs. EXTERNAL VERIFICATION
# REQUIRED lines never fail the script — they are printed so they cannot be
# forgotten.
set -uo pipefail
cd "$(dirname "$0")/.."

APP="${1:-build/CoreTend.app}"
NOTARY_PROFILE="${CORETEND_NOTARY_PROFILE:-CoreTend-Notary}"
DEVELOPER_ID="${CORETEND_DEVELOPER_ID_APPLICATION:-Developer ID Application: Ahmet BASBUNAR (NSCUV5G738)}"

fail=0
ok()   { printf '  OK:       %s\n' "$1"; }
bad()  { printf '  FAIL:     %s\n' "$1"; fail=1; }
note() { printf '  NOTE:     %s\n' "$1"; }
ext()  { printf '  EXTERNAL: %s\n' "$1"; }

# ---------------------------------------------------------------------------
echo "== 1. BUNDLE STATIC AUDIT =="
if [ ! -d "$APP" ]; then
  note "$APP not present — skipping the bundle audit (run Scripts/build-xcode.sh first)."
else
  ACCOUNT_NAME=$(id -un)
  case "$ACCOUNT_NAME" in runner|runneradmin|root) ACCOUNT_NAME="" ;; esac

  # Text-ish files only: plists, json, strings, actionsdata, nib text, etc.
  # The Mach-O binaries are scanned separately with `strings`.
  TEXT_HITS=$(grep -rlI -e '/Users/' "$APP" 2>/dev/null || true)
  [ -z "$TEXT_HITS" ] && ok "no '/Users/...' absolute path in any text resource" \
                      || bad "absolute /Users path in bundle text resource(s): $(echo "$TEXT_HITS" | tr '\n' ' ')"

  if [ -n "$ACCOUNT_NAME" ]; then
    ACC_HITS=$(grep -rlI -e "$ACCOUNT_NAME" "$APP" 2>/dev/null || true)
    [ -z "$ACC_HITS" ] && ok "no build-account username in any text resource" \
                       || bad "build-account username in: $(echo "$ACC_HITS" | tr '\n' ' ')"
  else
    note "running as a CI service account — username scan skipped"
  fi

  SECRET_HITS=$(grep -rlIE 'RESEND_API_KEY|ADMIN_TOKEN|POSTGRES_URL|AUTH_SECRET|BEGIN [A-Z ]*PRIVATE KEY|xox[bp]-[0-9A-Za-z-]{10,}|sk_live_[0-9A-Za-z]{10,}' "$APP" 2>/dev/null || true)
  [ -z "$SECRET_HITS" ] && ok "no secret markers in bundle resources" \
                        || bad "secret marker(s) in: $(echo "$SECRET_HITS" | tr '\n' ' ')"

  ENV_HITS=$(find "$APP" \( -name '.env' -o -name '.env.*' -o -name '*.xcconfig' \) 2>/dev/null || true)
  [ -z "$ENV_HITS" ] && ok "no .env / .xcconfig files inside the bundle" \
                     || bad "config/env file(s) inside the bundle: $(echo "$ENV_HITS" | tr '\n' ' ')"

  FIXTURE_HITS=$(find "$APP" \( -name '*.xctest' -o -ipath '*fixture*' -o -ipath '*VisualAudit*' -o -ipath '*_capture_*' -o -ipath '*/Tests/*' \) 2>/dev/null || true)
  [ -z "$FIXTURE_HITS" ] && ok "no test bundles / fixtures / VisualAudit captures inside the bundle" \
                         || bad "test/QA artefact(s) inside the bundle: $(echo "$FIXTURE_HITS" | tr '\n' ' ')"

  # Main + nested executables: no dev paths or secrets baked into the binary.
  BIN_BAD=0
  while IFS= read -r bin; do
    file "$bin" 2>/dev/null | grep -q "Mach-O" || continue
    if strings -a "$bin" 2>/dev/null | grep -qE "/Users/${ACCOUNT_NAME:-__no_such__}/|RESEND_API_KEY|ADMIN_TOKEN|POSTGRES_URL|sk_live_[0-9A-Za-z]{10,}"; then
      bad "secret/dev-path string in Mach-O: $bin"
      BIN_BAD=1
    fi
  done < <(find "$APP" -type f -perm -u+x 2>/dev/null)
  [ "$BIN_BAD" -eq 0 ] && ok "no dev-path / secret strings in any Mach-O executable"

  # Debug config markers that must not ship.
  DEBUG_HITS=$(grep -rlIE 'DEBUG_MENU|StagingServer|http://localhost|127\.0\.0\.1|NSAllowsArbitraryLoads' "$APP" 2>/dev/null || true)
  [ -z "$DEBUG_HITS" ] && ok "no debug/staging/localhost markers in bundle resources" \
                       || bad "debug/staging marker(s) in: $(echo "$DEBUG_HITS" | tr '\n' ' ')"
fi

# ---------------------------------------------------------------------------
echo
echo "== 2. APP GROUP — LOCAL ENTITLEMENT CONFIG =="
GROUP="group.com.ahmetbsbnr.coretend"
HOST_ENT="Configuration/CoreTend.entitlements"
WIDGET_ENT="Configuration/CoreTendWidget.entitlements"
FINDER_ENT="Configuration/CoreTendFinder.entitlements"

# Read the actual <key>...application-groups</key> array, not comment prose,
# via PlistBuddy. Absent key -> non-zero exit -> treated as "no App Group".
ent_group() { /usr/libexec/PlistBuddy -c "Print :com.apple.security.application-groups:0" "$1" 2>/dev/null; }
[ "$(ent_group "$HOST_ENT")"   = "$GROUP" ] && ok "host   $HOST_ENT declares $GROUP"   || bad "host entitlements missing $GROUP"
[ "$(ent_group "$WIDGET_ENT")" = "$GROUP" ] && ok "widget $WIDGET_ENT declares $GROUP" || bad "widget entitlements missing $GROUP"
if /usr/libexec/PlistBuddy -c "Print :com.apple.security.application-groups" "$FINDER_ENT" >/dev/null 2>&1; then
  bad "Finder $FINDER_ENT declares an App Group — by design it must not (handoff is a coretend:// URL)"
else
  ok "Finder $FINDER_ENT has NO App Group key (by design)"
fi
grep -q "com.apple.security.app-sandbox" "$WIDGET_ENT" && ok "widget entitlements set app-sandbox = true" || bad "widget entitlements missing app-sandbox"
grep -q "com.apple.security.app-sandbox" "$FINDER_ENT" && ok "Finder entitlements set app-sandbox = true" || bad "Finder entitlements missing app-sandbox"
grep -q "com.apple.security.app-sandbox" "$HOST_ENT"   && bad "host entitlements set app-sandbox — the host is deliberately NOT sandboxed" || ok "host entitlements do NOT set app-sandbox (by design)"
if grep -qE 'com\.apple\.security\.(network\.client|network\.server|personal-information|automation|cs\.[a-z-]+|files\.all)' "$HOST_ENT" "$WIDGET_ENT" "$FINDER_ENT"; then
  bad "an unexpected broad entitlement is present — review the .entitlements files"
else
  ok "no unexpected broad entitlement (network/automation/cs.*/files.all) in any target"
fi
echo
ext "APPLE PORTAL REGISTRATION for $GROUP — cannot be verified locally."
ext "  It must exist in the Apple Developer portal (Identifiers -> App Groups)"
ext "  and be associated with BOTH App IDs:"
ext "    com.ahmetbsbnr.coretend         (host)"
ext "    com.ahmetbsbnr.coretend.widget  (widget)"
ext "  A Developer ID + notarised build carrying this entitlement will be"
ext "  rejected until that portal registration is in place."

# ---------------------------------------------------------------------------
echo
echo "== 3. SIGNING TOOLCHAIN (no signing performed) =="
for tool in codesign xcrun hdiutil spctl; do
  command -v "$tool" >/dev/null 2>&1 && ok "$tool on PATH" || bad "$tool not found on PATH"
done
xcrun --find notarytool >/dev/null 2>&1 && ok "xcrun notarytool available" || bad "xcrun notarytool not available"
xcrun --find stapler   >/dev/null 2>&1 && ok "xcrun stapler available"     || bad "xcrun stapler not available"

if security find-identity -v -p codesigning 2>/dev/null | grep -qF "$DEVELOPER_ID"; then
  ok "Developer ID identity present: ${DEVELOPER_ID%% (*} (...)"
else
  bad "Developer ID identity not in the codesigning keychain: '$DEVELOPER_ID'"
fi

if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  ok "notarytool keychain profile '$NOTARY_PROFILE' resolves (history query succeeded)"
else
  bad "notarytool keychain profile '$NOTARY_PROFILE' does not resolve"
fi

for f in Scripts/sign-and-notarize.sh Scripts/build-xcode.sh Scripts/package-dmg.sh Configuration/CoreTend.entitlements Configuration/CoreTendWidget.entitlements Configuration/CoreTendFinder.entitlements; do
  [ -f "$f" ] && ok "present: $f" || bad "missing: $f"
done

echo
if [ "$fail" -ne 0 ]; then
  echo "release-preflight.sh: FAILED — see FAIL lines above."
  exit 1
fi
echo "release-preflight.sh: PASSED (local checks). EXTERNAL lines above still require a human."
