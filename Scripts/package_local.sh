#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
# Xcode's Swift, not another toolchain earlier in PATH: the app needs the SDK's SwiftUI overlays.
# CORETEND_UNIVERSAL=1 (the public build) builds for Apple silicon and Intel in one binary.
build=(xcrun swift build -c release)
if [[ "${CORETEND_UNIVERSAL:-0}" == "1" ]]; then
  build+=(--arch arm64 --arch x86_64)
fi
for product in CoreTendApp CoreTendCLI CoreTendWidget CoreTendFinder CoreTendHelper; do
  "${build[@]}" --product "$product"
done
bin_dir="$("${build[@]}" --show-bin-path)"
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
# The command-line tool travels inside the app (Homebrew links it as `coretend`).
mkdir -p "$app_path/Contents/Helpers"
cp "$bin_dir/CoreTendCLI" "$app_path/Contents/Helpers/coretend"
# The widget and the Finder menu, as app extensions.
version="${CORETEND_VERSION:-0.1.0-local}"
build_number="${CORETEND_BUILD:-1}"
bundle_id="${CORETEND_BUNDLE_ID:-local.coretend.reconstruction}"
extension() { # extension NAME SUFFIX POINT [PRINCIPAL_CLASS]
  local appex="$app_path/Contents/PlugIns/$1.appex"
  mkdir -p "$appex/Contents/MacOS"
  cp "$bin_dir/$1" "$appex/Contents/MacOS/$1"
  local principal=""
  [[ -n "${4:-}" ]] && principal="<key>NSExtensionPrincipalClass</key><string>$4</string>"
  cat > "$appex/Contents/Info.plist" <<EXT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$1</string>
  <key>CFBundleIdentifier</key><string>$bundle_id.$2</string>
  <key>CFBundleName</key><string>CoreTend</string>
  <key>CFBundleDisplayName</key><string>CoreTend</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$build_number</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSExtension</key><dict><key>NSExtensionPointIdentifier</key><string>$3</string>$principal<key>NSExtensionAttributes</key><dict/></dict>
</dict>
</plist>
EXT
  plutil -lint "$appex/Contents/Info.plist" >/dev/null
}
extension CoreTendWidget widget com.apple.widgetkit-extension
extension CoreTendFinder finder com.apple.FinderSync CoreTendFinderSync
# The optional system helper (decision 0006) ships only in the public build, which is signed:
# launchd will not run an unsigned daemon.
if [[ "${CORETEND_SPARKLE:-0}" == "1" ]]; then
  cp "$bin_dir/CoreTendHelper" "$app_path/Contents/Helpers/CoreTendHelper"
  mkdir -p "$app_path/Contents/Library/LaunchDaemons"
  cat > "$app_path/Contents/Library/LaunchDaemons/$bundle_id.helper.plist" <<DAEMON
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$bundle_id.helper</string>
  <key>BundleProgram</key><string>Contents/Helpers/CoreTendHelper</string>
  <key>MachServices</key><dict><key>$bundle_id.helper</key><true/></dict>
  <key>AssociatedBundleIdentifiers</key><array><string>$bundle_id</string></array>
</dict>
</plist>
DAEMON
  plutil -lint "$app_path/Contents/Library/LaunchDaemons/$bundle_id.helper.plist" >/dev/null
fi
# Sparkle (updates), with its symbolic links intact.
mkdir -p "$app_path/Contents/Frameworks"
ditto "$bin_dir/Sparkle.framework" "$app_path/Contents/Frameworks/Sparkle.framework"
# The public build carries the update feed and the key its updates are signed with; local builds
# carry neither, so they never look for updates.
sparkle_keys=""
if [[ "${CORETEND_SPARKLE:-0}" == "1" ]]; then
  sparkle_keys="  <key>SUFeedURL</key><string>https://coretend.ahmetbsbnr.com/appcast.xml</string>
  <key>SUPublicEDKey</key><string>3I19rw1r6HdAyCavOs+20JXcFhi8hsUJxRphteOnEOE=</string>"
fi
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
# Shortcuts and Siri: Xcode's App Intents metadata, extracted from the compiler's constant values
# (SwiftPM does not run the extractor), and the French titles and phrases. Older SwiftPM build
# engines emit no constant values; only the public build requires them.
intents_list="$stage_dir/intents-sources.txt"
consts_list="$stage_dir/intents-consts.txt"
ls "$repo_root"/Sources/CoreTendApp/*.swift > "$intents_list"
find "$repo_root/.build" -path '*CoreTendApp*' -path '*/Release/*' -path '*arm64*' -name '*.swiftconstvalues' > "$consts_list" 2>/dev/null || true
if [[ -s "$consts_list" ]]; then
  swift_bin="$(xcrun --find swift)"
  xcrun appintentsmetadataprocessor --output "$app_path/Contents/Resources" \
    --toolchain-dir "${swift_bin%/usr/bin/swift}" --module-name CoreTendApp --sdk-root "$(xcrun --show-sdk-path)" \
    --xcode-version "$(xcodebuild -version | awk '/Build version/ {print $3}')" --platform-family macOS \
    --deployment-target 14.0 --target-triple arm64-apple-macos14.0 --source-file-list "$intents_list" \
    --swift-const-vals-list "$consts_list" --binary-file "$bin_dir/CoreTendApp" --force >/dev/null 2>&1 || true
fi
if [[ ! -f "$app_path/Contents/Resources/Metadata.appintents/extract.actionsdata" ]]; then
  if [[ "${CORETEND_SPARKLE:-0}" == "1" ]]; then
    printf 'App Intents metadata missing from the public build.\n' >&2
    exit 1
  fi
  printf 'Note: no App Intents metadata in this local build (Shortcuts actions absent).\n' >&2
fi
ditto "$repo_root/Resources/Intents" "$app_path/Contents/Resources"
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
  <!-- coretend://open/<space> and coretend://scan?path=… (widget, Finder menu). -->
  <key>CFBundleURLTypes</key><array><dict>
    <key>CFBundleURLName</key><string>${CORETEND_BUNDLE_ID:-local.coretend.reconstruction}</string>
    <key>CFBundleURLSchemes</key><array><string>coretend</string></array>
  </dict></array>
  <!-- A folder dropped on the Dock icon opens its map. -->
  <key>CFBundleDocumentTypes</key><array><dict>
    <key>CFBundleTypeName</key><string>Folder</string>
    <key>CFBundleTypeRole</key><string>Viewer</string>
    <key>LSHandlerRank</key><string>None</string>
    <key>LSItemContentTypes</key><array><string>public.folder</string></array>
  </dict></array>
${sparkle_keys}
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
