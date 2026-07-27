#!/bin/sh
# Reports every remaining publication placeholder token (see
# Documentation/PUBLICATION_PLACEHOLDERS.md). This is a *gate*, not a
# bug report: before a real public release, this must print zero
# matches; until then, nonzero is expected.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

TOKENS='\[SECURITY_CONTACT_TO_DEFINE\]|\[MAINTAINER_HANDLE_TO_DEFINE\]|\[REPO_URL_TO_DEFINE\]|\[LEGAL_NAME_TO_DEFINE\]|\[LEGAL_ADDRESS_TO_DEFINE\]|\[DOMAIN_TO_DEFINE\]'

# Configuration/PublicIdentity.example.json is the template that *defines* the
# placeholder mechanism: its bracketed values are what the site renders when no
# real identity has been supplied, which is the deliberate visible-failure mode.
# Resolving them there would remove the safety net rather than satisfy it, so
# the file is excluded here. The real values are gated separately and more
# strictly by check-publish-readiness.sh, which requires the gitignored
# Configuration/PublicIdentity.local.json to exist and to carry no _TO_DEFINE
# value. Generated site HTML is tracked and still scanned, so an identity
# regression would surface there.
EXCLUDE=':(exclude)Configuration/PublicIdentity.example.json'

echo "Scanning tracked files for publication placeholders..."
matches=$(git grep -nIE "$TOKENS" -- . "$EXCLUDE" 2>/dev/null || true)

if [ -n "$matches" ]; then
  echo "$matches"
  count=$(printf '%s\n' "$matches" | wc -l | tr -d ' ')
  echo "check-placeholders.sh: $count placeholder occurrence(s) remain — expected pre-release, must be zero before real publication."
  exit 0
fi

echo "check-placeholders.sh: 0 placeholders remain."
