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
codesign --force --sign - "$APP"
echo "Built: $APP"
