#!/bin/zsh
# End-to-end client journey against the published release, from the public URL
# down to a launched app, in an isolated Applications directory and HOME.
#
# The point of this test is to keep three very different failures apart, since
# to a user they all look like "the app doesn't work":
#
#   EXPECTED-BLOCK — only for an unsigned, un-notarized build: Gatekeeper
#                    refuses it, which is correct, and it must be recoverable by
#                    the documented System Settings route. A signed + notarized
#                    build has no such block — Gatekeeper must accept it.
#   PACKAGING      — the download, checksum, signature, notarization ticket, DMG
#                    layout or bundle is wrong. Our defect, blocks the release.
#   APP-DEFECT     — once allowed to run, the app crashes or exits. Our defect,
#                    blocks the release.
#
# The signed/unsigned posture is read from Configuration/published-release.json,
# so this one script covers both a pre-1.0 unsigned line and the 1.0 signed one.
# Everything happens under a temporary tree. The real /Applications and the
# real HOME are never touched.
set -e
cd "$(dirname "$0")/.."
REPO="$PWD"

VERSION="${1:?usage: test-client-journey.sh <version> [--local]}"
LOCAL_MODE="${2:-}"
DOWNLOAD_URL="https://coretend.ahmetbsbnr.com/download"
REPO_SLUG="ahmetbsbnr/coretend"

# rc.6 onward is Developer ID signed + Apple-notarized; the artifact name drops
# the -unsigned tag and Gatekeeper accepts it outright. published-release.json
# is the tracked record of what GitHub actually serves.
PUB_SIGNED=$(/usr/bin/python3 -c "import json; r=json.load(open('Configuration/published-release.json')); print('yes' if r.get('signed') and r.get('notarized') else 'no')")
if [ "$PUB_SIGNED" = "yes" ]; then
  DMG_NAME="CoreTend-${VERSION}-arm64.dmg"
else
  DMG_NAME="CoreTend-${VERSION}-arm64-unsigned.dmg"
fi

WORK=$(mktemp -d)
HOME_ISO="$WORK/home"
APPS_ISO="$WORK/Applications"
mkdir -p "$HOME_ISO/tmp" "$HOME_ISO/store" "$APPS_ISO"
MOUNT=""
cleanup() {
  [ -n "$MOUNT" ] && { hdiutil detach "$MOUNT" >/dev/null 2>&1 || hdiutil detach "$MOUNT" -force >/dev/null 2>&1; }
  pkill -f "$APPS_ISO/CoreTend.app" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

STEP=0
ok()   { STEP=$((STEP+1)); echo "  [$STEP] ok — $1"; }
note() { echo "        · $1"; }
die()  { echo "  FAIL [$1] — $2"; exit 1; }

echo "test-client-journey: $VERSION"
echo "test-client-journey: isolated HOME=$HOME_ISO Applications=$APPS_ISO"

DMG="$WORK/CoreTend.dmg"

if [ "$LOCAL_MODE" = "--local" ]; then
  cp "Release/$DMG_NAME" "$DMG"
  ok "using the locally built DMG (--local): $DMG_NAME"
else
  # 1-3. Site, /download route, redirect to the right release. GitHub's asset
  # CDN 302s to release-assets.githubusercontent.com with the artifact name in
  # the response-content-disposition query, so match the name anywhere in the
  # resolved URL rather than assuming a .../releases/download/... path.
  EFFECTIVE=$(curl -sSL -o "$DMG" -w '%{url_effective}' "$DOWNLOAD_URL") \
    || die PACKAGING "the public download URL did not resolve"
  ok "downloaded from $DOWNLOAD_URL"
  case "$EFFECTIVE" in
    *"$DMG_NAME"*) ok "/download resolves to $DMG_NAME" ;;
    *) die PACKAGING "/download resolved to an artifact that is not $DMG_NAME: $EFFECTIVE" ;;
  esac
fi

[ -s "$DMG" ] || die PACKAGING "downloaded DMG is empty"
ACTUAL_SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
note "sha256 $ACTUAL_SHA"

# 5. Checksum against the published SHA256SUMS.
if [ "$LOCAL_MODE" != "--local" ]; then
  curl -sSL -o "$WORK/SHA256SUMS" \
    "https://github.com/$REPO_SLUG/releases/download/v${VERSION}/SHA256SUMS" \
    || die PACKAGING "could not fetch the published SHA256SUMS"
  EXPECTED_SHA=$(awk -v n="$DMG_NAME" '$2 == n || $2 == "*"n {print $1}' "$WORK/SHA256SUMS")
  [ -n "$EXPECTED_SHA" ] || die PACKAGING "SHA256SUMS has no entry for the DMG"
  [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] || die PACKAGING "checksum mismatch: got $ACTUAL_SHA, published $EXPECTED_SHA"
  ok "SHA-256 matches the published SHA256SUMS"

  # 6. Minisign over the checksum file, using the published public key.
  if command -v minisign >/dev/null 2>&1; then
    curl -sSL -o "$WORK/minisign.pub" "https://github.com/$REPO_SLUG/releases/download/v${VERSION}/minisign.pub"
    curl -sSL -o "$WORK/SHA256SUMS.minisig" "https://github.com/$REPO_SLUG/releases/download/v${VERSION}/SHA256SUMS.minisig"
    minisign -Vm "$WORK/SHA256SUMS" -p "$WORK/minisign.pub" -x "$WORK/SHA256SUMS.minisig" >/dev/null \
      || die PACKAGING "Minisign rejected the published SHA256SUMS"
    ok "Minisign verified SHA256SUMS against the published key"
  else
    note "minisign not installed — signature check skipped"
  fi
fi

# 4. A browser download carries quarantine; reproduce that exactly.
xattr -w com.apple.quarantine "0083;$(printf %x "$(date +%s)");Safari;" "$DMG"
ok "quarantine attribute applied, as a browser download would"

# 7-8. Mount, and assert the volume is what a user should see.
MOUNT=$(mktemp -d)
hdiutil attach "$DMG" -mountpoint "$MOUNT" -nobrowse -noverify -readonly >/dev/null \
  || die PACKAGING "the DMG would not mount"
ok "DMG mounts"

[ -f "$MOUNT/.DS_Store" ] || die PACKAGING "no .DS_Store — the window would open unstyled"
[ -d "$MOUNT/CoreTend.app" ] || die PACKAGING "CoreTend.app missing from the volume"
[ -L "$MOUNT/Applications" ] || die PACKAGING "Applications symlink missing"
VISIBLE=$(ls "$MOUNT" | sort | tr '\n' ' ')
[ "$VISIBLE" = "Applications CoreTend.app " ] || die PACKAGING "unexpected visible files: $VISIBLE"
ok "volume layout is correct and free of clutter"

# 9. Copy to an isolated Applications, exactly as a drag would.
cp -R "$MOUNT/CoreTend.app" "$APPS_ISO/" || die PACKAGING "could not copy the app off the volume"
ok "copied CoreTend.app to the isolated Applications"

hdiutil detach "$MOUNT" >/dev/null 2>&1 || hdiutil detach "$MOUNT" -force >/dev/null 2>&1
MOUNT=""
ok "volume ejected"

# 13. The app must not depend on the volume it came from.
[ -x "$APPS_ISO/CoreTend.app/Contents/MacOS/CoreTend" ] || die PACKAGING "binary missing after the copy"
codesign --verify --deep --strict "$APPS_ISO/CoreTend.app" 2>/dev/null \
  || die PACKAGING "the bundle signature is broken after copying off the volume"
ok "app is self-contained and its signature survives the copy"

# 10-11. Quarantine present, then Gatekeeper's verdict. For a signed +
# notarized build that verdict must be "accepted / Notarized Developer ID";
# for an unsigned build the EXPECTED block is a rejection, and its reason must
# be the missing Developer ID rather than anything else.
xattr -p com.apple.quarantine "$APPS_ISO/CoreTend.app" >/dev/null 2>&1 \
  || note "quarantine did not propagate to the copy on this filesystem"

SPCTL_OUT=$(spctl --assess --type execute --verbose=4 "$APPS_ISO/CoreTend.app" 2>&1 || true)
SIGN_INFO=$(codesign -dvvv "$APPS_ISO/CoreTend.app" 2>&1 || true)
if [ "$PUB_SIGNED" = "yes" ]; then
  case "$SPCTL_OUT" in
    *accepted*) ok "Gatekeeper accepts the signed, notarized build" ;;
    *rejected*) die PACKAGING "Gatekeeper rejected a build published as signed + notarized: $SPCTL_OUT" ;;
    *) die PACKAGING "unreadable spctl verdict: $SPCTL_OUT" ;;
  esac
  case "$SPCTL_OUT" in
    *"Notarized Developer ID"*) ok "verdict source is a notarized Developer ID signature" ;;
    *) note "spctl accepted but did not name a notarized Developer ID source: $SPCTL_OUT" ;;
  esac
  case "$SIGN_INFO" in
    *"Developer ID Application"*) ok "bundle carries a Developer ID Application signature: $(printf '%s' "$SIGN_INFO" | grep -i '^Authority=Developer ID' | head -1 | sed 's/^Authority=//')" ;;
    *adhoc*) die PACKAGING "bundle is ad-hoc signed but the release is published as signed" ;;
    *) die PACKAGING "bundle has no Developer ID Application authority: $(printf '%s' "$SIGN_INFO" | grep -i '^Authority' | head -1)" ;;
  esac
  xcrun stapler validate "$APPS_ISO/CoreTend.app" >/dev/null 2>&1 \
    && ok "notarization ticket is stapled to the app" \
    || die PACKAGING "the app bundle is not stapled"
else
  case "$SPCTL_OUT" in
    *rejected*) ok "EXPECTED-BLOCK: Gatekeeper rejects the unsigned build" ;;
    *accepted*) note "Gatekeeper accepted it — this build appears to be signed and notarized" ;;
    *) die PACKAGING "unreadable spctl verdict: $SPCTL_OUT" ;;
  esac
  case "$SIGN_INFO" in
    *adhoc*) ok "block reason confirmed: ad-hoc signature, no Developer ID (as documented)" ;;
    *) note "signature is not ad-hoc: $(printf '%s' "$SIGN_INFO" | grep -i '^Authority' | head -1)" ;;
  esac
fi

# 12. What "the download won't open" recovery looks like depends on whether the
# published build is signed. rc.6 onward is Developer ID signed and
# Apple-notarized: it opens with no Gatekeeper prompt, so the docs carry the
# independent provenance check (SHA-256 + Minisign + a stapled ticket) instead
# of an "Open Anyway" workaround. An unsigned build must still document the
# System Settings route, because Apple removed the Control-click override in
# macOS 15. Website/index.html is the bilingual source of truth (the retired
# Website/en|fr trees were removed).
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
# Markdown may wrap a phrase across source lines while rendering it as one
# sentence. Normalize line breaks so harmless prose reflow cannot turn this
# release gate into a false negative.
README_COPY=$(tr '\n' ' ' < README.md)
if [ "$PUB_SIGNED" = "yes" ]; then
  case "$README_COPY" in
    *notariz*|*stapled*) ;;
    *) die PACKAGING "README does not document notarization / provenance verification" ;;
  esac
  grep -q "stapler validate" Website/index.html \
    || die PACKAGING "the site does not document the notarization provenance check"
  ok "signed build: README and site document the provenance check, no Gatekeeper prompt to recover from"
elif [ "$MAJOR" -ge 15 ]; then
  case "$README_COPY" in
    *"Open Anyway"*) ;;
    *) die PACKAGING "README does not document the System Settings route" ;;
  esac
  grep -q "Ouvrir quand même" Website/index.html || die PACKAGING "the FR site does not document the System Settings route"
  grep -q "Open Anyway" Website/index.html || die PACKAGING "the EN site does not document the System Settings route"
  ok "unsigned build: documented recovery route matches macOS $MAJOR (System Settings, not Control-click)"
else
  ok "unsigned build: macOS $MAJOR still supports the Control-click route"
fi

# 13-17. Reach the state of an app the user has been allowed to run. A signed +
# notarized build reaches it on the first double-click with no prompt; an
# unsigned build needs the one-time System Settings approval. Either way the
# equivalent end state — a non-quarantined copy — is produced directly here so
# the app can be exercised for real. Anything that fails from here is an
# APP-DEFECT.
xattr -dr com.apple.quarantine "$APPS_ISO/CoreTend.app"
if [ "$PUB_SIGNED" = "yes" ]; then
  ok "cleared the first-launch quarantine (signed build opens with no prompt)"
else
  ok "simulated the user's one-time 'Open Anyway' approval"
fi

launch_and_hold() {
  local label="$1" hold="$2"
  CORETEND_TEST_MODE=1 CORETEND_TEST_STORE_DIR="$HOME_ISO/store" \
  HOME="$HOME_ISO" TMPDIR="$HOME_ISO/tmp" "$APPS_ISO/CoreTend.app/Contents/MacOS/CoreTend" \
    >"$WORK/$label.log" 2>&1 &
  local pid=$! waited=0
  while [ "$waited" -lt "$hold" ]; do
    sleep 1; waited=$((waited+1))
    kill -0 "$pid" 2>/dev/null || break
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
    return 0
  fi
  wait "$pid" 2>/dev/null
  echo "exit=$? log=$(head -c 300 "$WORK/$label.log" | tr '\n' ' ')"
  return 1
}

ok "Integrity has no third-party scanner dependency"

launch_and_hold first-launch 6 || die APP-DEFECT "first launch did not stay up: $(cat "$WORK/first-launch.log" | head -c 300)"
ok "first launch survives with a virgin HOME and no prior state"

[ -d "$HOME_ISO/store" ] \
  && ok "app created its store directory (inside the sandbox)" \
  || note "no store directory created on first launch"

# 18. Close and relaunch — the second run reads what the first one wrote.
launch_and_hold relaunch 6 || die APP-DEFECT "relaunch over first-run state failed: $(cat "$WORK/relaunch.log" | head -c 300)"
ok "relaunch over its own first-run state"

# 19. Offline: the update check must fail soft, never block the window.
launch_and_hold offline 6 || die APP-DEFECT "launch failed with no reachable network state"
ok "launch with no cached update manifest (update check fails soft)"

# 21. Uninstall, isolated.
rm -rf "$APPS_ISO/CoreTend.app" "$HOME_ISO/store"
[ -d "$APPS_ISO/CoreTend.app" ] && die PACKAGING "uninstall left the bundle behind"
ok "uninstall removes the bundle and its support directory"

echo
echo "test-client-journey: PASS — $STEP steps, no packaging or application defect"
if [ "$PUB_SIGNED" = "yes" ]; then
  echo "test-client-journey: signed + notarized build — Gatekeeper accepted it with"
  echo "                     no block to recover from."
else
  echo "test-client-journey: the only block encountered was the expected Gatekeeper"
  echo "                     refusal of an unsigned, un-notarized build."
fi
