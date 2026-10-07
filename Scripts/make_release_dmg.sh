#!/bin/bash
# Builds the release disk image from a notarized, stapled CoreTend.app.
# The app must already be notarized. The image is signed with the same Developer ID identity,
# then notarized and stapled with a notarytool keychain profile created by the maintainer
# (`xcrun notarytool store-credentials`); the script never sees the credential itself.
set -euo pipefail

usage() {
  printf 'Usage: %s --app CoreTend.app --identity SHA1 --notary-profile NAME --output DIRECTORY\n' "$0" >&2
}

app_arg=""
identity_arg=""
profile_arg=""
output_arg=""
while (($#)); do
  case "$1" in
    --app)
      (($# >= 2)) || { usage; exit 64; }
      app_arg="$2"; shift 2 ;;
    --identity)
      (($# >= 2)) || { usage; exit 64; }
      identity_arg="$2"; shift 2 ;;
    --notary-profile)
      (($# >= 2)) || { usage; exit 64; }
      profile_arg="$2"; shift 2 ;;
    --output)
      (($# >= 2)) || { usage; exit 64; }
      output_arg="$2"; shift 2 ;;
    *) usage; exit 64 ;;
  esac
done
[[ -n "$app_arg" && -n "$identity_arg" && -n "$profile_arg" && -n "$output_arg" ]] || { usage; exit 64; }
[[ -d "$app_arg" && -d "$output_arg" ]] || { printf 'App or output directory missing\n' >&2; exit 66; }

xcrun stapler validate "$app_arg" >/dev/null || { printf 'App is not stapled; notarize it first\n' >&2; exit 65; }
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_arg/Contents/Info.plist")
dmg="$output_arg/CoreTend-$version-universal.dmg"
[[ ! -e "$dmg" ]] || { printf 'Refusing to overwrite %s\n' "$dmg" >&2; exit 73; }

stage=$(mktemp -d "${TMPDIR:-/tmp}/coretend-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app_arg" "$stage/CoreTend.app"
ln -s /Applications "$stage/Applications"

hdiutil create -volname "CoreTend $version" -srcfolder "$stage" -fs APFS -format ULFO -quiet "$dmg"
codesign --sign "$identity_arg" --timestamp "$dmg"
codesign --verify --strict "$dmg"

xcrun notarytool submit "$dmg" --keychain-profile "$profile_arg" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature -vv "$dmg"

# Replace only the image's line, keeping the other release files (the ZIP) listed.
(cd "$output_arg" && name=$(basename "$dmg") && {
  [[ -f SHA256SUMS ]] && grep -v "  $name\$" SHA256SUMS || true
  shasum -a 256 "$name"
} > SHA256SUMS.new && mv SHA256SUMS.new SHA256SUMS)
cat "$output_arg/SHA256SUMS"
