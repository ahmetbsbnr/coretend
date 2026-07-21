#!/bin/zsh
# Builds ZIP + DMG, patches Release/latest.json's zipSHA256/zipSize/
# dmgSHA256/dmgSize/sourceCommit to match the artifacts just built (release
# notes and known-limitations text stay hand-authored), then regenerates
# Release/SHA256SUMS over both artifacts plus the now-patched latest.json.
# sourceCommit is always `git rev-parse HEAD` at build time — never hand-edit
# it (see Scripts/test-release-manifest.sh's sourceCommit-matches-HEAD check).
# This order matters: neither the DMG nor ZIP build is byte-reproducible
# run to run (embedded timestamps), so latest.json MUST be resynced from
# the actual artifacts on every run — never hand-edited separately, or it
# drifts (see Scripts/test-release-manifest.sh + AUDIT_COMMANDS.log).
set -e
cd "$(dirname "$0")/.."

ARTIFACT_VERSION="${1:-0.7.0}"
ZIP_NAME="MacCare-Local-${ARTIFACT_VERSION}-arm64-unsigned.zip"
DMG_NAME="MacCare-Local-${ARTIFACT_VERSION}-arm64-unsigned.dmg"

bash Scripts/package-zip.sh "$ARTIFACT_VERSION"
bash Scripts/package-dmg.sh "$ARTIFACT_VERSION"

ZIP_SHA=$(shasum -a 256 "Release/$ZIP_NAME" | awk '{print $1}')
DMG_SHA=$(shasum -a 256 "Release/$DMG_NAME" | awk '{print $1}')
ZIP_SIZE=$(stat -f%z "Release/$ZIP_NAME")
DMG_SIZE=$(stat -f%z "Release/$DMG_NAME")
SOURCE_COMMIT=$(git rev-parse HEAD)

/usr/bin/python3 - "$ZIP_SHA" "$ZIP_SIZE" "$DMG_SHA" "$DMG_SIZE" "$SOURCE_COMMIT" <<'PYEOF'
import json, sys
zip_sha, zip_size, dmg_sha, dmg_size, source_commit = sys.argv[1:6]
path = "Release/latest.json"
with open(path) as f:
    data = json.load(f)
data["zipSHA256"] = zip_sha
data["zipSize"] = int(zip_size)
data["dmgSHA256"] = dmg_sha
data["dmgSize"] = int(dmg_size)
data["sourceCommit"] = source_commit
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

(cd Release && shasum -a 256 \
  "$ZIP_NAME" \
  "$DMG_NAME" \
  latest.json > SHA256SUMS)

echo "Release/latest.json resynced. Release/SHA256SUMS:"
cat Release/SHA256SUMS
