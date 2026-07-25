#!/bin/sh
# Tests for Scripts/check-legacy-brand-references.sh against a fixture tree.
# The property under test is the one that makes the gate worth having: an
# allowlist entry only counts if it carries a stated reason.
set -eu
cd "$(dirname "$0")/.."
GATE="$PWD/Scripts/check-legacy-brand-references.sh"

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

setup() {
  rm -rf "$FIXTURE"
  mkdir -p "$FIXTURE/Scripts" "$FIXTURE/Sources" "$FIXTURE/Documentation"
  cp "$GATE" "$FIXTURE/Scripts/check-legacy-brand-references.sh"
  echo "clean file, no old name here" > "$FIXTURE/Sources/Clean.swift"
}

# 1. A tree with no old-brand reference passes.
setup
CHECK_LEGACY_REFS_ROOT="$FIXTURE" sh "$FIXTURE/Scripts/check-legacy-brand-references.sh" >/tmp/clbr-1.out 2>&1 \
  || fail "gate failed on a tree with no old references: $(cat /tmp/clbr-1.out)"
grep -q "^OK — " /tmp/clbr-1.out || fail "no OK verdict on a clean tree"
echo "PASS: a tree with no pre-rename reference passes"

# 2. An old reference in a non-allowlisted file fails, and names the file.
setup
echo "let name = \"MacCareLocal\"" > "$FIXTURE/Sources/Leftover.swift"
set +e
CHECK_LEGACY_REFS_ROOT="$FIXTURE" sh "$FIXTURE/Scripts/check-legacy-brand-references.sh" >/tmp/clbr-2.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with an unexplained old reference"
grep -q "Sources/Leftover.swift" /tmp/clbr-2.out || fail "the offending file was not named"
echo "PASS: an unexplained pre-rename reference blocks the gate"

# 3. The same reference inside an allowlisted path passes — the allowlist is
#    what distinguishes a record from a leftover.
setup
mkdir -p "$FIXTURE/Documentation/RebrandHistory"
echo "the abandoned candidate was MacCareLocal" > "$FIXTURE/Documentation/RebrandHistory/notes.md"
CHECK_LEGACY_REFS_ROOT="$FIXTURE" sh "$FIXTURE/Scripts/check-legacy-brand-references.sh" >/tmp/clbr-3.out 2>&1 \
  || fail "gate failed on an allowlisted historical file: $(cat /tmp/clbr-3.out)"
echo "PASS: an allowlisted path with a stated reason passes"

# 4. Every allowlisted path in the real gate has a non-empty reason. A path
#    added without one would silently permit a leftover, which is exactly the
#    thing the gate exists to prevent.
#    allowed_reason() is not exported, so this asserts through the --list
#    output format: an allowlisted path prints as ALLOWED with its reason in
#    parentheses, and never with empty parentheses.
setup
mkdir -p "$FIXTURE/Documentation/RebrandHistory" "$FIXTURE/Release/Notes" "$FIXTURE/Sources/Persistence"
echo "MacCareLocal" > "$FIXTURE/Documentation/RebrandHistory/x.md"
echo "MacCareLocal" > "$FIXTURE/Documentation/PRE_REBRAND_BASELINE.md"
echo "MacCareLocal" > "$FIXTURE/Release/Notes/0.7.0.en.md"
echo "MacCareLocal" > "$FIXTURE/Sources/Persistence/LegacyDataMigration.swift"
CHECK_LEGACY_REFS_ROOT="$FIXTURE" sh "$FIXTURE/Scripts/check-legacy-brand-references.sh" --list >/tmp/clbr-4.out 2>&1
grep -q "UNKNOWN" /tmp/clbr-4.out && fail "a path that should be allowlisted reported as UNKNOWN"
if grep -E 'ALLOWED .*\(\)$' /tmp/clbr-4.out; then
  fail "an allowlisted path has an empty reason"
fi
grep -q "ALLOWED" /tmp/clbr-4.out || fail "--list printed no ALLOWED rows"
echo "PASS: every allowlisted path reports a non-empty reason"

# 5. --list is read-only and never fails the build, so it can be used to
#    inspect state without gating on it.
CHECK_LEGACY_REFS_ROOT="$FIXTURE" sh "$FIXTURE/Scripts/check-legacy-brand-references.sh" --list >/dev/null 2>&1 \
  || fail "--list exited non-zero"
echo "PASS: --list always exits 0"

echo
echo "All check-legacy-brand-references.sh tests passed."
