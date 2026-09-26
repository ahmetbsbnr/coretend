#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
swift build -c release --product CoreTendApp
bin_dir="$(swift build -c release --show-bin-path)"
artifact_dir="$repo_root/Artifacts"
mkdir -p "$artifact_dir"
if [[ -L "$artifact_dir" ]]; then
  printf 'Refusing symlinked Artifacts directory.\n' >&2
  exit 1
fi
stage_dir="$(mktemp -d "$artifact_dir/.coretend-package.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
app_path="$stage_dir/CoreTend.app"
mkdir -p "$app_path/Contents/MacOS"
cp "$bin_dir/CoreTendApp" "$app_path/Contents/MacOS/CoreTendApp"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>CoreTendApp</string>
  <key>CFBundleIdentifier</key><string>local.coretend.reconstruction</string>
  <key>CFBundleName</key><string>CoreTend</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0-local</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
plutil -lint "$app_path/Contents/Info.plist"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$stage_dir/CoreTend-local-unsigned.zip"
rm -rf "$artifact_dir/CoreTend.app"
mv "$app_path" "$artifact_dir/CoreTend.app"
mv -f "$stage_dir/CoreTend-local-unsigned.zip" "$artifact_dir/CoreTend-local-unsigned.zip"
shasum -a 256 "$artifact_dir/CoreTend-local-unsigned.zip"
printf 'Local unsigned artifact: %s\n' "$artifact_dir/CoreTend-local-unsigned.zip"
