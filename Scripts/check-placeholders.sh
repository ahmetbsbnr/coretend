#!/bin/sh
# Reports every remaining publication placeholder token (see
# Documentation/PUBLICATION_PLACEHOLDERS.md). This is a *gate*, not a
# bug report: before a real public release, this must print zero
# matches; until then, nonzero is expected.
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

TOKENS='\[SECURITY_CONTACT_TO_DEFINE\]|\[MAINTAINER_HANDLE_TO_DEFINE\]|\[REPO_URL_TO_DEFINE\]|\[LEGAL_NAME_TO_DEFINE\]|\[LEGAL_ADDRESS_TO_DEFINE\]|\[DOMAIN_TO_DEFINE\]'

echo "Scanning tracked files for publication placeholders..."
matches=$(git grep -nIE "$TOKENS" -- . 2>/dev/null || true)

if [ -n "$matches" ]; then
  echo "$matches"
  count=$(printf '%s\n' "$matches" | wc -l | tr -d ' ')
  echo "check-placeholders.sh: $count placeholder occurrence(s) remain — expected pre-release, must be zero before real publication."
  exit 0
fi

echo "check-placeholders.sh: 0 placeholders remain."
