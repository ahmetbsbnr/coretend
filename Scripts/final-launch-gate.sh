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
# The gate adapts to the release posture recorded in Release/latest.json:
#
#   posture=signed    the manifest declares signed && notarized. The artifacts
#                     drop the -unsigned token and every signing check is
#                     verified for real (Developer ID, notarization, staple).
#   posture=unsigned  a local pre-signing build. The -unsigned artifacts and a
#                     signed=false manifest are expected. A 1.x version is still
#                     legitimate — the *published* line has been Developer ID
#                     signed and Apple-notarized since v0.9.1-rc.6
#                     (Configuration/published-release.json) — but shipping THIS
#                     build needs Scripts/sign-and-notarize.sh first, so that is
#                     reported as HUMAN_ACTION_REQUIRED, never as a signing pass.
#
# Presenting an absent signature as a success is the one thing this gate exists
# to prevent, in either posture.
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
  main|release/*)
    PASS "branch '$BRANCH' is an allowed release branch" ;;
  "") FAIL "detached HEAD — a release must be cut from a named branch" ;;
  *)  FAIL "branch '$BRANCH' is not an allowed release branch (expected main or release/*)" ;;
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

# 1.x is only legitimate once the published build is Developer ID signed and
# Apple-notarized. The release has been signed + notarized since v0.9.1-rc.6,
# so a 1.x version is now allowed; an unsigned build claiming 1.x still fails.
PUB_SIGNED=$(/usr/bin/python3 -c "
import json
r = json.load(open('Configuration/published-release.json'))
print('yes' if r.get('signed') and r.get('notarized') else 'no')
" 2>/dev/null)
case "$VERSION" in
  1.*)
    [ "$PUB_SIGNED" = "yes" ] \
      && PASS "version $VERSION claims 1.x and the published release is signed + notarized" \
      || FAIL "version $VERSION claims 1.x but the published release is not signed + notarized" ;;
  *)   PASS "version is pre-1.0" ;;
esac

# Release posture: does the built manifest declare a real signature, or is this
# a local pre-signing build? Everything downstream (artifact names, the signing
# section, the release-notes wording check) keys off this.
MANIFEST="Release/latest.json"
POSTURE="unsigned"
if [ -f "$MANIFEST" ]; then
  MAN_POSTURE=$(/usr/bin/python3 -c "
import json
m = json.load(open('$MANIFEST'))
print('signed' if m.get('signed') and m.get('notarized') else 'unsigned')
" 2>/dev/null)
  [ -n "$MAN_POSTURE" ] && POSTURE="$MAN_POSTURE"
fi
echo "posture:     $POSTURE (from $MANIFEST)"

run_gate "version is consistent across Info.plist and PROJECT_STATE.json" \
  bash Scripts/check-version-consistency.sh

# --------------------------------------------------------------- build/tests
section "Build and tests"

run_gate "test suite" bash Scripts/test.sh
run_gate "Debug build" swift build
run_gate "Release build" swift build -c release

# ----------------------------------------------------------------- artifacts
section "Artifacts"

if [ "$POSTURE" = "signed" ]; then
  ZIP="Release/CoreTend-${VERSION}-arm64.zip"
  DMG="Release/CoreTend-${VERSION}-arm64.dmg"
else
  ZIP="Release/CoreTend-${VERSION}-arm64-unsigned.zip"
  DMG="Release/CoreTend-${VERSION}-arm64-unsigned.dmg"
fi

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

  # The manifest must declare exactly what was done — no more, no less.
  if [ "$POSTURE" = "signed" ]; then
    { [ "$M_SIGNED" = "True" ] && [ "$M_NOTARIZED" = "True" ]; } \
      && PASS "manifest declares signed=true and notarized=true, matching a signed build" \
      || FAIL "posture is signed but manifest claims signed=$M_SIGNED notarized=$M_NOTARIZED"
  else
    { [ "$M_SIGNED" = "False" ] && [ "$M_NOTARIZED" = "False" ]; } \
      && PASS "manifest declares signed=false and notarized=false, matching this local build" \
      || FAIL "manifest claims signed=$M_SIGNED notarized=$M_NOTARIZED — it must not claim what was not done"
    case "$VERSION" in
      1.*) HUMAN "publishing $VERSION needs a signed rebuild: Scripts/sign-and-notarize.sh $VERSION CoreTend-Notary, then CORETEND_RELEASE_SIGNED=1 Scripts/build-release.sh $VERSION" ;;
    esac
  fi

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
  #
  # The file may sit at the archive root (unsigned ZIP: Scripts/package-zip.sh
  # stages the app plus loose LICENSE/NOTICE/THIRD_PARTY_NOTICES.md) or sealed
  # inside the bundle at CoreTend.app/Contents/Resources/ (signed ZIP:
  # sign-and-notarize.sh dittos the bundle only, and package-local.sh copies
  # the texts into Resources/ before signing). Both satisfy Apache-2.0 §4 —
  # the notice travels with the work — so accept either. The unzip -l name
  # column is preceded by spaces at the root and by '/' when nested.
  ZIP_LIST=$(unzip -l "$ZIP" 2>/dev/null)
  for required in LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
    case "$ZIP_LIST" in
      *" ${required}"$'\n'*|*" ${required}"|*"/${required}"$'\n'*|*"/${required}") PASS "ZIP contains $required" ;;
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

if [ "$POSTURE" = "signed" ]; then
  # A signed posture must be verifiable end to end on the packaged DMG.
  if [ -f "$DMG" ]; then
    if xcrun stapler validate "$DMG" >/dev/null 2>&1; then
      PASS "notarization ticket is stapled to the DMG (xcrun stapler validate)"
    else
      FAIL "posture is signed but the DMG has no stapled notarization ticket"
    fi
    if spctl --assess --type open --context context:primary-signature "$DMG" >/dev/null 2>&1; then
      PASS "Gatekeeper accepts the signed, notarized DMG"
    else
      FAIL "posture is signed but Gatekeeper rejects the DMG"
    fi
  else
    FAIL "posture is signed but $DMG is not present to verify"
  fi
  APP="build/CoreTend.app"
  if [ -d "$APP" ]; then
    if codesign --verify --strict --deep "$APP" >/dev/null 2>&1 \
       && codesign -dv "$APP" 2>&1 | grep -q 'Authority=Developer ID Application'; then
      PASS "built app carries a valid Developer ID Application signature"
    else
      HUMAN "verify build/CoreTend.app carries the Developer ID identity before publishing (it may be a local dev-signed copy)"
    fi
  fi
else
  # Local pre-signing build. A Developer ID identity on the machine is now
  # expected — it is what a release needs — so its presence is not a finding.
  # Captured, not piped: under `pipefail`, `producer | grep -q` lets grep exit
  # at the first match and SIGPIPE the producer, flipping the verdict between
  # identical runs.
  IDENTITY_OUT=$(security find-identity -p codesigning 2>/dev/null || true)
  case "$IDENTITY_OUT" in
    *"Developer ID Application"*)
      HUMAN "code signing — a Developer ID identity is present; run Scripts/sign-and-notarize.sh to produce the signed release artifacts. This local build is NOT signed." ;;
    *)
      HUMAN "code signing — no Developer ID identity is currently unlocked on this machine; signing must run in a session where the login keychain is available. This is NOT a signing pass." ;;
  esac
  HUMAN "notarization — not performed for a local build; runs as part of Scripts/sign-and-notarize.sh. This is NOT a notarization pass."

  APP="build/CoreTend.app"
  if [ -d "$APP" ]; then
    # The local build is signed with the Apple Development identity for on-device
    # testing (Scripts/build-release.sh), so Gatekeeper for *execute* may accept
    # it locally. What must never happen is the packaged DMG passing the
    # *distribution* assessment without a real notarization.
    if [ -f "$DMG" ] && spctl --assess --type open --context context:primary-signature "$DMG" >/dev/null 2>&1; then
      FAIL "the unsigned DMG passed Gatekeeper's distribution assessment — something notarized it unexpectedly; investigate"
    else
      PASS "the unsigned DMG does not pass Gatekeeper's distribution assessment, as expected for a local build"
    fi
  else
    NA "no built app at $APP to assess"
  fi
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

# Release notes must state the signing status truthfully for the posture.
if [ -f "Release/Notes/${VERSION}.en.md" ]; then
  NOTES_EN="Release/Notes/${VERSION}.en.md"
  if [ "$PUB_SIGNED" = "yes" ]; then
    if grep -qi 'notariz' "$NOTES_EN" && grep -qiE 'developer id|signed' "$NOTES_EN"; then
      PASS "release notes state the build is Developer ID signed and notarized"
    else
      FAIL "release notes do not state the signed + notarized status"
    fi
    if grep -qiE '\bunsigned\b|not signed|not notarized|non-notarized' "$NOTES_EN"; then
      FAIL "release notes still describe the build as unsigned — stale wording for a signed release"
    else
      PASS "release notes carry no stale unsigned wording"
    fi
  else
    grep -qi 'unsigned' "$NOTES_EN" \
      && PASS "release notes disclose the unsigned status" \
      || FAIL "release notes do not mention that the build is unsigned"
  fi
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

# The legal / privacy / licenses / support routes are generated by
# Website/build.py from Website/index.html — the authored per-locale HTML trees
# were retired. Build to a scratch dir and confirm every info route renders in
# both locales. check-website.sh (run above) validates their content and a11y;
# this only asserts the set is complete.
SITE_OUT=$(mktemp -d)
if ( cd Website && /usr/bin/python3 build.py --output "$SITE_OUT" ) >/dev/null 2>&1; then
  for route in legal.html privacy.html licenses.html support.html \
               fr-legal.html fr-privacy.html fr-licenses.html fr-support.html; do
    [ -s "$SITE_OUT/$route" ] \
      && PASS "generated info route $route" \
      || FAIL "generated info route $route is missing or empty"
  done
else
  FAIL "Website/build.py failed to produce the site — cannot verify the info routes"
fi
rm -rf "$SITE_OUT"

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
    # -L: the canonical URL is the trailing-slash form (/en/); index.html
    # 308-redirects to it. Follow redirects and judge the final status.
    CODE=$(curl -sL -o /dev/null -w '%{http_code}' --max-time 20 "https://$SITE_HOST/en/" 2>/dev/null)
    case "$CODE" in
      200)
        PASS "https://$SITE_HOST/en/ resolves to 200 (following redirects)"
        REDIR=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "http://$SITE_HOST/en/" 2>/dev/null)
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
        FAIL "https://$SITE_HOST/en/ returned '$CODE'" ;;
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
  if [ "$POSTURE" != "signed" ]; then
    echo "This is a local build. The signed + notarized release artifacts are produced"
    echo "by Scripts/sign-and-notarize.sh in a session with the login keychain unlocked."
  fi
else
  echo "final-launch-gate.sh: READY"
fi
exit 0
