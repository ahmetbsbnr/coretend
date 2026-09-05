#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Non-interactive Xcode SHIPPING build + structural verification.
#
# SwiftPM (Scripts/build.sh / Scripts/test.sh) stays the authoritative build
# for every domain module and every test — this script does NOT replace it.
# The Xcode project exists only to produce the Apple bundle structures
# SwiftPM cannot express: the .app, the nested WidgetKit .appex, the App
# Intents metadata bundle, entitlements, and the nested-signing relationship.
#
# Usage:
#   Scripts/build-xcode.sh              # unsigned Release build + verify (CI/local)
#   CORETEND_XCODE_DERIVED=/path ...    # override the derived-data location
#
# An ordinary build needs NO Developer ID credentials: it signs ad-hoc-off
# (CODE_SIGNING_ALLOWED=NO). The signed release lane is
# Scripts/sign-and-notarize.sh, which consumes the .app this script leaves at
# build/CoreTend.app.
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="CoreTend-App"
PROJECT="CoreTend.xcodeproj"
DERIVED="${CORETEND_XCODE_DERIVED:-$(mktemp -d)/coretend-xcode-dd}"
OUT_APP="build/CoreTend.app"

command -v xcodegen >/dev/null 2>&1 || {
  echo "FAIL: xcodegen not installed (brew install xcodegen)"; exit 1
}

echo "== Regenerating $PROJECT from project.yml =="
xcodegen generate --quiet
# The generated project is tracked; drift means project.yml changed without
# a regenerate. The repository doctor also checks this.
if ! git diff --quiet -- "$PROJECT" 2>/dev/null; then
  echo "NOTE: $PROJECT changed after regeneration — commit the regenerated project."
fi

echo "== xcodebuild (Release, unsigned) -> $DERIVED =="
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=NO \
  build

BUILT_APP="$DERIVED/Build/Products/Release/CoreTend.app"
[ -d "$BUILT_APP" ] || { echo "FAIL: $BUILT_APP not produced"; exit 1; }

echo "== Verifying bundle structure =="
fail=0
check() { if eval "$1"; then echo "  OK: $2"; else echo "  FAIL: $2"; fail=1; fi }

check "[ -d '$BUILT_APP/Contents/PlugIns/CoreTendWidget.appex' ]" \
  "WidgetKit extension embedded at Contents/PlugIns/CoreTendWidget.appex"
check "[ -f '$BUILT_APP/Contents/PlugIns/CoreTendWidget.appex/Contents/MacOS/CoreTendWidget' ]" \
  "widget executable present"
WIDGET_EPI=$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' \
  "$BUILT_APP/Contents/PlugIns/CoreTendWidget.appex/Contents/Info.plist" 2>/dev/null || true)
check "[ '$WIDGET_EPI' = 'com.apple.widgetkit-extension' ]" \
  "widget NSExtensionPointIdentifier = com.apple.widgetkit-extension (got: ${WIDGET_EPI:-<none>})"
WIDGET_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
  "$BUILT_APP/Contents/PlugIns/CoreTendWidget.appex/Contents/Info.plist" 2>/dev/null || true)
check "[ '$WIDGET_ID' = 'com.ahmetbsbnr.coretend.widget' ]" \
  "widget bundle id = com.ahmetbsbnr.coretend.widget (got: ${WIDGET_ID:-<none>})"
check "find '$BUILT_APP/Contents/PlugIns/CoreTendWidget.appex' -path '*CoreTend_WidgetShared.bundle/*fr.lproj*' | grep -q ." \
  "widget ships its FR localization (CoreTend_WidgetShared.bundle/fr.lproj)"

check "[ -d '$BUILT_APP/Contents/Resources/Metadata.appintents' ]" \
  "App Intents metadata bundle present (Contents/Resources/Metadata.appintents)"
check "[ -f '$BUILT_APP/Contents/Resources/Metadata.appintents/extract.actionsdata' ]" \
  "extract.actionsdata present"
ACTIONS="$BUILT_APP/Contents/Resources/Metadata.appintents/extract.actionsdata"
if [ -f "$ACTIONS" ]; then
  INTENT_COUNT=$(python3 -c "import json;print(len(json.load(open('$ACTIONS')).get('actions',{})))" 2>/dev/null || echo 0)
  SHORTCUT_COUNT=$(python3 -c "import json;d=json.load(open('$ACTIONS'));print(len(d.get('appShortcuts',[]))+len(d.get('autoShortcuts',[])))" 2>/dev/null || echo 0)
  check "[ '$INTENT_COUNT' -ge 7 ]" "metadata contains >= 7 App Intents (found: $INTENT_COUNT)"
  check "[ '$SHORTCUT_COUNT' -ge 6 ]" "metadata contains >= 6 App Shortcuts (found: $SHORTCUT_COUNT)"
fi

check "[ -d '$BUILT_APP/Contents/Resources/CoreTend_CoreTendApp.bundle' ]" \
  "main app localization bundle present"
check "! grep -rlI '/Users/' '$BUILT_APP/Contents/Info.plist'" \
  "app Info.plist carries no absolute developer path"

echo "== Copying to $OUT_APP for the signing lane =="
rm -rf "$OUT_APP"
mkdir -p "$(dirname "$OUT_APP")"
ditto "$BUILT_APP" "$OUT_APP"
cp LICENSE NOTICE THIRD_PARTY_NOTICES.md "$OUT_APP/Contents/Resources/" 2>/dev/null || true

echo
if [ "$fail" -ne 0 ]; then
  echo "build-xcode.sh: FAILED — see FAIL lines above."
  exit 1
fi
echo "build-xcode.sh: OK"
echo "  Unsigned Release app: $OUT_APP"
echo "  Derived data:         $DERIVED"
echo "  Next (release only):  Scripts/sign-and-notarize.sh <version> <notary-profile>"
