#!/bin/sh
# Repo-hygiene checks for the open-source foundation: required policy files
# present, private-data scan clean, placeholder scan clean. Read-only.
# Safe to run from any working directory.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

fail=0

echo "MacCare Local — repository doctor"
echo "=================================="

echo "-- Required top-level policy files --"
for f in LICENSE NOTICE COPYRIGHT README.md SECURITY.md CODE_OF_CONDUCT.md CONTRIBUTING.md; do
  if [ -f "$f" ]; then
    echo "  OK: $f"
  else
    echo "  FAIL: missing $f"
    fail=1
  fi
done

echo "-- Required Documentation/ files --"
for f in Documentation/PUBLICATION_AUDIT.md Documentation/REPOSITORY_SANITIZATION.md \
         Documentation/ASSET_PROVENANCE.md Documentation/DEPENDENCIES.md; do
  if [ -f "$f" ]; then
    echo "  OK: $f"
  else
    echo "  FAIL: missing $f"
    fail=1
  fi
done

echo "-- Private-data scan --"
if [ -x Scripts/check-private-data.sh ]; then
  if Scripts/check-private-data.sh; then
    echo "  OK: check-private-data.sh passed"
  else
    echo "  FAIL: check-private-data.sh reported issues"
    fail=1
  fi
else
  echo "  WARN: Scripts/check-private-data.sh missing or not executable"
fi

echo "-- Placeholder scan --"
if [ -x Scripts/check-placeholders.sh ]; then
  if Scripts/check-placeholders.sh; then
    echo "  OK: check-placeholders.sh passed"
  else
    echo "  FAIL: check-placeholders.sh reported issues"
    fail=1
  fi
else
  echo "  WARN: Scripts/check-placeholders.sh missing or not executable"
fi

echo "-- .gitignore sanity: nothing tracked is newly ignored --"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
ignored_file="$tmp_dir/newly-ignored.txt"
git ls-files | git check-ignore --stdin >"$ignored_file" 2>/dev/null || true
if [ -s "$ignored_file" ]; then
  echo "  FAIL: tracked files match .gitignore patterns:"
  sed 's/^/    /' "$ignored_file"
  fail=1
else
  echo "  OK: no tracked file is ignored."
fi

echo "=================================="
if [ "$fail" -eq 0 ]; then
  echo "repository-doctor: all checks passed."
else
  echo "repository-doctor: one or more checks FAILED. See above."
fi
exit "$fail"
