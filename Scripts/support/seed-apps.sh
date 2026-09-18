#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Builds the application fixtures the Applications module reads in test mode:
# <store>/ApplicationFixtures/{Applications,Home,SystemLibrary,Caskroom}.
# Bundles are real enough for the inventory (Info.plist, an executable of a
# given size); associated data lives under Home/Library so the inspector has
# something to list. usage: seed-apps.sh <store-dir>
set -euo pipefail
store="${1:?usage: $0 <store-dir>}"
fx="$store/ApplicationFixtures"
mkdir -p "$fx/Applications" "$fx/Home/Applications" "$fx/Home/Library/Application Support" \
         "$fx/Home/Library/Caches" "$fx/Home/Library/Preferences" "$fx/SystemLibrary" "$fx/Caskroom"
app () { # name bundle-id version size-in-100KB support-size cache-size
  local dir="$fx/Applications/$1.app/Contents"
  mkdir -p "$dir/MacOS" "$dir/Resources"
  cat > "$dir/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$1</string>
<key>CFBundleIdentifier</key><string>$2</string>
<key>CFBundleShortVersionString</key><string>$3</string>
<key>CFBundleExecutable</key><string>$1</string>
</dict></plist>
PLIST
  dd if=/dev/zero of="$dir/MacOS/$1" bs=102400 count="$4" status=none
  chmod +x "$dir/MacOS/$1"
  if [[ "$5" -gt 0 ]]; then mkdir -p "$fx/Home/Library/Application Support/$1"; dd if=/dev/zero of="$fx/Home/Library/Application Support/$1/data.db" bs=102400 count="$5" status=none; fi
  if [[ "$6" -gt 0 ]]; then mkdir -p "$fx/Home/Library/Caches/$2"; dd if=/dev/zero of="$fx/Home/Library/Caches/$2/Cache.db" bs=102400 count="$6" status=none; fi
  : > "$fx/Home/Library/Preferences/$2.plist"
}
app "Figma"            com.figma.Desktop      "124.6.5"  1200 412 96
app "Slack"            com.tinyspeck.slackmacgap "4.41.97" 980 88 210
app "Blender"          org.blenderfoundation.blender "4.2.1" 3300 12 0
app "Zoom"             us.zoom.xos            "6.2.0"    640 40 30
app "Pixelmator Pro"   com.pixelmatorteam.pixelmator.x "3.6.4" 720 4 0
app "A Very Long Application Name That Someone Shipped" com.example.longname "1.0" 20 0 0
echo "$fx"
