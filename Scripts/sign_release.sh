#!/bin/bash
# Signs a packaged CoreTend.app with a Developer ID for notarization: Sparkle's helpers first
# (innermost out, as Sparkle documents), then the command-line tool, the system helper and the
# extensions, then the app, all with the hardened runtime and a secure timestamp. Never --deep.
set -euo pipefail
app="${1:?usage: sign_release.sh CoreTend.app IDENTITY}"
identity="${2:?usage: sign_release.sh CoreTend.app IDENTITY}"
sign() { codesign --force --options runtime --timestamp --sign "$identity" "$@"; }
sparkle="$app/Contents/Frameworks/Sparkle.framework"
sign "$sparkle/Versions/B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$sparkle/Versions/B/XPCServices/Downloader.xpc"
sign "$sparkle/Versions/B/Autoupdate"
sign "$sparkle/Versions/B/Updater.app"
sign "$sparkle"
sign "$app/Contents/Helpers/coretend"
entitlements="$(cd "$(dirname "$0")/.." && pwd)/Resources/Entitlements"
# The system helper: its identifier is what CoreTend requires of the other end of the XPC link.
if [[ -f "$app/Contents/Helpers/CoreTendHelper" ]]; then
  sign --identifier com.ahmetbsbnr.coretend.helper "$app/Contents/Helpers/CoreTendHelper"
fi
# The extensions are sandboxed, as macOS requires of widgets and Finder Sync extensions.
sign --entitlements "$entitlements/CoreTendWidget.entitlements" "$app/Contents/PlugIns/CoreTendWidget.appex"
sign --entitlements "$entitlements/CoreTendFinder.entitlements" "$app/Contents/PlugIns/CoreTendFinder.appex"
sign --entitlements "$entitlements/CoreTend.entitlements" "$app"
codesign --verify --strict --deep --verbose=2 "$app"
