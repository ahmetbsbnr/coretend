#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# The last gate before a public release. Reproducible, read-only, and honest
# about the difference between "this passed", "this does not apply", and "a
# human has to do this".
#
# Four verdicts, and the distinction matters:
#
#   PASS                   verified here, with the command shown
#   FAIL                   verified here, and wrong
#   NOT_APPLICABLE         cannot apply in this configuration, and that is fine
#   HUMAN_ACTION_REQUIRED  correct so far, but needs a person to finish
#
# The unsigned status of 0.9.0 is deliberately NOT reported as a signing pass.
# It is reported as NOT_APPLICABLE with the reason, because presenting an
# absent signature as a success is the one thing this gate exists to prevent.
#
# Exit code is 0 only when nothing FAILed. HUMAN_ACTION_REQUIRED does not fail
# the gate — it is the expected state before someone pushes the button — but it
# is always printed in the summary so it cannot be overlooked.
#
# Usage: bash Scripts/final-launch-gate.sh [--expect-head <sha>] [--expect-version <v>]
set -uo pipefail

cd "$(dirname "$0")/.."

EXPECT_HEAD=""
EXPECT_VERSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --expect-head)    EXPECT_HEAD="${2:-}"; shift 2 ;;
    --expect-version) EXPECT_VERSION="${2:-}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

pass=0; fail=0; na=0; human=0
FAILED_ITEMS=(); HUMAN_ITEMS=()

PASS()  { printf '  PASS                   %s\n' "$1"; pass=$((pass+1)); }
FAIL()  { printf '  FAIL                   %s\n' "$1"; fail=$((fail+1)); FAILED_ITEMS+=("$1"); }
NA()    { printf '  NOT_APPLICABLE         %s\n' "$1"; na=$((na+1)); }
HUMAN() { printf '  HUMAN_ACTION_REQUIRED  %s\n' "$1"; human=$((human+1)); HUMAN_ITEMS+=("$1"); }

section() { printf '\n== %s ==\n' "$1"; }

# Run a gate script, reporting by exit status. Exit code is captured directly,
# never through a pipe — a pipeline reports the last command's status, which
# silently turns a failing gate into a passing one.
run_gate() {
  local label="$1"; shift
  local out
  if out=$("$@" 2>&1); then PASS "$label"; else FAIL "$label — $(printf '%s' "$out" | tail -1)"; fi
}

echo "CoreTend — final launch gate"
echo "run (UTC):   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "commit:      $(git rev-parse HEAD 2>/dev/null || echo '(not a git repo)')"
echo "branch:      $(git branch --show-current 2>/dev/null)"

# ---------------------------------------------------------------- repository
section "Repository"

if [ -z "$(git status --porcelain --untracked-files=no)" ]; then
  PASS "working tree is clean"
else
  FAIL "working tree is dirty — a release must be built from a committed tree"
fi

BRANCH=$(git branch --show-current)
case "$BRANCH" in
  main|feat/coretend-rebrand-workspace)
    PASS "branch '$BRANCH' is an allowed release branch" ;;
  "") FAIL "detached HEAD — a release must be cut from a named branch" ;;
  *)  FAIL "branch '$BRANCH' is not an allowed release branch" ;;
esac

HEAD_SHA=$(git rev-parse HEAD)
if [ -n "$EXPECT_HEAD" ]; then
  # "$EXPECT_HEAD^{commit}" dereferences an annotated tag to the commit it
  # points at. Plain `git rev-parse <tag>` returns the tag OBJECT's own sha for
  # an annotated tag, not the commit sha, so comparing that directly against
  # HEAD_SHA fails even when the tag correctly points at HEAD.
  EXPECT_COMMIT=$(git rev-parse "${EXPECT_HEAD}^{commit}" 2>/dev/null)
  if [ -n "$EXPECT_COMMIT" ] && [ "$HEAD_SHA" = "$EXPECT_COMMIT" ]; then
    PASS "HEAD matches the expected commit"
  else
    FAIL "HEAD is $HEAD_SHA, expected $EXPECT_HEAD (resolves to ${EXPECT_COMMIT:-unresolvable})"
  fi
else
  NA "expected HEAD not supplied (pass --expect-head <sha> to pin it)"
fi

# ------------------------------------------------------------------- version
section "Version"

IDENT_EXAMPLE="Configuration/PublicIdentity.example.json"
IDENT_LOCAL="Configuration/PublicIdentity.local.json"
VERSION=$(/usr/bin/python3 -c "
import json, os
cfg = json.load(open('$IDENT_EXAMPLE'))
if os.path.exists('$IDENT_LOCAL'):
    cfg.update(json.load(open('$IDENT_LOCAL')))
print(cfg.get('marketingVersion', ''))
" 2>/dev/null)

if [ -n "$VERSION" ]; then PASS "configured version is $VERSION"; else FAIL "no marketingVersion resolvable"; fi

if [ -n "$EXPECT_VERSION" ]; then
  [ "$VERSION" = "$EXPECT_VERSION" ] \
    && PASS "version matches the expected $EXPECT_VERSION" \
    || FAIL "version is $VERSION, expected $EXPECT_VERSION"
fi

case "$VERSION" in
  1.*) FAIL "version $VERSION claims 1.x — this release is an unsigned beta and must not be 1.0" ;;
  *)   PASS "version does not claim a 1.x signed release" ;;
esac

run_gate "version is consistent across Info.plist and PROJECT_STATE.json" \
  bash Scripts/check-version-consistency.sh

# --------------------------------------------------------------- build/tests
section "Build and tests"

run_gate "test suite" bash Scripts/test.sh
run_gate "Debug build" swift build
run_gate "Release build" swift build -c release

# ----------------------------------------------------------------- artifacts
section "Artifacts"

ZIP="Release/CoreTend-${VERSION}-arm64-unsigned.zip"
DMG="Release/CoreTend-${VERSION}-arm64-unsigned.dmg"
MANIFEST="Release/latest.json"

if [ -f "$MANIFEST" ]; then
  if /usr/bin/python3 -m json.tool "$MANIFEST" >/dev/null 2>&1; then
    PASS "$MANIFEST is valid JSON"
  else
    FAIL "$MANIFEST is not valid JSON"
  fi

  M_VERSION=$(/usr/bin/python3 -c "import json;print(json.load(open('$MANIFEST')).get('version',''))")
  M_TAG=$(/usr/bin/python3 -c "import json;print(json.load(open('$MANIFEST')).get('releaseTag') or '')")
  M_TREE=$(/usr/bin/python3 -c "import json;print(json.load(open('$MANIFEST')).get('treeState',''))")
  M_SIGNED=$(/usr/bin/python3 -c "import json;print(json.load(open('$MANIFEST')).get('signed'))")
  M_NOTARIZED=$(/usr/bin/python3 -c "import json;print(json.load(open('$MANIFEST')).get('notarized'))")
  M_COMMIT=$(/usr/bin/python3 -c "import json;print(json.load(open('$MANIFEST')).get('sourceCommit',''))")

  [ "$M_VERSION" = "$VERSION" ] \
    && PASS "manifest version matches the configured version" \
    || FAIL "manifest version is $M_VERSION, configured is $VERSION"

  [ "$M_TREE" = "clean" ] \
    && PASS "manifest records a clean-tree build" \
    || FAIL "manifest treeState is '$M_TREE' — not releasable"

  if [ "$M_COMMIT" = "$HEAD_SHA" ]; then
    PASS "artifacts were built from the current HEAD"
  else
    FAIL "artifacts were built from $M_COMMIT but HEAD is $HEAD_SHA — rebuild before releasing"
  fi

  # The manifest must never advertise a signature that does not exist.
  { [ "$M_SIGNED" = "False" ] && [ "$M_NOTARIZED" = "False" ]; } \
    && PASS "manifest declares signed=false and notarized=false, matching reality" \
    || FAIL "manifest claims signed=$M_SIGNED notarized=$M_NOTARIZED — it must not claim what was not done"

  if [ -n "$M_TAG" ]; then
    PASS "manifest carries release tag $M_TAG"
  else
    HUMAN "no release tag yet — build on a tagged commit to publish (see §G of the launch brief)"
  fi
else
  FAIL "$MANIFEST does not exist — run Scripts/build-release.sh"
fi

if [ -f "$ZIP" ]; then
  unzip -tqq "$ZIP" >/dev/null 2>&1 \
    && PASS "ZIP integrity ($(basename "$ZIP"), $(stat -f%z "$ZIP") bytes)" \
    || FAIL "ZIP failed unzip -t"
  # Listed once into a variable rather than piped per lookup: `unzip -l | grep -q`
  # makes grep exit at the first match, which SIGPIPEs unzip, which under
  # `pipefail` reports the whole pipeline as failed even though the file was
  # found. That produced a false "missing NOTICE" against a ZIP that contained
  # it. Matching against a string cannot misfire that way.
  ZIP_LIST=$(unzip -l "$ZIP" 2>/dev/null)
  for required in LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
    case "$ZIP_LIST" in
      *" ${required}"$'\n'*|*" ${required}") PASS "ZIP contains $required" ;;
      *) FAIL "ZIP is missing $required (Apache-2.0 §4 requires NOTICE to travel with the work)" ;;
    esac
  done
else
  FAIL "$ZIP not found"
fi

if [ -f "$DMG" ]; then
  hdiutil verify "$DMG" >/dev/null 2>&1 \
    && PASS "DMG checksum verifies ($(basename "$DMG"), $(stat -f%z "$DMG") bytes)" \
    || FAIL "hdiutil verify failed on the DMG"
else
  NA "no DMG present for this version"
fi

if [ -f Release/SHA256SUMS ]; then
  ( cd Release && shasum -a 256 -c SHA256SUMS >/dev/null 2>&1 ) \
    && PASS "Release/SHA256SUMS verifies against the artifacts" \
    || FAIL "Release/SHA256SUMS does not match the artifacts"
else
  FAIL "Release/SHA256SUMS not found"
fi

# ------------------------------------------------- signing and notarization
section "Signing and notarization"

# Captured, not piped. Under `pipefail`, `producer | grep -q` lets grep exit at
# the first match and SIGPIPE the producer, so the pipeline reports failure even
# on a match — nondeterministically, depending on who finishes first. That bug
# made this gate flip its ad-hoc signature verdict between identical runs.
IDENTITY_OUT=$(security find-identity -v -p codesigning 2>/dev/null || true)
case "$IDENTITY_OUT" in
  *"0 valid identities found"*)
    NA "code signing — no Developer ID available on this machine, and 0.9.0 ships unsigned by decision. This is NOT a signing pass."
    NA "notarization — impossible without a Developer ID. This is NOT a notarization pass."
    ;;
  *)
    HUMAN "a signing identity exists on this machine — decide deliberately whether 0.9.0 should still ship unsigned"
    ;;
esac

APP="build/CoreTend.app"
if [ -d "$APP" ]; then
  CODESIGN_OUT=$(codesign -dv "$APP" 2>&1 || true)
  case "$CODESIGN_OUT" in
    *"Signature=adhoc"*)
      PASS "built app carries an ad-hoc signature only (asserts no identity, as expected)" ;;
    *)
      HUMAN "built app is not ad-hoc signed — verify what identity it carries before publishing" ;;
  esac
  # Gatekeeper MUST reject an unsigned build. If it ever accepts one, something
  # is signing it that we did not intend, and that is worth stopping for.
  if spctl --assess --type execute "$APP" >/dev/null 2>&1; then
    FAIL "Gatekeeper ACCEPTED an unsigned build — unexpected; investigate before publishing"
  else
    PASS "Gatekeeper rejects the unsigned app, as documented (expected for 0.9.0)"
  fi
else
  NA "no built app at $APP to assess"
fi

# ------------------------------------------------------- content and legal
section "Content, legal and secrets"

run_gate "no publication placeholders remain"  bash Scripts/check-placeholders.sh
run_gate "no private data in tracked files"    bash Scripts/check-private-data.sh
run_gate "licence declarations present"        bash Scripts/check-licenses.sh
run_gate "no unexplained pre-rename references" bash Scripts/check-legacy-brand-references.sh
run_gate "website integrity and accessibility floor" bash Scripts/check-website.sh
run_gate "internal documentation links resolve" /usr/bin/python3 Scripts/check-markdown-links.py

for f in LICENSE NOTICE COPYRIGHT THIRD_PARTY_NOTICES.md TRADEMARKS.md SECURITY.md PRIVACY.md; do
  [ -f "$f" ] && PASS "$f present" || FAIL "$f missing"
done

for f in "Release/Notes/${VERSION}.en.md" "Release/Notes/${VERSION}.fr.md"; do
  [ -f "$f" ] && PASS "release notes $(basename "$f") present" || FAIL "release notes $f missing"
done

# Release notes must disclose the unsigned status rather than bury it.
if [ -f "Release/Notes/${VERSION}.en.md" ]; then
  grep -qi 'unsigned' "Release/Notes/${VERSION}.en.md" \
    && PASS "release notes disclose the unsigned status" \
    || FAIL "release notes do not mention that the build is unsigned"
  # Match the actual dangerous instruction, not the phrase. Notes that say
  # "do not disable Gatekeeper" contain the words "disable Gatekeeper", so a
  # phrase match flags correct advice as if it were the opposite. The commands
  # below are the only way to disable it system-wide, so their presence is what
  # matters.
  if grep -Eqi 'spctl[[:space:]]+--(master|global)-disable' "Release/Notes/${VERSION}.en.md"; then
    FAIL "release notes contain a command that disables Gatekeeper system-wide"
  else
    PASS "release notes do not instruct disabling Gatekeeper system-wide"
  fi
fi

for p in en/legal.html en/privacy.html en/security.html en/licenses.html \
         fr/legal.html fr/privacy.html fr/security.html fr/licenses.html; do
  [ -f "Website/$p" ] && PASS "legal page Website/$p generated" || FAIL "legal page Website/$p missing"
done

# ------------------------------------------------------------- publication
section "Publication"

TAG_NAME="v${VERSION}"
if git rev-parse -q --verify "refs/tags/${TAG_NAME}" >/dev/null; then
  PASS "tag ${TAG_NAME} exists locally"
  if [ "$(git rev-list -n1 "${TAG_NAME}")" = "$HEAD_SHA" ]; then
    PASS "tag ${TAG_NAME} points at HEAD"
  else
    FAIL "tag ${TAG_NAME} does not point at HEAD"
  fi
else
  HUMAN "tag ${TAG_NAME} does not exist yet — create it once this gate is otherwise green"
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  if gh release view "${TAG_NAME}" >/dev/null 2>&1; then
    if [ "$(gh release view "${TAG_NAME}" --json isPrerelease --jq .isPrerelease 2>/dev/null)" = "true" ]; then
      PASS "GitHub release ${TAG_NAME} exists and is marked prerelease"
    else
      FAIL "GitHub release ${TAG_NAME} is NOT marked prerelease — a beta must not present as stable"
    fi
  else
    HUMAN "no GitHub release for ${TAG_NAME} yet — publishing is a deliberate act"
  fi
else
  NA "gh unavailable or unauthenticated — cannot check the published release"
fi

# Deployment. Never assert DNS or TLS without resolving them for real.
SITE_HOST=$(/usr/bin/python3 -c "
import json, os
cfg = json.load(open('$IDENT_EXAMPLE'))
if os.path.exists('$IDENT_LOCAL'):
    cfg.update(json.load(open('$IDENT_LOCAL')))
print(cfg.get('websiteURL','').replace('https://','').replace('http://','').rstrip('/'))
" 2>/dev/null)

if [ -n "$SITE_HOST" ] && command -v dig >/dev/null 2>&1; then
  if [ -n "$(dig +short "$SITE_HOST" 2>/dev/null)" ]; then
    PASS "DNS resolves for $SITE_HOST"
    CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$SITE_HOST/en/index.html" 2>/dev/null)
    case "$CODE" in
      200)
        PASS "https://$SITE_HOST/en/index.html returns 200"
        REDIR=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "http://$SITE_HOST/en/index.html" 2>/dev/null)
        case "$REDIR" in
          30*|200) PASS "http://$SITE_HOST redirects or serves over TLS ($REDIR)" ;;
          *)       FAIL "http://$SITE_HOST returned '$REDIR' — expected a redirect to HTTPS" ;;
        esac ;;
      404|000)
        # The name resolving is not the same as the site being deployed. A 404
        # here means DNS points somewhere real that is not serving this site
        # yet, which is exactly the pre-deploy state — not a defect.
        HUMAN "$SITE_HOST resolves but returns '$CODE' — the site is not deployed yet" ;;
      *)
        FAIL "https://$SITE_HOST/en/index.html returned '$CODE'" ;;
    esac
  else
    HUMAN "DNS does not resolve for $SITE_HOST — the CNAME is the one step that needs registrar access"
  fi
else
  NA "site host not configured, or dig unavailable"
fi

# -------------------------------------------------------------------- summary
section "Summary"
printf '  PASS                   %d\n' "$pass"
printf '  FAIL                   %d\n' "$fail"
printf '  NOT_APPLICABLE         %d\n' "$na"
printf '  HUMAN_ACTION_REQUIRED  %d\n' "$human"

if [ "$human" -gt 0 ]; then
  echo
  echo "Waiting on a person:"
  for item in "${HUMAN_ITEMS[@]}"; do echo "  - $item"; done
fi

if [ "$fail" -gt 0 ]; then
  echo
  echo "Blocking failures:"
  for item in "${FAILED_ITEMS[@]}"; do echo "  - $item"; done
  echo
  echo "final-launch-gate.sh: NOT READY"
  exit 1
fi

echo
if [ "$human" -gt 0 ]; then
  echo "final-launch-gate.sh: READY, pending the human actions listed above."
  echo "Nothing here is broken. Nothing here is signed either — 0.9.0 ships unsigned by decision."
else
  echo "final-launch-gate.sh: READY"
fi
exit 0
