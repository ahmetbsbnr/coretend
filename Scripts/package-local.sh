#!/bin/zsh
# Assembles MacCare Local.app from the release binary (SwiftPM, no Xcode).
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP="build/MacCare Local.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MacCareLocal "$APP/Contents/MacOS/MacCareLocal"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Brand/Generated/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/Brand/Generated/MenuBarTemplate.png "$APP/Contents/Resources/MenuBarTemplate.png"
cp Resources/Brand/Generated/MenuBarTemplate@2x.png "$APP/Contents/Resources/MenuBarTemplate@2x.png"
# SwiftPM resource bundles (e.g. localization strings) must ship inside the
# app bundle's Resources, or the runtime accessor falls back to an absolute
# .build path baked into the binary at compile time — which breaks the app
# on any machine other than the one it was built on.
for bundle in .build/release/*.bundle; do
  [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done
codesign --force --sign - "$APP"
echo "Built: $APP"
