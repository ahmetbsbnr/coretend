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
codesign --force --sign - "$APP"
echo "Built: $APP"
