#!/bin/sh
# Shell-level tests for Scripts/check-brand-clearance.sh, run against an
# isolated fixture root (never the real repo's own approval/clearance
# state) so this can exercise both the blocked and the fully-cleared path.
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
cat > "$FIXTURE/Configuration/BrandRenameApproval.local.json" <<'EOF'
{ "approvedName": "TestName", "approvedByHuman": false, "approvalDate": "2026-01-01", "legalReviewStatus": "accepted" }
EOF
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-2.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with approvedByHuman=false"
grep -q "approvedByHuman is not true" /tmp/cbc-test-2.out || fail "approvedByHuman blocker not reported"
echo "PASS: approvedByHuman=false blocks the gate"

# 3. Candidate name mismatch (approval file names a different product) blocks.
setup_fixture
cat > "$FIXTURE/Configuration/BrandRenameApproval.local.json" <<'EOF'
{ "approvedName": "SomeOtherName", "approvedByHuman": true, "approvalDate": "2026-01-01", "legalReviewStatus": "accepted" }
EOF
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-3.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed despite a candidate/approval name mismatch"
grep -q "does not match" /tmp/cbc-test-3.out || fail "name-mismatch blocker not reported"
echo "PASS: candidate name mismatch blocks the gate"

# 4. Missing clearance.json blocks even with a valid approval file.
setup_fixture
cat > "$FIXTURE/Configuration/BrandRenameApproval.local.json" <<'EOF'
{ "approvedName": "TestName", "approvedByHuman": true, "approvalDate": "2026-01-01", "legalReviewStatus": "accepted" }
EOF
set +e
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-4.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with no brand-name-clearance.json at all"
grep -q "brand-name-clearance.json is missing" /tmp/cbc-test-4.out || fail "missing-clearance-file blocker not reported"
echo "PASS: missing brand-name-clearance.json blocks the gate"

# 5. clearance.json present but status != CLEAR_FOR_ENGINEERING blocks.
setup_fixture
cat > "$FIXTURE/Configuration/BrandRenameApproval.local.json" <<'EOF'
{ "approvedName": "TestName", "approvedByHuman": true, "approvalDate": "2026-01-01", "legalReviewStatus": "accepted" }
EOF
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

# 6. FULLY CLEARED path: every precondition satisfied -> gate passes (exit 0).
setup_fixture
cat > "$FIXTURE/Configuration/BrandRenameApproval.local.json" <<'EOF'
{ "approvedName": "TestName", "approvedByHuman": true, "approvalDate": "2026-01-01", "legalReviewStatus": "accepted" }
EOF
cat > "$FIXTURE/Documentation/brand-name-clearance.json" <<'EOF'
{ "candidateName": "TestName", "status": "CLEAR_FOR_ENGINEERING" }
EOF
mkdir -p "$FIXTURE/Documentation/WorkspacePreflight/fixture-run"
: > "$FIXTURE/Documentation/WorkspacePreflight/fixture-run/product.bundle"
( cd "$FIXTURE" && git add -A && git commit -q -m "fully cleared fixture state" )
CHECK_BRAND_CLEARANCE_ROOT="$FIXTURE" "$GATE" TestName >/tmp/cbc-test-6.out 2>&1 \
  || fail "gate failed despite every precondition being satisfied: $(cat /tmp/cbc-test-6.out)"
grep -q "^CLEAR — " /tmp/cbc-test-6.out || fail "gate didn't print the CLEAR verdict on the fully-satisfied path"
echo "PASS: gate passes (exit 0) only when every precondition is genuinely satisfied"

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

echo
echo "All check-brand-clearance.sh tests passed."
