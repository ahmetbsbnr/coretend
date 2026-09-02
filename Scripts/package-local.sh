#!/bin/zsh
# Assembles CoreTend.app from the release binary (SwiftPM, no Xcode).
#
# The release build uses a scratch path outside $HOME. SwiftPM compiles the
# absolute path of the generated resource bundle into the binary as the
# fallback branch of resource_bundle_accessor.swift, and that string survives
# into the shipped app. Built under the default .build/, it reads:
#
#   /Users/<real-name>/Documents/.../app/.build/.../CoreTend_CoreTendApp.bundle
#
# — the developer's account name and folder layout, inside a binary meant for
# other people. The fallback is never *reached* (the bundle ships inside
# Contents/Resources), but a string does not have to be reached to be read.
# Building from a scratch path outside $HOME makes that same fallback carry
# nothing personal.
set -e
cd "$(dirname "$0")/.."

SCRATCH="${CORETEND_SCRATCH_PATH:-/tmp/coretend-release-build}"
swift build ${CORETEND_SWIFT_BUILD_FLAGS:-} -c release --scratch-path "$SCRATCH"
BIN_DIR="$SCRATCH/release"

APP="${CORETEND_APP_BUNDLE_PATH:-build/CoreTend.app}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CoreTend" "$APP/Contents/MacOS/CoreTend"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Brand/Generated/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/Brand/Generated/MenuBarTemplate.png "$APP/Contents/Resources/MenuBarTemplate.png"
cp Resources/Brand/Generated/MenuBarTemplate@2x.png "$APP/Contents/Resources/MenuBarTemplate@2x.png"
# SwiftPM resource bundles (e.g. localization strings) must ship inside the
# app bundle's Resources, or the runtime accessor falls back to the absolute
# build path described above — which breaks the app on any machine other than
# the one it was built on.
for bundle in "$BIN_DIR"/*.bundle; do
  [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done
# Licence texts ship inside the bundle, not loose on the DMG volume root. They
# have to be added before signing, or the copy breaks the sealed CodeResources
# and macOS reports the app as damaged.
cp LICENSE NOTICE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
# Swift's release linker keeps N_OSO/debug records that name every source file
# with its absolute checkout path. They are not needed to run the distributed
# executable and would disclose the build account inside the shipped binary.
# Strip only debug symbols before sealing the bundle; a future symbolicated
# Developer ID build can archive a separate dSYM outside the application.
xcrun strip -S "$APP/Contents/MacOS/CoreTend"

# Signing identity for LOCAL runs only (never the release path — that is
# Scripts/sign-and-notarize.sh with the Developer ID identity).
#
# Ad-hoc ("-") has no stable designated requirement, so macOS TCC keys the
# app's Full-Disk / Downloads / Desktop grants to the exact code hash. Every
# rebuild changes that hash, so every rebuild re-prompts for folder access —
# which is not how the shipped Developer ID build behaves (there, the grant
# is remembered once, permanently).
#
# Set CORETEND_LOCAL_SIGN_ID to a stable identity to make local grants stick
# across rebuilds. If unset, we auto-pick an installed "Apple Development"
# identity (its whole purpose is local development); failing that, ad-hoc.
SIGN_ID="${CORETEND_LOCAL_SIGN_ID:-}"
if [ -z "$SIGN_ID" ]; then
  SIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null \
            | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"')
fi
if [ -n "$SIGN_ID" ]; then
  echo "Signing locally with: $SIGN_ID (TCC grants persist across rebuilds)"
  codesign --force --options runtime --sign "$SIGN_ID" "$APP"
else
  echo "Signing locally ad-hoc — macOS will re-prompt for folder access on each rebuild."
  codesign --force --sign - "$APP"
fi
echo "Built: $APP (scratch: $SCRATCH)"
