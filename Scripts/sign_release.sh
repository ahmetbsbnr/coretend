#!/bin/bash
# Signs a packaged CoreTend.app with a Developer ID for notarization: Sparkle's helpers first
# (innermost out, as Sparkle documents), then the command-line tool, then the app, all with the
# hardened runtime and a secure timestamp. Never --deep.
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
sign "$app"
codesign --verify --strict --deep --verbose=2 "$app"
