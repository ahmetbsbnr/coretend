#!/bin/sh
# Meaningful checks on the release manifest/checksums/docs that
# test-distribution.sh (bundle structure/arch/launch) doesn't cover:
# checksum correctness, latest.json <-> SHA256SUMS consistency,
# unsigned/notarized declared consistently, and no dangerous
# Gatekeeper-bypass commands anywhere in shipped docs.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
ok()  { echo "OK: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

json_get() { /usr/bin/python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ''))" "$1" "$2"; }

if [ ! -f Release/latest.json ] || [ ! -f Release/SHA256SUMS ]; then
  echo "SKIP: no Release/latest.json or SHA256SUMS present yet (build artifacts not generated in this environment run)."
  exit 0
fi

echo "== SHA256SUMS entries actually match the files on disk =="
( cd Release && shasum -a 256 -c SHA256SUMS >/tmp/shasums-check.out 2>&1 ) \
  && ok "SHA256SUMS verifies against files on disk" \
  || { bad "SHA256SUMS does not verify — see /tmp/shasums-check.out"; cat /tmp/shasums-check.out; }

echo "== latest.json zipSHA256/dmgSHA256 match SHA256SUMS =="
ZIP_NAME=$(json_get Release/latest.json zipName)
DMG_NAME=$(json_get Release/latest.json dmgName)
ZIP_SHA_MANIFEST=$(json_get Release/latest.json zipSHA256)
DMG_SHA_MANIFEST=$(json_get Release/latest.json dmgSHA256)
ZIP_SHA_SUMS=$(awk -v f="$ZIP_NAME" '$2==f{print $1}' Release/SHA256SUMS)
DMG_SHA_SUMS=$(awk -v f="$DMG_NAME" '$2==f{print $1}' Release/SHA256SUMS)

[ "$ZIP_SHA_MANIFEST" = "$ZIP_SHA_SUMS" ] \
  && ok "zipSHA256 in latest.json matches SHA256SUMS ($ZIP_SHA_MANIFEST)" \
  || bad "zipSHA256 mismatch: latest.json=$ZIP_SHA_MANIFEST SHA256SUMS=$ZIP_SHA_SUMS"
[ "$DMG_SHA_MANIFEST" = "$DMG_SHA_SUMS" ] \
  && ok "dmgSHA256 in latest.json matches SHA256SUMS ($DMG_SHA_MANIFEST)" \
  || bad "dmgSHA256 mismatch: latest.json=$DMG_SHA_MANIFEST SHA256SUMS=$DMG_SHA_SUMS"

echo "== latest.json zipSize/dmgSize match actual file sizes =="
ZIP_SIZE_MANIFEST=$(json_get Release/latest.json zipSize)
DMG_SIZE_MANIFEST=$(json_get Release/latest.json dmgSize)
[ -f "Release/$ZIP_NAME" ] && ZIP_SIZE_ACTUAL=$(stat -f%z "Release/$ZIP_NAME") || ZIP_SIZE_ACTUAL="missing"
[ -f "Release/$DMG_NAME" ] && DMG_SIZE_ACTUAL=$(stat -f%z "Release/$DMG_NAME") || DMG_SIZE_ACTUAL="missing"
[ "$ZIP_SIZE_MANIFEST" = "$ZIP_SIZE_ACTUAL" ] \
  && ok "zipSize matches actual file size" \
  || bad "zipSize mismatch: manifest=$ZIP_SIZE_MANIFEST actual=$ZIP_SIZE_ACTUAL"
[ "$DMG_SIZE_MANIFEST" = "$DMG_SIZE_ACTUAL" ] \
  && ok "dmgSize matches actual file size" \
  || bad "dmgSize mismatch: manifest=$DMG_SIZE_MANIFEST actual=$DMG_SIZE_ACTUAL"

echo "== unsigned/non-notarized declared consistently =="
SIGNED=$(json_get Release/latest.json signed)
NOTARIZED=$(json_get Release/latest.json notarized)
[ "$SIGNED" = "False" ] && ok "latest.json signed:false" || bad "latest.json signed is not false ($SIGNED) — app is genuinely unsigned, manifest must say so"
[ "$NOTARIZED" = "False" ] && ok "latest.json notarized:false" || bad "latest.json notarized is not false ($NOTARIZED)"
if grep -qi "without.*apple notarization\|without.*signature\|unsigned\|not notarized\|non-notarized" Documentation/INSTALL_UNSIGNED.md 2>/dev/null; then
  ok "INSTALL_UNSIGNED.md states unsigned/non-notarized status"
else
  bad "INSTALL_UNSIGNED.md does not clearly state unsigned/non-notarized status"
fi

echo "== no dangerous Gatekeeper-bypass commands documented as steps to follow =="
# A dangerous command mentioned purely to warn against it (preceded within
# 5 lines by "never"/"do not"/"NOT to do") is fine and expected — INSTALL_UNSIGNED.md
# does exactly that. Only flag it if presented with no such warning nearby.
DANGEROUS='sudo spctl --master-disable|csrutil disable|xattr -cr /|xattr -r -d com.apple.quarantine /$'
set +e
python3 - "$DANGEROUS" <<'PYEOF'
import re, subprocess, sys, glob
pattern = re.compile(sys.argv[1] if len(sys.argv) > 1 else "", re.IGNORECASE)
warn = re.compile(r'never|do not|not to do|don\'t', re.IGNORECASE)
files = glob.glob("Documentation/*.md") + glob.glob("Release/Notes/*.md")
found_unwarned = False
for path in files:
    lines = open(path, encoding="utf-8", errors="ignore").read().splitlines()
    for i, line in enumerate(lines):
        if pattern.search(line):
            # Window includes the current line, not just the preceding
            # ones — a warning quoted inline on the same line ("...with
            # its 'Do not...' warning...") is exactly as valid a warning
            # as one on a prior line. A look-behind-only window falsely
            # flagged prose that discusses this very heuristic's history
            # (see REQUIREMENTS_TRACEABILITY_MATRIX.md's session-1 note).
            window = lines[max(0, i - 5):i + 1]
            if not any(warn.search(w) for w in window):
                print(f"UNWARNED: {path}:{i+1}: {line.strip()}")
                found_unwarned = True
sys.exit(1 if found_unwarned else 0)
PYEOF
PY_STATUS=$?
set -e
if [ "$PY_STATUS" -eq 0 ]; then
  ok "no unwarned dangerous Gatekeeper/SIP-bypass commands in Documentation/ or Release/Notes/"
else
  bad "found a dangerous command presented without a 'never/do not' warning nearby (see UNWARNED lines above)"
fi

echo "== the manifest is generated, not tracked =="
# This is the structural fix for DIST-003/RESYNC-003. A tracked manifest would
# have to contain the SHA of the commit that adds it, which is impossible, so the
# old committed latest.json was permanently one commit stale and this gate could
# only be green on an uncommitted tree. The manifest is now generated output.
if git ls-files --error-unmatch Release/latest.json >/dev/null 2>&1; then
  bad "Release/latest.json is tracked by git — it must be generated output, never committed (see Documentation/RELEASE_PROVENANCE.md)"
else
  ok "Release/latest.json is not tracked (generated by Scripts/build-release.sh)"
fi
if git ls-files --error-unmatch Release/SHA256SUMS >/dev/null 2>&1; then
  bad "Release/SHA256SUMS is tracked by git — it must be generated output"
else
  ok "Release/SHA256SUMS is not tracked (generated by Scripts/build-release.sh)"
fi
if git ls-files --error-unmatch Release/latest.template.json >/dev/null 2>&1; then
  ok "Release/latest.template.json is tracked (the hand-authored source)"
else
  bad "Release/latest.template.json must be tracked — it holds the human-authored fields"
fi

echo "== the template carries no computed field =="
# A hand-edited checksum in the template must never be able to win over a
# computed one, so the template is required to declare and honour the exclusion.
TEMPLATE_VIOLATIONS=$(/usr/bin/python3 - <<'PY'
import json
t = json.load(open("Release/latest.template.json"))
forbidden = set(t.get("_doNotAddHere", []))
if not forbidden:
    print("template does not declare _doNotAddHere")
else:
    bad = sorted(forbidden & set(t))
    if bad:
        print("template contains computed fields: " + ", ".join(bad))
PY
)
[ -z "$TEMPLATE_VIOLATIONS" ] \
  && ok "template holds only hand-authored fields" \
  || bad "$TEMPLATE_VIOLATIONS"

echo "== resolved release limitations cannot return to the template =="
STALE_LIMITATIONS=$(/usr/bin/python3 - <<'PY'
import json
limitations = "\n".join(json.load(open("Release/latest.template.json")).get("knownLimitations", []))
for stale in (
    "no saved icon positions",
    "full visual-QA capture campaign could not be run",
    "Living System background",
):
    if stale.casefold() in limitations.casefold():
        print(stale)
PY
)
[ -z "$STALE_LIMITATIONS" ] \
  && ok "template does not re-open resolved rc.4 packaging or visual gaps" \
  || bad "template still claims resolved limitation(s): $STALE_LIMITATIONS"

echo "== generated manifest records real provenance =="
MANIFEST_SOURCE_COMMIT=$(json_get Release/latest.json sourceCommit)
MANIFEST_TREE_STATE=$(json_get Release/latest.json treeState)
MANIFEST_TAG=$(json_get Release/latest.json releaseTag)
MANIFEST_RELEASABLE=$(json_get Release/latest.json releasable)
MANIFEST_BUILD_ID=$(json_get Release/latest.json buildInvocationID)
MANIFEST_BUILD_DATE=$(json_get Release/latest.json buildDate_UTC)

# sourceCommit must name a commit that really exists in this repository. It is
# NOT required to equal current HEAD: commits made after a build do not
# retroactively change what was built, and demanding equality is precisely the
# circularity that was removed.
if [ -z "$MANIFEST_SOURCE_COMMIT" ]; then
  bad "manifest has no sourceCommit"
elif git cat-file -e "${MANIFEST_SOURCE_COMMIT}^{commit}" 2>/dev/null; then
  ok "sourceCommit ($MANIFEST_SOURCE_COMMIT) is a real commit in this repository"
  if [ "$MANIFEST_SOURCE_COMMIT" = "$(git rev-parse HEAD)" ]; then
    echo "  (it also happens to be current HEAD)"
  else
    echo "  (HEAD has moved since the build — expected, and not a failure)"
  fi
else
  bad "sourceCommit ($MANIFEST_SOURCE_COMMIT) is not a commit in this repository"
fi

[ -n "$MANIFEST_BUILD_ID" ] && ok "buildInvocationID recorded" || bad "manifest has no buildInvocationID"
[ -n "$MANIFEST_BUILD_DATE" ] && ok "buildDate_UTC recorded ($MANIFEST_BUILD_DATE)" || bad "manifest has no buildDate_UTC"

case "$MANIFEST_TREE_STATE" in
  clean) ok "treeState=clean — built from a committed tree" ;;
  dirty) echo "NOTE: treeState=dirty — a local, deliberately non-releasable build (ALLOW_DIRTY_BUILD=1)."
         [ "$MANIFEST_RELEASABLE" = "False" ] \
           && ok "releasable=false, consistent with the dirty tree" \
           || bad "treeState=dirty but releasable is not false" ;;
  *)     bad "manifest has no valid treeState (got '$MANIFEST_TREE_STATE')" ;;
esac

if [ -n "$MANIFEST_TAG" ] && [ "$MANIFEST_TAG" != "None" ]; then
  if git rev-parse -q --verify "refs/tags/$MANIFEST_TAG" >/dev/null; then
    TAG_COMMIT=$(git rev-parse "refs/tags/$MANIFEST_TAG^{commit}")
    [ "$TAG_COMMIT" = "$MANIFEST_SOURCE_COMMIT" ] \
      && ok "releaseTag $MANIFEST_TAG points at sourceCommit" \
      || bad "releaseTag $MANIFEST_TAG points at $TAG_COMMIT, not sourceCommit $MANIFEST_SOURCE_COMMIT"
  else
    bad "manifest names releaseTag $MANIFEST_TAG, which does not exist"
  fi
else
  echo "NOTE: no releaseTag — untagged build. Expected for local verification; a real release is built on a tag."
fi

echo "== build-release.sh refuses a dirty tree =="
# Verified by inspection rather than by dirtying the tree: this gate must not
# mutate the repository it is auditing, and must not rebuild the artifacts as a
# side effect the way the old rebuild-resync check did.
if grep -q 'working tree is not clean' Scripts/build-release.sh \
   && grep -q 'ALLOW_DIRTY_BUILD' Scripts/build-release.sh; then
  ok "build-release.sh gates on a clean tree, with a documented local override"
else
  bad "build-release.sh must refuse to build from a dirty tree"
fi

echo "== summary =="
[ "$fail" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "ONE OR MORE CHECKS FAILED"
exit $fail
