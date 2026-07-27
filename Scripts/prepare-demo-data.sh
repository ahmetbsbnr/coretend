#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
set -eu

root="${1:-/tmp/coretend-demo-dataset}"
case "$root" in
  /tmp/coretend-demo-*|/private/tmp/coretend-demo-*) ;;
  *) print -u2 "FAIL: demo dataset must be under the dedicated temporary prefix"; exit 1 ;;
esac

if [[ -e "$root" ]]; then
  print -u2 "FAIL: target already exists; choose a fresh target"
  exit 1
fi

mkdir -p "$root/Demo Workspace/Sample Documents" \
  "$root/Demo Workspace/Example Projects/Build Cache" \
  "$root/Demo Workspace/Photos Demo" \
  "$root/Demo Workspace/Archive"

print 'Synthetic project notes for the CoreTend demonstration.' \
  >"$root/Demo Workspace/Sample Documents/Project Notes.txt"
print 'Synthetic status report. No personal or production data.' \
  >"$root/Demo Workspace/Sample Documents/Status Report.txt"
cp "$root/Demo Workspace/Sample Documents/Project Notes.txt" \
  "$root/Demo Workspace/Sample Documents/Project Notes Copy.txt"

dd if=/dev/zero of="$root/Demo Workspace/Example Projects/Build Cache/build-cache.bin" \
  bs=1024 count=384 status=none
dd if=/dev/zero of="$root/Demo Workspace/Archive/Archive 2025.bin" \
  bs=1024 count=768 status=none

for color in '220 238 228' '224 220 248' '248 231 190'; do
  parts=(${=color})
  name="sample-${parts[1]}-${parts[2]}-${parts[3]}.ppm"
  {
    print 'P3'
    print '64 64'
    print '255'
    yes "${parts[1]} ${parts[2]} ${parts[3]}" | head -n 4096
  } >"$root/Demo Workspace/Photos Demo/$name"
done

find "$root" -type f -exec touch -t 202501151200 {} +
print "PASS: synthetic demo dataset created under the dedicated temporary prefix"
