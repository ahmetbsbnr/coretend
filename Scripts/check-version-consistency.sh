#!/bin/bash
# Fails if the marketing version diverges between the single source of truth
# (Configuration/PublicIdentity.example.json, or .local.json if present) and
# the places that must mirror it: Info.plist, Documentation/PROJECT_STATE.json,
# Documentation/CHANGELOG.md's latest heading.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="Configuration/PublicIdentity.local.json"
[ -f "$IDENTITY" ] || IDENTITY="Configuration/PublicIdentity.example.json"

json_get() { /usr/bin/python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$1" "$2"; }

VERSION=$(json_get "$IDENTITY" marketingVersion)
BUNDLE_ID=$(json_get "$IDENTITY" bundleId)

fail=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" != "$expected" ]; then
    echo "MISMATCH: $label is '$actual', expected '$expected' (from $IDENTITY)"
    fail=1
  fi
}

PLIST_SHORT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
PLIST_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Info.plist)
PLIST_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Resources/Info.plist)

check "Resources/Info.plist CFBundleShortVersionString" "$PLIST_SHORT" "$VERSION"
check "Resources/Info.plist CFBundleVersion" "$PLIST_BUILD" "$VERSION"
check "Resources/Info.plist CFBundleIdentifier" "$PLIST_ID" "$BUNDLE_ID"

STATE_VERSION=$(/usr/bin/python3 -c "import json; print(json.load(open('Documentation/PROJECT_STATE.json'))['version'])")
check "Documentation/PROJECT_STATE.json version" "$STATE_VERSION" "$VERSION"

if [ "$fail" -ne 0 ]; then
  echo "check-version-consistency.sh: FAILED"
  exit 1
fi
echo "check-version-consistency.sh: OK (version $VERSION consistent)"
