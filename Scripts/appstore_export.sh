#!/bin/bash
# Mac App Store build: packages the sandboxed app, places it in an Xcode archive, then exports it
# with Xcode's managed signing (Apple Distribution identity, Mac App Store profile, installer
# identity — created on demand by -allowProvisioningUpdates with the account signed in to Xcode).
#
#   bash Scripts/appstore_export.sh export   # signed .pkg in Artifacts/AppStore, nothing sent
#   bash Scripts/appstore_export.sh upload   # sends the build to App Store Connect (TestFlight)
#
# The upload needs the app record in App Store Connect (bundle ID com.ahmetbsbnr.coretend).
set -euo pipefail

mode="${1:-export}"
[[ "$mode" == "export" || "$mode" == "upload" ]] || { printf 'Usage: %s export|upload\n' "$0" >&2; exit 64; }
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

build="${CORETEND_BUILD:-201}"
version="2.0.0"
team="NSCUV5G738"
CORETEND_BUILD="$build" make package-appstore >/dev/null

archive="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/CoreTend $version ($build) App Store.xcarchive"
[[ ! -e "$archive" ]] || { printf 'Archive already exists: %s\n' "$archive" >&2; exit 73; }
mkdir -p "$archive/Products/Applications"
ditto Artifacts/CoreTend.app "$archive/Products/Applications/CoreTend.app"
cat > "$archive/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>ApplicationProperties</key><dict>
<key>ApplicationPath</key><string>Applications/CoreTend.app</string>
<key>CFBundleIdentifier</key><string>com.ahmetbsbnr.coretend</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$build</string>
<key>Team</key><string>$team</string>
</dict>
<key>ArchiveVersion</key><integer>2</integer>
<key>CreationDate</key><date>$(date -u +%Y-%m-%dT%H:%M:%SZ)</date>
<key>Name</key><string>CoreTend</string>
<key>SchemeName</key><string>CoreTend</string>
</dict></plist>
PLIST

options="$(mktemp -d)/export-options.plist"
destination=$([[ "$mode" == "upload" ]] && echo upload || echo export)
cat > "$options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>$destination</string>
<key>teamID</key><string>$team</string>
<key>signingStyle</key><string>automatic</string>
<key>manageAppVersionAndBuildNumber</key><false/>
<key>uploadSymbols</key><false/>
</dict></plist>
PLIST

out="$repo_root/Artifacts/AppStore/$build"
mkdir -p "$out"
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$options" -exportPath "$out" -allowProvisioningUpdates
printf 'Archive: %s\nOutput: %s\n' "$archive" "$out"
