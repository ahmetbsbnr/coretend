#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
zip_path="$repo_root/Artifacts/CoreTend-local-unsigned.zip"
app_path="$repo_root/Artifacts/CoreTend.app"
test -f "$zip_path"
test -x "$app_path/Contents/MacOS/CoreTendApp"
plutil -lint "$app_path/Contents/Info.plist"
unzip -t "$zip_path"
unzip -Z1 "$zip_path" | grep -Fx 'CoreTend.app/Contents/MacOS/CoreTendApp'
file "$app_path/Contents/MacOS/CoreTendApp"
shasum -a 256 "$zip_path"
printf 'Verified local bundle structure only; signature, notarization and runtime remain unverified.\n'
