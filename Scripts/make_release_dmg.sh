#!/bin/bash
# Builds the release disk image from a notarized, stapled CoreTend.app.
# The app must already be notarized (Gatekeeper evaluates the stapled app inside the image);
# the image itself is signed with the same Developer ID identity.
set -euo pipefail

usage() {
  printf 'Usage: %s --app CoreTend.app --identity SHA1 --output DIRECTORY\n' "$0" >&2
}

app_arg=""
identity_arg=""
output_arg=""
while (($#)); do
  case "$1" in
    --app)
      (($# >= 2)) || { usage; exit 64; }
      app_arg="$2"; shift 2 ;;
    --identity)
      (($# >= 2)) || { usage; exit 64; }
      identity_arg="$2"; shift 2 ;;
    --output)
      (($# >= 2)) || { usage; exit 64; }
      output_arg="$2"; shift 2 ;;
    *) usage; exit 64 ;;
  esac
done
[[ -n "$app_arg" && -n "$identity_arg" && -n "$output_arg" ]] || { usage; exit 64; }
[[ -d "$app_arg" && -d "$output_arg" ]] || { printf 'App or output directory missing\n' >&2; exit 66; }

xcrun stapler validate "$app_arg" >/dev/null || { printf 'App is not stapled; notarize it first\n' >&2; exit 65; }
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_arg/Contents/Info.plist")
dmg="$output_arg/CoreTend-$version-arm64.dmg"
[[ ! -e "$dmg" ]] || { printf 'Refusing to overwrite %s\n' "$dmg" >&2; exit 73; }

stage=$(mktemp -d "${TMPDIR:-/tmp}/coretend-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app_arg" "$stage/CoreTend.app"
ln -s /Applications "$stage/Applications"

hdiutil create -volname "CoreTend $version" -srcfolder "$stage" -fs APFS -format ULFO -quiet "$dmg"
codesign --sign "$identity_arg" --timestamp "$dmg"
codesign --verify --strict "$dmg"

(cd "$output_arg" && shasum -a 256 "$(basename "$dmg")" > SHA256SUMS)
cat "$output_arg/SHA256SUMS"
