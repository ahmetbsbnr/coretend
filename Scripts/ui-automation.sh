#!/bin/zsh
# Runs the XCUITest interaction suite against the built CoreTend.app.
# usage: ui-automation.sh [-only <TestClass/testMethod>]
set -euo pipefail
cd "$(dirname "$0")/.."
app="${CORETEND_APP:-$PWD/build/CoreTend.app}"
[[ -d "$app" ]] || { print -u2 "build the app first: Scripts/package-local.sh"; exit 2; }
cd Tests/UIAutomation
xcodegen generate >/dev/null
only=()
[[ "${1:-}" == "-only" ]] && only=(-only-testing:"CoreTendUIAutomation/$2")
CORETEND_UI_APP_PATH="$app" \
xcodebuild test \
  -project CoreTendUIAutomation.xcodeproj \
  -scheme CoreTendUIAutomation \
  -destination 'platform=macOS' \
  $only 2>&1 | tail -40
