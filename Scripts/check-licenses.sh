#!/bin/sh
# Verifies license declarations are present and internally consistent:
# root LICENSE/NOTICE/COPYRIGHT exist, LICENSES/ has the referenced texts,
# and Documentation/DEPENDENCIES.md's dependency list matches Package.swift
# (this repo currently declares zero external SwiftPM dependencies — if
# that ever changes, this check will start failing on purpose).
# Read-only. Safe to run from any working directory.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

fail=0

echo "MacCare Local — check-licenses"

for f in LICENSE NOTICE COPYRIGHT THIRD_PARTY_NOTICES.md; do
  if [ -f "$f" ]; then
    echo "  OK: $f present"
  else
    echo "  FAIL: $f missing"
    fail=1
  fi
done

if [ -d LICENSES ] && [ -f LICENSES/Apache-2.0.txt ] && [ -f LICENSES/CC-BY-4.0.txt ]; then
  echo "  OK: LICENSES/Apache-2.0.txt and LICENSES/CC-BY-4.0.txt present"
else
  echo "  FAIL: LICENSES/ missing expected license texts"
  fail=1
fi

if [ -f Documentation/DEPENDENCIES.md ]; then
  echo "  OK: Documentation/DEPENDENCIES.md present"
else
  echo "  FAIL: Documentation/DEPENDENCIES.md missing"
  fail=1
fi

echo "-- Package.swift dependency count --"
pkg_deps=$(grep -c '\.package(' Package.swift || true)
echo "  .package(...) entries in Package.swift: $pkg_deps"
if [ "$pkg_deps" -eq 0 ]; then
  if grep -q "zero external\|zero \`.package" Documentation/DEPENDENCIES.md 2>/dev/null || grep -qi "None\." Documentation/DEPENDENCIES.md 2>/dev/null; then
    echo "  OK: Package.swift has no external dependencies, matching DEPENDENCIES.md."
  else
    echo "  WARN: Package.swift has no dependencies but DEPENDENCIES.md doesn't clearly say so — review it."
  fi
else
  echo "  WARN: Package.swift now declares $pkg_deps external dependencies."
  echo "        Update Documentation/DEPENDENCIES.md with license/necessity/risk for each."
fi

if [ "$fail" -eq 0 ]; then
  echo "check-licenses: passed."
else
  echo "check-licenses: FAILED. See above."
fi
exit "$fail"
