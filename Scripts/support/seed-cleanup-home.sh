#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Builds a stand-in home directory with the kinds of files Cleanup's rules
# find, so the review screen can be captured on controlled data instead of
# whatever this machine's caches hold. Files carry real bytes — a sparse file
# reports its allocated size to the Explore scan, which turned a 2 GB fixture
# into 16 MB of map — so sizes are kept modest (units of 100 KB). Dates are
# old enough to match the "older than N days" rules.
#
# usage: seed-cleanup-home.sh <home-dir>
set -euo pipefail
home="${1:?usage: $0 <home-dir>}"
mkdir -p "$home"
mk () { # path size-in-100KB-units days-old
  mkdir -p "$(dirname "$home/$1")"
  dd if=/dev/zero of="$home/$1" bs=102400 count="$2" status=none
  touch -t "$(date -v-"$3"d +%Y%m%d%H%M)" "$home/$1"
}
mk "Library/Caches/com.apple.Safari/WebKitCache/Version 17/Blobs/3f9c" 212 40
mk "Library/Caches/com.figma.Desktop/Cache/data_3" 96 12
mk "Library/Caches/Google/Chrome/Default/Cache/f_000a1c" 380 9
mk "Library/Caches/com.spotify.client/Storage/segment-00017" 1024 60
mk "Library/Caches/pip/http/2/c/3f/2c3f9e" 14 200
mk "Library/Logs/DiagnosticReports/Xcode-2026-07-02-101512.ips" 2 78
mk "Library/Logs/CoreSimulator/Simulator Device.log" 41 30
mk "Library/Developer/Xcode/DerivedData/CoreTend-abcdef/Build/Intermediates.noindex/x.o" 640 21
mk "Library/Developer/Xcode/iOS DeviceSupport/17.4 (21E219)/Symbols/usr/lib/dyld" 2200 300
mk "Downloads/Firefox 128.0.dmg" 130 45
mk "Downloads/A very long archive name that a person actually gave their download because they were in a hurry.zip" 590 90
mk "Downloads/report.pdf.download/report.pdf" 3 15
echo "$home"
