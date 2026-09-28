#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
swift build -c release --product CoreTendApp
bin_dir="$(swift build -c release --show-bin-path)"
artifact_dir="${CORETEND_ARTIFACT_DIR:-$repo_root/Artifacts}"
mkdir -p "$artifact_dir"
if [[ -L "$artifact_dir" ]]; then
  printf 'Refusing symlinked artifact directory.\n' >&2
  exit 1
fi
stage_dir="$(mktemp -d "$artifact_dir/.coretend-package.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
app_path="$stage_dir/CoreTend.app"
mkdir -p "$app_path/Contents/MacOS"
cp "$bin_dir/CoreTendApp" "$app_path/Contents/MacOS/CoreTendApp"
# App icon: the Icon Composer document (Liquid Glass on macOS 26+) compiled by actool, with the
# classic .icns it also produces for macOS 14 and 15.
mkdir -p "$app_path/Contents/Resources"
xcrun actool "$repo_root/Resources/Brand/AppIcon.icon" --compile "$app_path/Contents/Resources" \
  --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon \
  --output-partial-info-plist "$stage_dir/icon-partial.plist" >/dev/null
# actool's .icns stops at 256 px for macOS 14; the App Store requires every size up to 512@2x.
# Rebuild it from the 1024 px rendering of the same Icon Composer document.
iconset="$stage_dir/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$repo_root/Resources/Brand/Logo/coretend-app-icon-1024.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$repo_root/Resources/Brand/Logo/coretend-app-icon-1024.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app_path/Contents/Resources/AppIcon.icns"
cat > "$app_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>CoreTendApp</string>
  <key>CFBundleIdentifier</key><string>${CORETEND_BUNDLE_ID:-local.coretend.reconstruction}</string>
  <key>CFBundleName</key><string>CoreTend</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${CORETEND_VERSION:-0.1.0-local}</string>
  <key>CFBundleVersion</key><string>${CORETEND_BUILD:-1}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>fr</string></array>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>ITSAppUsesNonExemptEncryption</key><false/>
  <key>NSHumanReadableCopyright</key><string>© 2026 Ahmet Basbunar · Apache 2.0</string>
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
