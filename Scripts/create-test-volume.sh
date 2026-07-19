#!/bin/zsh
# Creates a small APFS disk image for destructive tests, mounted at /Volumes/MacCareTest.
# Never touches the real home directory.
set -e
IMG="${TMPDIR:-/tmp}/maccare-test.dmg"
rm -f "$IMG"
hdiutil create -size 64m -fs APFS -volname MacCareTest "$IMG" -quiet
hdiutil attach "$IMG" -quiet
echo "Mounted /Volumes/MacCareTest (detach with: hdiutil detach /Volumes/MacCareTest)"
