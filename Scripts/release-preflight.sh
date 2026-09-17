#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Everything that can be known to be wrong BEFORE a release spends an Apple
# notarization round trip, in one place.
#
# Written after v1.0.1 nearly published unverifiable. The Minisign key had been
# rotated in the GitHub Actions secret while the repository still published the
# retired public key; release.yml would have caught it, but only after building,
# Developer ID signing and notarizing — leaving a half-made release and a wasted
# round trip. Every check here is cheap, local, and answers a question that used
# to be answered too late.
#
# Ordering is deliberate: the checks that need no credentials and no network run
# first, so the common failures are reported in seconds.
#
# Usage:
#   Scripts/release-preflight.sh <version> [--signing]
#
#   --signing  also check the signing-runner-only prerequisites (Developer ID
#              identity, notarytool profile, minisign binary). Omit it in plain
#              CI, which has none of them and is not supposed to.
#
# Exit 0 = every checked invariant holds. Exit 1 = do not tag.
set -uo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "usage: Scripts/release-preflight.sh <version> [--signing]" >&2
  exit 2
fi
VERSION="${VERSION#v}"
SIGNING=0
[ "${2:-}" = "--signing" ] && SIGNING=1

fail=0
ok()   { printf '  OK   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
note() { printf '       %s\n' "$1"; }
head_() { printf '\n== %s ==\n' "$1"; }

REPO="${CORETEND_REPO:-ahmetbsbnr/coretend}"

# ---------------------------------------------------------------- version ---
head_ "Version is coherent everywhere"

SOT_VERSION=$(/usr/bin/python3 -c "import json;print(json.load(open('Configuration/PublicIdentity.example.json'))['marketingVersion'])" 2>/dev/null)
if [ "$SOT_VERSION" = "$VERSION" ]; then
  ok "Configuration/PublicIdentity.example.json declares $VERSION"
else
  bad "version mismatch against the single source of truth"
  note "Expected: $VERSION (the version being released)"
  note "Found:    ${SOT_VERSION:-<unreadable>} in Configuration/PublicIdentity.example.json"
  note "Fix: bump marketingVersion there, then re-run Scripts/check-version-consistency.sh"
fi

if bash Scripts/check-version-consistency.sh >/dev/null 2>&1; then
  ok "Info.plist, PROJECT_STATE.json and the changelog agree"
else
  bad "version copies disagree — Scripts/check-version-consistency.sh fails"
  note "Fix: run it directly; it names the file that is out of step."
fi

for notes in "Release/Notes/${VERSION}.en.md" "Release/Notes/${VERSION}.fr.md"; do
  if [ -s "$notes" ]; then ok "$notes exists"; else
    bad "$notes is missing or empty"
    note "Fix: write the release notes before tagging; the release body quotes them."
  fi
done

# ------------------------------------------------------------- minisign ----
head_ "Minisign key matches the version being released"

if EXPECTED_KEY=$(/usr/bin/python3 Scripts/resolve-minisign-key.py "$VERSION" 2>/dev/null); then
  ok "version $VERSION expects key $EXPECTED_KEY"
  if /usr/bin/python3 Scripts/resolve-minisign-key.py "$VERSION" --check >/dev/null 2>&1; then
    ok "Configuration/minisign.pub carries $EXPECTED_KEY"
  else
    bad "Configuration/minisign.pub does not carry the key this version requires"
    /usr/bin/python3 Scripts/resolve-minisign-key.py "$VERSION" --check 2>&1 | sed 's/^/       /'
  fi
else
  bad "no Minisign key is registered for version $VERSION"
  /usr/bin/python3 Scripts/resolve-minisign-key.py "$VERSION" 2>&1 | sed 's/^/       /'
fi

# --------------------------------------------------------------- git ------
head_ "The commit being released is the one that was validated"

if [ -z "$(git status --short --untracked-files=no)" ]; then
  ok "working tree is clean"
else
  bad "working tree is dirty — the tag would not describe what gets built"
  git status --short --untracked-files=no | sed 's/^/       /'
fi

HEAD_SHA=$(git rev-parse HEAD)
if git merge-base --is-ancestor "$HEAD_SHA" origin/main 2>/dev/null || \
   [ "$HEAD_SHA" = "$(git rev-parse origin/main 2>/dev/null || echo none)" ]; then
  ok "HEAD (${HEAD_SHA:0:7}) is on origin/main"
else
  bad "HEAD (${HEAD_SHA:0:7}) is not an ancestor of origin/main"
  note "Expected: releases are cut from main, so the published source is reviewable."
  note "Fix: land the work on main and re-run, or release from the right commit."
fi

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  bad "tag v$VERSION already exists locally"
  note "Expected: a new version tag. Re-tagging silently changes what a release means."
  note "Fix: bump the version, or delete the tag deliberately if it was never pushed."
else
  ok "tag v$VERSION does not exist yet"
fi

# ------------------------------------------------------------ remote -------
head_ "GitHub state"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  if gh release view "v$VERSION" -R "$REPO" >/dev/null 2>&1; then
    bad "a GitHub release v$VERSION already exists"
    note "Fix: delete it deliberately, or release a new version. Never overwrite a published release."
  else
    ok "no GitHub release v$VERSION yet"
  fi

  CI_STATE=$(gh api "repos/$REPO/commits/$HEAD_SHA/check-runs" \
    --jq '[.check_runs[] | select(.name=="build-and-test" or .name=="distribution-check")] | map(.conclusion // "pending") | join(",")' 2>/dev/null)
  case "$CI_STATE" in
    "") note "no check-runs reported for ${HEAD_SHA:0:7} yet (CI may not have started)" ;;
    *pending*|*failure*|*cancelled*|*timed_out*)
       bad "CI for ${HEAD_SHA:0:7} is not green (build-and-test, distribution-check = $CI_STATE)"
       note "Expected: both success. Tagging a red commit publishes code nothing validated." ;;
    *) ok "CI for ${HEAD_SHA:0:7} is green ($CI_STATE)" ;;
  esac

  RUNNERS=$(gh api "repos/$REPO/actions/runners" --jq '[.runners[] | select(.status=="online")] | length' 2>/dev/null || echo 0)
  if [ "${RUNNERS:-0}" -gt 0 ]; then
    ok "$RUNNERS self-hosted runner(s) online"
  else
    bad "no self-hosted runner is online — the release job would queue forever"
    note "Fix: start the signing runner (see Documentation/RELEASE_RUNBOOK.md)."
  fi

  for secret in CORETEND_DEVELOPER_ID_APPLICATION CORETEND_NOTARY_PROFILE MINISIGN_SECRET_KEY MINISIGN_PASSWORD; do
    if gh secret list -R "$REPO" --json name --jq '.[].name' 2>/dev/null | grep -qx "$secret"; then
      ok "secret $secret is configured"
    else
      bad "secret $secret is missing"
      note "Fix: gh secret set $secret -R $REPO   (see Documentation/RELEASE_RUNBOOK.md)"
    fi
  done
else
  note "gh is unavailable or unauthenticated — skipped the GitHub-side checks"
  note "These are exactly the checks that catch a queued-forever release; prefer running with gh."
fi

# ------------------------------------------------------- signing host -----
if [ "$SIGNING" = "1" ]; then
  head_ "Signing host prerequisites"

  DEV_ID="${CORETEND_DEVELOPER_ID_APPLICATION:-}"
  if [ -z "$DEV_ID" ]; then
    bad "CORETEND_DEVELOPER_ID_APPLICATION is not set in this environment"
  elif security find-identity -v -p codesigning 2>/dev/null | grep -qF "$DEV_ID"; then
    ok "Developer ID identity present: $DEV_ID"
  else
    bad "Developer ID identity '$DEV_ID' is not in the keychain"
    note "Found: $(security find-identity -v -p codesigning 2>/dev/null | grep -c 'Developer ID Application') Developer ID identities"
    note "Fix: unlock the login keychain, or re-import the certificate. See the runbook."
  fi

  PROFILE="${CORETEND_NOTARY_PROFILE:-}"
  if [ -z "$PROFILE" ]; then
    bad "CORETEND_NOTARY_PROFILE is not set in this environment"
  elif xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    ok "notarytool profile '$PROFILE' works"
  else
    bad "notarytool profile '$PROFILE' is not usable"
    note "Fix: xcrun notarytool store-credentials \"$PROFILE\" --key … --key-id … --issuer …"
    note "An expired Apple credential fails here rather than midway through a release."
  fi

  for tool in minisign shasum ditto hdiutil codesign xcrun swift; do
    if command -v "$tool" >/dev/null 2>&1; then ok "$tool available"; else
      bad "$tool is not on PATH"
      note "Fix: install it on the signing runner; the release cannot complete without it."
    fi
  done
fi

# ---------------------------------------------------------------- done ----
printf '\n'
if [ "$fail" -ne 0 ]; then
  echo "release-preflight: $fail check(s) FAILED — do not tag v$VERSION."
  exit 1
fi
echo "release-preflight: all checks passed for v$VERSION."
