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

echo "== build-release.sh resyncs latest.json after a rebuild (regression: DMG/ZIP output is not byte-reproducible run to run, so a rebuild without resync silently desyncs the manifest — see AUDIT_COMMANDS.log session 1) =="
if [ "${SKIP_REBUILD_CHECK:-}" = "1" ]; then
  echo "SKIP: rebuild check disabled via SKIP_REBUILD_CHECK=1"
else
  BEFORE_ZIP_SHA=$(json_get Release/latest.json zipSHA256)
  BEFORE_DMG_SHA=$(json_get Release/latest.json dmgSHA256)
  bash Scripts/build-release.sh "$(json_get Release/latest.json version)" >/tmp/build-release-rebuild.out 2>&1
  AFTER_ZIP_ACTUAL=$(shasum -a 256 "Release/$(json_get Release/latest.json zipName)" | awk '{print $1}')
  AFTER_DMG_ACTUAL=$(shasum -a 256 "Release/$(json_get Release/latest.json dmgName)" | awk '{print $1}')
  MANIFEST_ZIP_SHA=$(json_get Release/latest.json zipSHA256)
  MANIFEST_DMG_SHA=$(json_get Release/latest.json dmgSHA256)
  [ "$MANIFEST_ZIP_SHA" = "$AFTER_ZIP_ACTUAL" ] && [ "$MANIFEST_DMG_SHA" = "$AFTER_DMG_ACTUAL" ] \
    && ok "latest.json auto-resynced to the freshly rebuilt artifacts (proves the fix, not just today's snapshot)" \
    || bad "latest.json did NOT resync after rebuild — see /tmp/build-release-rebuild.out"
fi

echo "== latest.json sourceCommit matches real git HEAD (never hand-edited) =="
REAL_HEAD=$(git rev-parse HEAD)
MANIFEST_SOURCE_COMMIT=$(json_get Release/latest.json sourceCommit)
[ "$MANIFEST_SOURCE_COMMIT" = "$REAL_HEAD" ] \
  && ok "sourceCommit ($MANIFEST_SOURCE_COMMIT) equals git rev-parse HEAD" \
  || bad "sourceCommit mismatch: manifest=$MANIFEST_SOURCE_COMMIT real HEAD=$REAL_HEAD (build-release.sh must set this automatically, never by hand)"

echo "== summary =="
[ "$fail" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "ONE OR MORE CHECKS FAILED"
exit $fail
