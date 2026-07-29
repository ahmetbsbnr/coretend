#!/bin/zsh
# Proves the DMG build needs no Finder, no GUI session and no human.
#
# Builds from a fresh clone of HEAD in a throwaway directory, with a temporary
# HOME (so no cached venv, no user defaults, no prior Finder state), with the
# Finder quit, and with the environment stripped of anything that could hand
# the build a graphical session. Then runs the full layout assertion on the
# result.
#
# This is the regression test for the 0.9.1-rc.2 failure mode: a build that
# quietly produced an unstyled DMG whenever the Finder was unavailable.
set -e
cd "$(dirname "$0")/.."
REPO="$PWD"

WORK=$(mktemp -d)
FAKE_HOME="$WORK/home"
mkdir -p "$FAKE_HOME"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo "test-dmg-headless: cloning HEAD into $WORK/clone"
git clone --quiet --no-hardlinks "$REPO" "$WORK/clone"
cd "$WORK/clone"

# The brand assets are generated, not committed as build inputs — regenerate
# them in the clone so this also proves the clone is self-sufficient.
swift Resources/Brand/Sources/generate-brand-assets.swift >/dev/null

echo "test-dmg-headless: quitting the Finder so it cannot service the build"
killall Finder 2>/dev/null || true

# env -i would lose PATH and the toolchain; instead strip exactly the variables
# that grant or identify a window session, and point HOME somewhere empty.
echo "test-dmg-headless: building with no session variables and HOME=$FAKE_HOME"
env -u DISPLAY -u SECURITYSESSIONID -u __CF_USER_TEXT_ENCODING \
    -u SSH_AUTH_SOCK -u TERM_SESSION_ID -u XPC_SERVICE_NAME \
    HOME="$FAKE_HOME" \
    zsh Scripts/package-dmg.sh 0.0.0-headless

DMG="Release/CoreTend-0.0.0-headless-arm64-unsigned.dmg"
[ -f "$DMG" ] || { echo "test-dmg-headless: FAIL — no DMG produced"; exit 1; }

echo "test-dmg-headless: asserting the layout of the headless build"
env HOME="$FAKE_HOME" zsh Scripts/test-dmg-layout.sh "$DMG" "CoreTend 0.0.0-headless"

echo "test-dmg-headless: PASS — styled DMG built with the Finder quit, from a clean clone"
