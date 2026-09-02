#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Builds the release artifacts and generates their provenance manifest.
#
# The provenance design, and why it is shaped this way:
#
#   Release/latest.template.json is TRACKED and hand-authored. It holds only
#   human decisions — channel, minimum OS, known limitations, URLs.
#
#   dist/latest.json and dist/SHA256SUMS are GENERATED and never committed.
#   They carry the computed facts: checksums, sizes, sourceCommit, releaseTag,
#   build date and a per-invocation ID.
#
# The old design committed latest.json with a `sourceCommit` field, which is
# impossible to keep true: the commit that adds the file cannot be named inside
# it, so the manifest was permanently one commit stale and the release-manifest
# gate could only ever be green on an uncommitted tree. Generating it instead
# means `sourceCommit` names the exact commit the artifacts were built from,
# with nothing to commit afterwards. See Documentation/RELEASE_PROVENANCE.md.
#
# A dirty tree is refused: `sourceCommit` would name a commit whose tree is not
# what was packaged. ALLOW_DIRTY_BUILD=1 overrides this for local iteration and
# stamps treeState:"dirty" into the manifest, so such a build can never be
# mistaken for a releasable one.
#
# Usage: Scripts/build-release.sh [version]
#        ALLOW_DIRTY_BUILD=1 Scripts/build-release.sh [version]   # local only
set -e -o pipefail
cd "$(dirname "$0")/.."

ARTIFACT_VERSION="${1:-$(/usr/bin/python3 -c "import json;print(json.load(open('Configuration/PublicIdentity.example.json'))['marketingVersion'])")}"
BUILD_NUMBER="$(/usr/bin/python3 -c "import json;print(json.load(open('Configuration/PublicIdentity.example.json')).get('buildNumber', ''))")"

# CORETEND_RELEASE_SIGNED=1 packages a real Developer ID signed + notarized +
# stapled release: the `-unsigned` suffix is dropped, `signed`/`notarized` are
# true in the manifest, and the ZIP/DMG are NOT rebuilt — they must already
# exist in Release/, produced by Scripts/sign-and-notarize.sh, so the bytes
# that carry the notarization ticket are the bytes that get checksummed and
# published. Default (unset) is the historical unsigned flow, unchanged.
SIGNED="${CORETEND_RELEASE_SIGNED:-0}"
if [ "$SIGNED" = "1" ]; then
  ZIP_NAME="CoreTend-${ARTIFACT_VERSION}-arm64.zip"
  DMG_NAME="CoreTend-${ARTIFACT_VERSION}-arm64.dmg"
else
  ZIP_NAME="CoreTend-${ARTIFACT_VERSION}-arm64-unsigned.zip"
  DMG_NAME="CoreTend-${ARTIFACT_VERSION}-arm64-unsigned.dmg"
fi
TEMPLATE="Release/latest.template.json"
DIST="dist"

[ -f "$TEMPLATE" ] || { echo "build-release.sh: FAIL — $TEMPLATE is missing"; exit 1; }

# --- Clean-tree gate -------------------------------------------------------
TREE_STATE="clean"
if [ -n "$(git status --short --untracked-files=no)" ]; then
  if [ "${ALLOW_DIRTY_BUILD:-}" = "1" ]; then
    TREE_STATE="dirty"
    echo "build-release.sh: WARNING — building from a DIRTY tree (ALLOW_DIRTY_BUILD=1)."
    echo "  The manifest will record treeState:\"dirty\". This build is not releasable."
    git status --short --untracked-files=no | sed 's/^/    /'
  else
    echo "build-release.sh: FAIL — working tree is not clean."
    echo "  sourceCommit would name a commit whose tree is not what was packaged."
    echo "  Commit or stash first, or set ALLOW_DIRTY_BUILD=1 for a local, non-releasable build."
    git status --short --untracked-files=no | sed 's/^/    /'
    exit 1
  fi
fi

SOURCE_COMMIT=$(git rev-parse HEAD)
# The exact tag at HEAD, if any. A release build is expected to be run on a tag;
# a build without one is legitimate for local verification and says so.
RELEASE_TAG=$(git describe --exact-match --tags HEAD 2>/dev/null || echo "")
BUILD_DATE_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_INVOCATION_ID=$(/usr/bin/uuidgen)

# --- Build ----------------------------------------------------------------
if [ "$SIGNED" = "1" ]; then
  # The signed artifacts are produced (and Apple-notarized) by
  # Scripts/sign-and-notarize.sh. Rebuilding here would strip the signature
  # and the stapled ticket, so this mode only verifies they are present.
  for f in "Release/$ZIP_NAME" "Release/$DMG_NAME"; do
    [ -f "$f" ] || { echo "build-release.sh: FAIL — $f not found. Run Scripts/sign-and-notarize.sh $ARTIFACT_VERSION <profile> first."; exit 1; }
  done
  if ! xcrun stapler validate "Release/$DMG_NAME" >/dev/null 2>&1; then
    echo "build-release.sh: FAIL — Release/$DMG_NAME is not stapled. Re-run sign-and-notarize.sh."
    exit 1
  fi
  echo "build-release.sh: signed mode — using notarized artifacts from Release/ (no rebuild)."
else
  bash Scripts/package-zip.sh "$ARTIFACT_VERSION"
  bash Scripts/package-dmg.sh "$ARTIFACT_VERSION"
fi

mkdir -p "$DIST"

ZIP_SHA=$(shasum -a 256 "Release/$ZIP_NAME" | awk '{print $1}')
DMG_SHA=$(shasum -a 256 "Release/$DMG_NAME" | awk '{print $1}')
ZIP_SIZE=$(stat -f%z "Release/$ZIP_NAME")
DMG_SIZE=$(stat -f%z "Release/$DMG_NAME")

# --- Generate the manifest from the template ------------------------------
/usr/bin/python3 - "$TEMPLATE" "$DIST" "$ARTIFACT_VERSION" "$ZIP_NAME" "$ZIP_SHA" "$ZIP_SIZE" \
  "$DMG_NAME" "$DMG_SHA" "$DMG_SIZE" "$SOURCE_COMMIT" "$RELEASE_TAG" \
  "$BUILD_DATE_UTC" "$BUILD_INVOCATION_ID" "$TREE_STATE" "$BUILD_NUMBER" "$SIGNED" <<'PYEOF'
import json, sys
(tpl_path, dist, version, zip_name, zip_sha, zip_size,
 dmg_name, dmg_sha, dmg_size, source_commit, release_tag,
 build_date, build_id, tree_state, build_number, signed_flag) = sys.argv[1:17]
signed = signed_flag == "1"

with open(tpl_path) as f:
    tpl = json.load(f)

if signed:
    # A signed + notarized release: the manifest states it, and the "Gatekeeper
    # will block" limitation is replaced with the notarized reality. The
    # artifacts themselves were verified (stapler validate) before this point.
    tpl["signed"] = True
    tpl["notarized"] = True
    lims = tpl.get("knownLimitations", [])
    if lims and lims[0].startswith("Unsigned, not notarized"):
        lims[0] = ("Developer ID signed (Team NSCUV5G738) and Apple-notarized; the app "
                   "and DMG are stapled, so Gatekeeper opens them without an override step.")
    tpl["knownLimitations"] = lims
    for k in ("zipNamePattern", "dmgNamePattern"):
        if k in tpl:
            tpl[k] = tpl[k].replace("-arm64-unsigned.", "-arm64.")

# The template documents which fields it must never carry. Enforce it, so a
# hand-edited checksum can never silently win over a computed one.
forbidden = set(tpl.pop("_doNotAddHere", []))
present = forbidden & set(tpl)
if present:
    raise SystemExit(
        f"build-release.sh: FAIL — {tpl_path} contains computed field(s) it must not: "
        f"{sorted(present)}. Remove them; they are generated."
    )
tpl.pop("_comment", None)

patterns = {k: tpl.pop(k) for k in
            ("zipNamePattern", "dmgNamePattern", "releaseNotesPattern") if k in tpl}

manifest = {
    "_comment": ("GENERATED by Scripts/build-release.sh — do not commit and do not hand-edit. "
                 "Hand-authored fields live in Release/latest.template.json. Regenerate with "
                 "Scripts/build-release.sh. See Documentation/RELEASE_PROVENANCE.md."),
    "schemaVersion": 2,
    **tpl,
    "version": version,
    "build": build_number,
    "zipName": zip_name,
    "zipSHA256": zip_sha,
    "zipSize": int(zip_size),
    "dmgName": dmg_name,
    "dmgSHA256": dmg_sha,
    "dmgSize": int(dmg_size),
    "releaseNotes": patterns.get("releaseNotesPattern", "Release/Notes/{version}.en.md")
                            .format(version=version),
    # Provenance. sourceCommit is the commit the artifacts were built from, and
    # because this file is not tracked, that statement stays true forever.
    "sourceCommit": source_commit,
    "releaseTag": release_tag or None,
    "treeState": tree_state,
    "buildDate_UTC": build_date,
    "buildInvocationID": build_id,
    "generatedBy": "Scripts/build-release.sh",
    "releasable": tree_state == "clean",
    "_releasableNote": ("releasable is false when the build came from a dirty tree, "
                        "regardless of whether a tag was present."),
}

# Sanity: the declared artifact names must match the patterns, so a renamed
# artifact cannot be published under a stale name.
for pat_key, actual in (("zipNamePattern", zip_name), ("dmgNamePattern", dmg_name)):
    if pat_key in patterns:
        expected = patterns[pat_key].format(version=version)
        if expected != actual:
            raise SystemExit(f"build-release.sh: FAIL — {pat_key} yields {expected!r}, built {actual!r}")

out = f"{dist}/latest.json"
with open(out, "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
print(f"Generated {out}")
PYEOF

# --- Checksums ------------------------------------------------------------
# Computed over the artifacts and the generated manifest. This file is an
# OUTPUT of the build, never an input to it.
cp "Release/$ZIP_NAME" "Release/$DMG_NAME" "$DIST/" 2>/dev/null || true
(cd "$DIST" && shasum -a 256 "$ZIP_NAME" "$DMG_NAME" latest.json > SHA256SUMS)

# Kept in Release/ too, so existing local tooling and the audit package keep
# finding them at the historical path. Both copies are gitignored.
cp "$DIST/latest.json" Release/latest.json
(cd Release && shasum -a 256 "$ZIP_NAME" "$DMG_NAME" latest.json > SHA256SUMS)

echo
echo "Version:      $ARTIFACT_VERSION"
echo "sourceCommit: $SOURCE_COMMIT"
echo "releaseTag:   ${RELEASE_TAG:-(none — not a tagged build)}"
echo "treeState:    $TREE_STATE"
echo "buildID:      $BUILD_INVOCATION_ID"
echo
cat "$DIST/SHA256SUMS"
