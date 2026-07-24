#!/bin/zsh
# Creates a small APFS disk image for destructive tests, mounted at /Volumes/CoreTendTest.
# Never touches the real home directory.
set -e
IMG="${TMPDIR:-/tmp}/coretend-test.dmg"
rm -f "$IMG"
hdiutil create -size 64m -fs APFS -volname CoreTendTest "$IMG" -quiet
hdiutil attach "$IMG" -quiet
echo "Mounted /Volumes/CoreTendTest (detach with: hdiutil detach /Volumes/CoreTendTest)"
