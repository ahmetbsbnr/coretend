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
skipped=0
ok()   { printf '  OK   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
# A check this host cannot perform is not a check that failed. Conflating the
# two is how a gate earns a reputation for crying wolf and stops being read.
skip() { printf '  SKIP %s\n' "$1"; skipped=$((skipped + 1)); }
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

if [ -x /usr/libexec/PlistBuddy ]; then
  if bash Scripts/check-version-consistency.sh >/dev/null 2>&1; then
    ok "Info.plist, PROJECT_STATE.json and the changelog agree"
  else
    bad "version copies disagree — Scripts/check-version-consistency.sh fails"
    note "Fix: run it directly; it names the file that is out of step."
  fi
else
  # The canonical script uses PlistBuddy, which is macOS-only. Rather than skip
  # the invariant on Linux, check the same thing portably: plistlib reads the
  # very same file. Skipping here would have let a version mismatch through the
  # one gate that runs before a tag.
  if /usr/bin/env python3 - "$VERSION" <<'PYEOF' >/dev/null 2>&1
import json, plistlib, sys
version = sys.argv[1]
with open("Resources/Info.plist", "rb") as fh:
    plist = plistlib.load(fh)
state = json.load(open("Documentation/PROJECT_STATE.json"))
problems = []
for key in ("CFBundleShortVersionString", "CoreTendMarketingVersion"):
    if plist.get(key) != version:
        problems.append(f"Info.plist {key}={plist.get(key)!r} != {version!r}")
if str(state.get("version")) != version:
    problems.append(f"PROJECT_STATE.json version={state.get('version')!r} != {version!r}")
if problems:
    print("; ".join(problems))
    sys.exit(1)
PYEOF
  then
    ok "Info.plist and PROJECT_STATE.json agree on $VERSION (portable check)"
  else
    bad "version copies disagree with $VERSION"
    /usr/bin/env python3 - "$VERSION" <<'PYEOF' 2>&1 | sed 's/^/       /'
import json, plistlib, sys
version = sys.argv[1]
with open("Resources/Info.plist", "rb") as fh:
    plist = plistlib.load(fh)
state = json.load(open("Documentation/PROJECT_STATE.json"))
for key in ("CFBundleShortVersionString", "CoreTendMarketingVersion"):
    if plist.get(key) != version:
        print(f"Expected {key}={version}, found {plist.get(key)}")
if str(state.get("version")) != version:
    print(f"Expected PROJECT_STATE.json version={version}, found {state.get('version')}")
PYEOF
  fi
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

# The right assertion about the tag depends on which side of it we are.
# Before tagging, the tag must NOT exist: re-pointing one silently changes what
# a version means. Inside the release, which checks out the tag, it must exist
# and point at exactly this commit — that is the stronger invariant, and it
# catches a tag moved between validation and build.
if [ "${GITHUB_REF:-}" != "${GITHUB_REF#refs/tags/}" ]; then
  TAG_REF="${GITHUB_REF#refs/tags/}"
  if [ "$TAG_REF" != "v$VERSION" ]; then
    bad "running from tag $TAG_REF but releasing version $VERSION"
    note "Expected: the tag and the version to describe the same release."
  elif [ "$(git rev-parse "$TAG_REF^{commit}" 2>/dev/null)" = "$HEAD_SHA" ]; then
    ok "tag $TAG_REF points at this exact commit (${HEAD_SHA:0:7})"
  else
    bad "tag $TAG_REF does not point at the commit being built"
    note "Expected: $HEAD_SHA"
    note "Found:    $(git rev-parse "$TAG_REF^{commit}" 2>/dev/null || echo '<unresolvable>')"
    note "A tag moved after validation means the release is not the code that was checked."
  fi
elif git rev-parse "v$VERSION" >/dev/null 2>&1; then
  bad "tag v$VERSION already exists"
  note "Expected: a new version tag. Re-pointing one silently changes what a release means."
  note "Fix: bump the version, or delete the tag deliberately if it published nothing."
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

  # The API call's own success is part of the answer. A commit GitHub has
  # never seen returns {"message":"No commit found for SHA: …"}, which is not
  # empty and matches none of the failure patterns below — so it fell through
  # to the catch-all and this gate reported "CI is green" for a commit that
  # does not exist on the remote. A release gate that cannot tell "green" from
  # "never looked" is worse than no gate: it is the one check standing between
  # a tag and code nothing validated.
  if ! CI_RAW=$(gh api "repos/$REPO/commits/$HEAD_SHA/check-runs" 2>&1); then
    bad "cannot read CI status for ${HEAD_SHA:0:7} — GitHub says: $(printf '%s' "$CI_RAW" | head -1)"
    note "A tag must point at a commit CI validated. If the commit is not pushed, CI has not seen it."
  elif printf '%s' "$CI_RAW" | grep -q '"message"'; then
    bad "GitHub does not know commit ${HEAD_SHA:0:7} — it is not pushed, so CI never ran on it"
  else
    # Say what green means, positively. A denylist of bad words cannot hold
    # here: GitHub's `status` is queued/in_progress/completed — never the
    # "pending" this once matched — and its conclusions include neutral,
    # action_required, stale and startup_failure. Every value not listed read
    # as green, and one did: a commit whose checks were still in_progress
    # passed the gate whose whole job is to assert they finished.
    #
    # Both required checks must be present, completed, and concluded success.
    # A re-run leaves several runs under one name, so each name is judged by
    # its most recent one.
    CI_VERDICT=$(printf '%s' "$CI_RAW" | jq -r '
      [.check_runs[]] as $runs
      | ["build-and-test", "distribution-check"]
      | map(. as $name
            | ($runs | map(select(.name == $name)) | max_by(.started_at)) as $run
            | if $run == null then "\($name)=absent"
              elif $run.status != "completed" then "\($name)=\($run.status)"
              else "\($name)=\($run.conclusion // "no-conclusion")"
              end)
      | join(" ")')
    if [ "$CI_VERDICT" = "build-and-test=success distribution-check=success" ]; then
      ok "CI for ${HEAD_SHA:0:7} is green ($CI_VERDICT)"
    else
      bad "CI for ${HEAD_SHA:0:7} is not green ($CI_VERDICT)"
      note "Green means both checks present, completed and concluded success."
      note "Anything else — still running, absent, or any other conclusion — is not."
    fi
  fi

  # Listing runners and secrets needs an admin-scoped token. The workflow
  # GITHUB_TOKEN has neither, so a 403 here means "not visible from this
  # context", not "absent" — reporting it as a failure would be a lie, and the
  # kind that trains people to ignore the gate.
  if RUNNER_JSON=$(gh api "repos/$REPO/actions/runners" 2>/dev/null); then
    RUNNERS=$(printf '%s' "$RUNNER_JSON" | /usr/bin/env python3 -c "import json,sys;print(sum(1 for r in json.load(sys.stdin).get('runners',[]) if r.get('status')=='online'))" 2>/dev/null || echo 0)
    if [ "${RUNNERS:-0}" -gt 0 ]; then
      ok "$RUNNERS self-hosted runner(s) online"
    else
      bad "no self-hosted runner is online — the release job would queue forever, not fail"
      note "Fix: cd ~/actions-runner-coretend && caffeinate -dimsu ./run.sh"
      note "See Documentation/RELEASE_RUNBOOK.md → 'The signing runner'."
    fi
  else
    skip "runner status not visible from this token (needs admin scope)"
    note "Check it before tagging: gh api repos/$REPO/actions/runners"
  fi

  if gh secret list -R "$REPO" >/dev/null 2>&1; then
    SECRET_NAMES=$(gh secret list -R "$REPO" --json name --jq '.[].name' 2>/dev/null)
    for secret in CORETEND_DEVELOPER_ID_APPLICATION CORETEND_NOTARY_PROFILE MINISIGN_SECRET_KEY MINISIGN_PASSWORD; do
      if printf '%s\n' "$SECRET_NAMES" | grep -qx "$secret"; then
        ok "secret $secret is configured"
      else
        bad "secret $secret is missing"
        note "Fix: gh secret set $secret -R $REPO   (see Documentation/RELEASE_RUNBOOK.md)"
      fi
    done
  else
    skip "secret names not visible from this token (needs admin scope)"
    note "Check them before tagging: gh secret list -R $REPO"
  fi
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
if [ "$skipped" -ne 0 ]; then
  echo "release-preflight: $skipped check(s) could not be performed from this host."
fi
if [ "$fail" -ne 0 ]; then
  echo "release-preflight: $fail check(s) FAILED — do not tag v$VERSION."
  exit 1
fi
if [ "$skipped" -ne 0 ]; then
  echo "release-preflight: every check this host could perform passed for v$VERSION."
  echo "                   Run it again where the skipped ones are visible before tagging."
else
  echo "release-preflight: all checks passed for v$VERSION."
fi
