#!/bin/sh
# Shell-level tests for Scripts/check-brand-clearance.sh, run against an
# isolated fixture root (never the real repo's own approval/clearance
# state) so this can exercise both the blocked and the fully-cleared path,
# in both --engineering and --publication mode.
set -eu
cd "$(dirname "$0")/.."
GATE="$PWD/Scripts/check-brand-clearance.sh"

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

setup_fixture() {
  rm -rf "$FIXTURE"
  mkdir -p "$FIXTURE/Documentation" "$FIXTURE/Configuration" "$FIXTURE/Scripts"
  ( cd "$FIXTURE" && git init -q && git config user.email "t@example.com" && git config user.name "T" )
  # A stub test.sh that always passes instantly, so this test doesn't
  # depend on the real Swift suite.
  cat > "$FIXTURE/Scripts/test.sh" <<'EOF'
#!/bin/sh
echo "stub tests passed"
exit 0
EOF
  chmod +x "$FIXTURE/Scripts/test.sh"
  cat > "$FIXTURE/Documentation/BRAND_SEARCH_EVIDENCE.md" <<'EOF'
# stub
EOF
  cat > "$FIXTURE/Documentation/BRAND_CONFLICT_REGISTER.md" <<'EOF'
# stub register, no entries
EOF
  cat > "$FIXTURE/Documentation/BRAND_NAME_CLEARANCE.md" <<'EOF'
# stub
EOF
  cat > "$FIXTURE/Documentation/PRODUCT_RENAME_ROLLBACK.md" <<'EOF'
# stub
EOF
  ( cd "$FIXTURE" && git add -A && git commit -q -m "fixture init" )
}

# Writes an approval file. $1 = approvedName, $2 = approvedByHuman,
# $3 = engineeringRenameApproved, $4 = legalReviewStatus,
# $5 = publicReleaseAllowed.
write_approval() {
  cat > "$FIXTURE/Configuration/BrandRenameApproval.local.json" <<EOF
{
  "approvedName": "$1",
  "approvedByHuman": $2,
  "engineeringRenameApproved": $3,
  "approvalDate": "2026-01-01",
  "legalReviewStatus": "$4",
  "publicReleaseAllowed": $5
}
EOF
}

# Brings a fixture to the state where every non-approval precondition holds.
satisfy_everything_else() {
  cat > "$FIXTURE/Documentation/brand-name-clearance.json" <<'EOF'
{ "candidateName": "TestName", "status": "CLEAR_FOR_ENGINEERING" }
EOF
  mkdir -p "$FIXTURE/Documentation/WorkspacePreflight/fixture-run"
  : > "$FIXTURE/Documentation/WorkspacePreflight/fixture-run/product.bundle"
  ( cd "$FIXTURE" && git add -A && git commit -q -m "cleared fixture state" )
}

# 1. Missing approval file blocks, exit non-zero.
setup_fixture
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-1.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with no approval file at all"
grep -q "BrandRenameApproval.local.json does not exist" /tmp/cbc-test-1.out || fail "missing-approval-file blocker not reported"
echo "PASS: missing approval file blocks the gate"

# 2. Approval file present but approvedByHuman=false blocks.
setup_fixture
write_approval TestName false true accepted true
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-2.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with approvedByHuman=false"
grep -q "approvedByHuman is not true" /tmp/cbc-test-2.out || fail "approvedByHuman blocker not reported"
echo "PASS: approvedByHuman=false blocks the gate"

# 3. Candidate name mismatch (approval file names a different product) blocks.
setup_fixture
write_approval SomeOtherName true true accepted true
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-3.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed despite a candidate/approval name mismatch"
grep -q "does not match" /tmp/cbc-test-3.out || fail "name-mismatch blocker not reported"
echo "PASS: candidate name mismatch blocks the gate"

# 4. Missing clearance.json blocks even with a valid approval file.
setup_fixture
write_approval TestName true true accepted true
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-4.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with no brand-name-clearance.json at all"
grep -q "brand-name-clearance.json is missing" /tmp/cbc-test-4.out || fail "missing-clearance-file blocker not reported"
echo "PASS: missing brand-name-clearance.json blocks the gate"

# 5. clearance.json present but status != CLEAR_FOR_ENGINEERING blocks.
setup_fixture
write_approval TestName true true accepted true
cat > "$FIXTURE/Documentation/brand-name-clearance.json" <<'EOF'
{ "candidateName": "TestName", "status": "CONFLICT_HIGH" }
EOF
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-5.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with a CONFLICT_HIGH status"
grep -q "not CLEAR_FOR_ENGINEERING" /tmp/cbc-test-5.out || fail "non-CLEAR status blocker not reported"
echo "PASS: a non-CLEAR_FOR_ENGINEERING status blocks the gate"

# 6. FULLY CLEARED path: every precondition satisfied -> both modes pass.
setup_fixture
write_approval TestName true true accepted true
satisfy_everything_else
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-6.out 2>&1 \
  || fail "engineering gate failed despite every precondition being satisfied: $(cat /tmp/cbc-test-6.out)"
grep -q "^CLEAR — " /tmp/cbc-test-6.out || fail "gate didn't print the CLEAR verdict on the fully-satisfied path"
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" --publication TestName >/tmp/cbc-test-6b.out 2>&1 \
  || fail "publication gate failed despite every precondition being satisfied: $(cat /tmp/cbc-test-6b.out)"
grep -q "^CLEAR — all publication preconditions" /tmp/cbc-test-6b.out || fail "publication mode didn't report its own verdict"
echo "PASS: both gates pass (exit 0) only when every precondition is genuinely satisfied"

# 7. Dirty tree still blocks even when everything else is satisfied.
echo "uncommitted" > "$FIXTURE/dirty.txt"
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-7.out 2>&1
rc=$?
set -e
rm -f "$FIXTURE/dirty.txt"
[ "$rc" -ne 0 ] || fail "gate passed with an uncommitted change present"
grep -q "working tree is not clean" /tmp/cbc-test-7.out || fail "dirty-tree blocker not reported"
echo "PASS: a dirty tree blocks the gate even when every other precondition holds"

# 8. engineeringRenameApproved=false blocks BOTH modes — the engineering
#    flag is a floor, not an alternative to the publication flags.
setup_fixture
write_approval TestName true false accepted true
satisfy_everything_else
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-8.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "engineering gate passed with engineeringRenameApproved=false"
grep -q "engineeringRenameApproved is not true" /tmp/cbc-test-8.out || fail "engineeringRenameApproved blocker not reported"
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" --publication TestName >/tmp/cbc-test-8b.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "publication gate passed with engineeringRenameApproved=false"
echo "PASS: engineeringRenameApproved=false blocks both modes"

# 9. THE SPLIT: pending legal review clears engineering but blocks publication.
#    This is the whole point of the two-gate design — a local rename is
#    allowed while the name is still legally unreviewed, publication is not.
setup_fixture
write_approval TestName true true pending false
satisfy_everything_else
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-9.out 2>&1 \
  || fail "engineering gate blocked on a pending legal review, which it must not: $(cat /tmp/cbc-test-9.out)"
grep -q "^CLEAR — all engineering preconditions" /tmp/cbc-test-9.out || fail "engineering mode didn't report CLEAR with legal review pending"
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" --publication TestName >/tmp/cbc-test-9b.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "publication gate passed with legalReviewStatus=pending"
grep -q "legalReviewStatus is 'pending'" /tmp/cbc-test-9b.out || fail "pending-legal-review blocker not reported"
grep -q "publicReleaseAllowed is not true" /tmp/cbc-test-9b.out || fail "publicReleaseAllowed blocker not reported"
echo "PASS: pending legal review clears engineering and blocks publication"

# 10. legalReviewStatus=accepted but publicReleaseAllowed=false still blocks
#     publication — the two publication flags are ANDed, not ORed.
setup_fixture
write_approval TestName true true accepted false
satisfy_everything_else
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" --publication TestName >/tmp/cbc-test-10.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "publication gate passed with publicReleaseAllowed=false"
grep -q "publicReleaseAllowed is not true" /tmp/cbc-test-10.out || fail "publicReleaseAllowed blocker not reported"
echo "PASS: publication needs BOTH legal acceptance and an explicit release allowance"

# 11. Conflict-register status vocabulary.
#
# The register distinguishes entries that bar the name from entries that merely
# record a condition for a later step. All three arms are asserted here, because
# the risk of a softer token is precisely that it stops blocking things it should
# block.

# 11a. A BLOCKING entry naming the candidate must block.
setup_fixture
write_approval TestName true true accepted true
satisfy_everything_else
cat > "$FIXTURE/Documentation/BRAND_CONFLICT_REGISTER.md" <<'EOF'
# register
| BC-900 | TestName clashes with a shipped product of the same name | HIGH | **BLOCKING** |
EOF
( cd "$FIXTURE" && git add -A && git commit -q -m "blocking entry" )
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-11a.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed despite a BLOCKING register entry naming the candidate"
grep -q "BLOCKING/OPEN entry naming" /tmp/cbc-test-11a.out || fail "BLOCKING entry not reported"
echo "PASS: a BLOCKING register entry blocks the gate"

# 11b. The legacy OPEN token must keep its force, so pre-existing rows still bar.
setup_fixture
write_approval TestName true true accepted true
satisfy_everything_else
cat > "$FIXTURE/Documentation/BRAND_CONFLICT_REGISTER.md" <<'EOF'
# register
| BC-901 | TestName unresolved prior use | HIGH | **OPEN** |
EOF
( cd "$FIXTURE" && git add -A && git commit -q -m "legacy open entry" )
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-11b.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed despite a legacy OPEN register entry naming the candidate"
echo "PASS: the legacy OPEN token still blocks the gate"

# 11c. A WATCH entry must NOT block, but must be surfaced on stdout.
setup_fixture
write_approval TestName true true accepted true
satisfy_everything_else
cat > "$FIXTURE/Documentation/BRAND_CONFLICT_REGISTER.md" <<'EOF'
# register
| BC-902 | TestName adjacent mark, unrelated industry | WATCH | **WATCH.** Condition: attorney review before commercial use. |
EOF
( cd "$FIXTURE" && git add -A && git commit -q -m "watch entry" )
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-11c.out 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "a WATCH entry blocked the gate; it must only be surfaced (see /tmp/cbc-test-11c.out)"
grep -q "WATCH entry/entries name" /tmp/cbc-test-11c.out || fail "WATCH entry was silently ignored instead of surfaced"
echo "PASS: a WATCH entry does not block but is surfaced"

echo
echo "All check-brand-clearance.sh tests passed."
