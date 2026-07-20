#!/bin/zsh
# Builds ZIP + DMG and regenerates Release/SHA256SUMS over both plus
# latest.json. Does NOT regenerate latest.json itself (its release notes
# and known-limitations text are hand-authored) — update the SHA256/size
# fields in Release/latest.json by hand after running this if the build
# output changed, then re-run to refresh SHA256SUMS.
set -e
cd "$(dirname "$0")/.."

ARTIFACT_VERSION="${1:-0.7.0}"

bash Scripts/package-zip.sh "$ARTIFACT_VERSION"
bash Scripts/package-dmg.sh "$ARTIFACT_VERSION"

(cd Release && shasum -a 256 \
  "MacCare-Local-${ARTIFACT_VERSION}-arm64-unsigned.zip" \
  "MacCare-Local-${ARTIFACT_VERSION}-arm64-unsigned.dmg" \
  latest.json > SHA256SUMS)

echo "Release/SHA256SUMS:"
cat Release/SHA256SUMS
