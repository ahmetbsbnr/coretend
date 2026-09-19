#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# A richer IntegrityFixtures than seed-apps.sh builds: enough downloads with
# varied provenance, and enough login items including broken ones, that the
# Integrity screen has real findings rather than four tidy rows.
# usage: seed-integrity.sh <store-dir>
set -euo pipefail
store="${1:?usage: $0 <store-dir>}"
ifx="$store/IntegrityFixtures"
mkdir -p "$ifx/Downloads" "$ifx/UserLaunchAgents" "$ifx/GlobalLaunchAgents" "$ifx/GlobalLaunchDaemons"

dl () { # name size-KB agent origin-url
  dd if=/dev/zero of="$ifx/Downloads/$1" bs=1024 count="$2" status=none
  if [[ -n "$3" ]]; then
    xattr -w com.apple.quarantine "0083;$(printf '%x' 1789000000);$3;" "$ifx/Downloads/$1"
  fi
  [[ -n "${4:-}" ]] && xattr -w com.apple.metadata:kMDItemWhereFroms "$4" "$ifx/Downloads/$1" || true
}

# Downloads with a recorded origin: the ordinary case.
dl "Figma-124.6.5.dmg"      3200 Safari    "https://desktop.figma.com/mac-arm/Figma-124.6.5.dmg"
dl "Docker-4.38.0.dmg"      6400 "Google Chrome" "https://desktop.docker.com/mac/main/arm64/Docker.dmg"
dl "invoice-2026-09.pdf"       6 Mail      ""
dl "contract-signed.pdf"      12 Mail      ""
dl "OBS-31.0.dmg"           4800 Firefox   "https://cdn-fastly.obsproject.com/downloads/obs-mac.dmg"
dl "TablePlus.dmg"          1600 Safari    "https://tableplus.com/release/osx/tableplus.dmg"
dl "brew-cask-notes.txt"       1 Terminal  ""
dl "presentation.key"        820 "Messages" ""

# Downloads with NO recorded origin. These are the findings: a file that
# arrived without macOS recording where from is the one thing this screen can
# honestly flag.
for name in "installer-unknown.pkg" "archive-from-usb.zip" "tool-v2.bin" "patch.dmg"; do
  dd if=/dev/zero of="$ifx/Downloads/$name" bs=1024 count=900 status=none
done

agent () { # label program-path dir
  cat > "$ifx/$3/$1.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$1</string>
<key>ProgramArguments</key><array><string>$2</string></array>
<key>RunAtLoad</key><true/>
</dict></plist>
PLIST
}

# Agents whose program still exists (this binary always does).
me="/bin/sleep"
agent "com.docker.helper"        "$me" UserLaunchAgents
agent "com.figma.agent"          "$me" UserLaunchAgents
agent "com.google.keystone"      "$me" GlobalLaunchAgents
agent "com.microsoft.update"     "$me" GlobalLaunchAgents
agent "com.vendor.telemetry"     "$me" GlobalLaunchDaemons

# Agents pointing at a program that is gone. These are real findings: an item
# macOS still tries to launch, for an application that was removed.
agent "com.example.vanished"     "/Applications/Vanished.app/Contents/MacOS/helper" UserLaunchAgents
agent "com.acme.uninstalled"     "/Applications/Acme.app/Contents/MacOS/acmed"      UserLaunchAgents
agent "com.oldvendor.daemon"     "/Library/Application Support/OldVendor/oldvendord" GlobalLaunchDaemons

echo "$ifx"
