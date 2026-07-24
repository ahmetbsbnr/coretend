#!/bin/sh
# Shell-level tests for Scripts/check-workspace-migration-readiness.sh,
# run against an isolated fixture root so this never touches the real
# repo's own state.
set -eu
cd "$(dirname "$0")/.."
GATE="$PWD/Scripts/check-workspace-migration-readiness.sh"

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

make_clean_repo() {
  path="$1"
  mkdir -p "$path"
  ( cd "$path" && git init -q && git config user.email "t@example.com" && git config user.name "T" \
    && echo hi > README.md && git add README.md && git commit -q -m init )
}

setup_fixture() {
  rm -rf "$FIXTURE"
  mkdir -p "$FIXTURE/Documentation" "$FIXTURE/Configuration"
  ( cd "$FIXTURE" && git init -q && git config user.email "t@example.com" && git config user.name "T" )
  make_clean_repo "$FIXTURE/product-repo"
  make_clean_repo "$FIXTURE/portfolio-repo"
}

# 1. Everything missing -> blocked.
setup_fixture
set +e
CHECK_WORKSPACE_READINESS_ROOT="$FIXTURE" WORKSPACE_PRODUCT_PATH="$FIXTURE/product-repo" \
  WORKSPACE_PORTFOLIO_PATH="$FIXTURE/portfolio-repo" "$GATE" >/tmp/cwr-test-1.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with nothing in place"
grep -q "no workspace backup found" /tmp/cwr-test-1.out || fail "missing-backup blocker not reported"
grep -q "workspace-migration-manifest.json is missing" /tmp/cwr-test-1.out || fail "missing-manifest blocker not reported"
echo "PASS: gate blocks when nothing is in place"

# 2. Dirty product repo blocks even if other things are fixed up.
setup_fixture
echo "uncommitted" > "$FIXTURE/product-repo/dirty.txt"
set +e
CHECK_WORKSPACE_READINESS_ROOT="$FIXTURE" WORKSPACE_PRODUCT_PATH="$FIXTURE/product-repo" \
  WORKSPACE_PORTFOLIO_PATH="$FIXTURE/portfolio-repo" "$GATE" >/tmp/cwr-test-2.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with a dirty product repo"
grep -q "Product repo has an unclean working tree" /tmp/cwr-test-2.out || fail "dirty-repo blocker not reported"
echo "PASS: a dirty repo blocks the gate"

# 3. Fully satisfied path -> gate passes (exit 0).
setup_fixture
mkdir -p "$FIXTURE/Documentation/WorkspacePreflight/run1"
: > "$FIXTURE/Documentation/WorkspacePreflight/run1/product.bundle"
cat > "$FIXTURE/Documentation/workspace-migration-manifest.json" <<'EOF'
{ "workspaceParent": "/tmp/some-resolved-parent" }
EOF
cat > "$FIXTURE/Documentation/brand-name-clearance.json" <<'EOF'
{ "status": "CLEAR_FOR_ENGINEERING" }
EOF
cat > "$FIXTURE/Documentation/WORKSPACE_ROLLBACK_PLAN.md" <<'EOF'
# stub
EOF
cat > "$FIXTURE/Configuration/BrandRenameApproval.local.json" <<'EOF'
{ "approvedName": "TestName", "approvedByHuman": true, "legalReviewStatus": "accepted" }
EOF
CHECK_WORKSPACE_READINESS_ROOT="$FIXTURE" WORKSPACE_PRODUCT_PATH="$FIXTURE/product-repo" \
  WORKSPACE_PORTFOLIO_PATH="$FIXTURE/portfolio-repo" "$GATE" >/tmp/cwr-test-3.out 2>&1 \
  || fail "gate failed despite every precondition satisfied: $(cat /tmp/cwr-test-3.out)"
grep -q "^READY — " /tmp/cwr-test-3.out || fail "gate didn't print the READY verdict on the fully-satisfied path"
echo "PASS: gate passes (exit 0) only when every precondition is genuinely satisfied"

# 4. A stray extra worktree on the product repo blocks.
setup_fixture
mkdir -p "$FIXTURE/Documentation/WorkspacePreflight/run1"
: > "$FIXTURE/Documentation/WorkspacePreflight/run1/product.bundle"
cat > "$FIXTURE/Documentation/workspace-migration-manifest.json" <<'EOF'
{ "workspaceParent": "/tmp/some-resolved-parent" }
EOF
cat > "$FIXTURE/Documentation/brand-name-clearance.json" <<'EOF'
{ "status": "CLEAR_FOR_ENGINEERING" }
EOF
cat > "$FIXTURE/Documentation/WORKSPACE_ROLLBACK_PLAN.md" <<'EOF'
# stub
EOF
cat > "$FIXTURE/Configuration/BrandRenameApproval.local.json" <<'EOF'
{ "approvedName": "TestName", "approvedByHuman": true, "legalReviewStatus": "accepted" }
EOF
( cd "$FIXTURE/product-repo" && git worktree add -q -b extra-branch "$FIXTURE/extra-worktree" )
set +e
CHECK_WORKSPACE_READINESS_ROOT="$FIXTURE" WORKSPACE_PRODUCT_PATH="$FIXTURE/product-repo" \
  WORKSPACE_PORTFOLIO_PATH="$FIXTURE/portfolio-repo" "$GATE" >/tmp/cwr-test-4.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with a stray extra worktree registered"
grep -q "worktrees registered" /tmp/cwr-test-4.out || fail "extra-worktree blocker not reported"
echo "PASS: a stray extra worktree blocks the gate"

echo
echo "All check-workspace-migration-readiness.sh tests passed."
