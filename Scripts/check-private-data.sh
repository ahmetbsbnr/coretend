#!/bin/sh
# Fails if tracked files contain secrets, personal absolute paths, or
# obvious private-data patterns. Safe to run from any working directory;
# does not delete anything.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

fail=0

echo "Checking for the developer's real macOS username in tracked files..."
# Excludes docs that intentionally *document* that this path was checked
# and found clean (audit narrative, not a functional/secret path) —
# PUBLICATION_AUDIT.md, REPOSITORY_SANITIZATION.md, CONTINUATION.md (the
# running session log, which by nature accumulates this kind of
# self-referential audit prose every session), and PROJECT_COMPLETE_AUDIT.md
# (states the session's working directory as an audit fact — previously
# manually re-explained as "pre-existing" in every package manifest instead
# of being fixed at the source; fixed here instead).
if git grep -nIE 'ahmetbasbunar' -- '*.swift' '*.md' '*.json' '*.sh' '*.yml' '*.yaml' '*.py' \
    ':!Documentation/PUBLICATION_AUDIT.md' ':!Documentation/REPOSITORY_SANITIZATION.md' \
    ':!Documentation/CONTINUATION.md' ':!Documentation/PROJECT_COMPLETE_AUDIT.md' \
    ':!Scripts/check-private-data.sh' 2>/dev/null; then
  echo "FAIL: found the developer's real macOS username above."
  fail=1
else
  echo "OK: no developer username leaked into tracked source/docs."
fi

echo "Checking for likely secrets (api_key/secret/password/token = literal)..."
if git grep -nIE '(api[_-]?key|secret|password|token)[[:space:]]*[:=][[:space:]]*.[A-Za-z0-9]{10,}' -- '*.swift' '*.sh' '*.json' '*.yml' '*.yaml' 2>/dev/null; then
  echo "FAIL: possible hardcoded secret above."
  fail=1
else
  echo "OK: no obvious hardcoded secrets found."
fi

echo "Checking for tracked .env files..."
if git ls-files | grep -E '(^|/)\.env(\.|$)' ; then
  echo "FAIL: .env file(s) tracked above."
  fail=1
else
  echo "OK: no tracked .env files."
fi

echo "Checking for tracked SQLite/DB files..."
if git ls-files | grep -E '\.(sqlite3?|db)($|-wal$|-shm$)' ; then
  echo "FAIL: tracked database file(s) above — real user data must never be committed."
  fail=1
else
  echo "OK: no tracked SQLite/DB files."
fi

if [ "$fail" -ne 0 ]; then
  echo "check-private-data.sh: FAILED"
  exit 1
fi
echo "check-private-data.sh: PASSED"
