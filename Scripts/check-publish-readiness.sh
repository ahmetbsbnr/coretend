#!/bin/sh
# Publish gate — NOT part of normal CI. Regular CI (ci.yml) must stay green
# with placeholders still in place, pre-release; this script is the one that
# is allowed to fail on them, run only before a real public release
# (manually, or from a future release workflow).
#
# Zero placeholders, a filled-in Configuration/PublicIdentity.local.json,
# and a final release manifest are all required. See
# Documentation/PUBLICATION_PLACEHOLDERS.md and
# Documentation/FIRST_PUBLIC_RELEASE_CHECKLIST.md for the human-only steps
# this cannot automate (an actual security contact inbox, actual legal
# identity, a registered domain).
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

fail=0
ok()  { echo "OK: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

echo "== Zero publication placeholders anywhere in the tracked tree =="
TOKENS='\[SECURITY_CONTACT_TO_DEFINE\]|\[MAINTAINER_HANDLE_TO_DEFINE\]|\[REPO_URL_TO_DEFINE\]|\[LEGAL_NAME_TO_DEFINE\]|\[LEGAL_ADDRESS_TO_DEFINE\]|\[DOMAIN_TO_DEFINE\]|\[LEGAL_ENTITY_TO_DEFINE\]|\[PUBLISHER_OF_RECORD_TO_DEFINE\]'
if matches=$(git grep -nIE "$TOKENS" -- . 2>/dev/null); then
  echo "$matches"
  bad "placeholder tokens remain (see above) — not ready for public release"
else
  ok "no placeholder tokens remain"
fi

echo "== Configuration/PublicIdentity.local.json exists and is filled in =="
IDENTITY="Configuration/PublicIdentity.local.json"
if [ ! -f "$IDENTITY" ]; then
  bad "$IDENTITY does not exist — copy PublicIdentity.example.json and fill in real values"
elif grep -qE '_TO_DEFINE' "$IDENTITY"; then
  bad "$IDENTITY still contains _TO_DEFINE placeholder values"
else
  ok "$IDENTITY exists with no placeholder values"
fi

echo "== Security contact reachable-looking value present =="
if [ -f "$IDENTITY" ] && grep -q '"securityContact"' "$IDENTITY" && ! grep -q 'securityContact.*TO_DEFINE' "$IDENTITY"; then
  ok "securityContact is set in $IDENTITY"
else
  bad "securityContact missing or still a placeholder in $IDENTITY"
fi

echo "== Release manifest provenance is real and releasable =="
# Deliberately NOT "sourceCommit == HEAD". That was circular: the manifest used
# to be tracked, so the commit adding it could never be named inside it, and this
# check could only pass on an uncommitted tree. The manifest is now generated
# output; what matters is that it was built from a clean tree and, for a real
# release, from the exact tag being published. See Documentation/RELEASE_PROVENANCE.md.
if [ -f Release/latest.json ]; then
  MANIFEST_COMMIT=$(/usr/bin/python3 -c "import json; print(json.load(open('Release/latest.json')).get('sourceCommit') or '')")
  MANIFEST_TREE=$(/usr/bin/python3 -c "import json; print(json.load(open('Release/latest.json')).get('treeState') or '')")
  MANIFEST_TAG=$(/usr/bin/python3 -c "import json; print(json.load(open('Release/latest.json')).get('releaseTag') or '')")

  if [ -z "$MANIFEST_COMMIT" ]; then
    bad "Release/latest.json has no sourceCommit — regenerate with Scripts/build-release.sh"
  elif git cat-file -e "${MANIFEST_COMMIT}^{commit}" 2>/dev/null; then
    ok "manifest sourceCommit is a real commit ($MANIFEST_COMMIT)"
  else
    bad "manifest sourceCommit ($MANIFEST_COMMIT) is not a commit in this repository"
  fi

  [ "$MANIFEST_TREE" = "clean" ] \
    && ok "manifest was built from a clean tree" \
    || bad "manifest treeState is '$MANIFEST_TREE' — a publishable build must come from a clean tree"

  # A public release must be cut from a tag, so the published artifacts are
  # reachable from an immutable ref rather than a floating commit.
  if [ -n "$MANIFEST_TAG" ]; then
    if git rev-parse -q --verify "refs/tags/$MANIFEST_TAG" >/dev/null \
       && [ "$(git rev-parse "refs/tags/$MANIFEST_TAG^{commit}")" = "$MANIFEST_COMMIT" ]; then
      ok "manifest was built on tag $MANIFEST_TAG, which points at sourceCommit"
    else
      bad "manifest names releaseTag $MANIFEST_TAG but it does not point at sourceCommit"
    fi
  else
    bad "manifest has no releaseTag — a public release must be built from a tagged commit"
  fi
else
  bad "Release/latest.json does not exist — run Scripts/build-release.sh first"
fi

echo "== summary =="
if [ "$fail" -eq 0 ]; then
  echo "check-publish-readiness.sh: READY FOR PUBLIC RELEASE (automated checks only — human steps in FIRST_PUBLIC_RELEASE_CHECKLIST.md still apply)"
else
  echo "check-publish-readiness.sh: NOT READY — see FAIL lines above. This is expected pre-release; it must never be run as a blocking step in normal CI."
fi
exit "$fail"
