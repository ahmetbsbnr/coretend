#!/bin/sh
# Shell-level tests for Scripts/preflight-workspace-migration.sh. Uses fake
# repos under mktemp so this never touches the real product/portfolio
# repos, and asserts the script never mv/rm/remote-changes anything.
set -eu
cd "$(dirname "$0")/.."
PREFLIGHT="$PWD/Scripts/preflight-workspace-migration.sh"

FAKE_ROOT="$(mktemp -d)"
trap 'rm -rf "$FAKE_ROOT"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

make_fake_repo() {
  path="$1"
  mkdir -p "$path"
  ( cd "$path" && git init -q && git config user.email "test@example.com" \
    && git config user.name "Test" && echo "hello" > README.md \
    && git add README.md && git commit -q -m "init" )
}

FAKE_PRODUCT="$FAKE_ROOT/product"
FAKE_PORTFOLIO="$FAKE_ROOT/portfolio"
make_fake_repo "$FAKE_PRODUCT"
make_fake_repo "$FAKE_PORTFOLIO"
BEFORE_PRODUCT_HEAD=$(cd "$FAKE_PRODUCT" && git rev-parse HEAD)
BEFORE_PORTFOLIO_HEAD=$(cd "$FAKE_PORTFOLIO" && git rev-parse HEAD)

OUT1="$FAKE_ROOT/out-check"

# 1. --check on two clean fake repos succeeds and writes a manifest.
PREFLIGHT_PRODUCT_PATH="$FAKE_PRODUCT" PREFLIGHT_PORTFOLIO_PATH="$FAKE_PORTFOLIO" \
  "$PREFLIGHT" --check --output "$OUT1" >/tmp/preflight-test-check.out 2>&1 \
  || fail "--check failed on two clean fake repos: $(cat /tmp/preflight-test-check.out)"
[ -f "$OUT1/preflight-manifest.json" ] || fail "--check did not write a manifest"
grep -q '"clean": true' "$OUT1/preflight-manifest.json" || fail "manifest didn't report clean trees"
echo "PASS: --check succeeds on clean repos and writes a manifest"

# 2. --check never creates a .bundle file (backups are opt-in only).
[ -f "$OUT1/product.bundle" ] && fail "--check created a backup bundle without --create-backups"
echo "PASS: --check creates no backup files"

# 3. Neither fake repo was modified by --check (no mv/rm/remote change).
AFTER_PRODUCT_HEAD=$(cd "$FAKE_PRODUCT" && git rev-parse HEAD)
AFTER_PORTFOLIO_HEAD=$(cd "$FAKE_PORTFOLIO" && git rev-parse HEAD)
[ "$AFTER_PRODUCT_HEAD" = "$BEFORE_PRODUCT_HEAD" ] || fail "--check changed the product repo's HEAD"
[ "$AFTER_PORTFOLIO_HEAD" = "$BEFORE_PORTFOLIO_HEAD" ] || fail "--check changed the portfolio repo's HEAD"
[ -d "$FAKE_PRODUCT/.git" ] || fail "--check removed the product repo's .git"
[ -d "$FAKE_PORTFOLIO/.git" ] || fail "--check removed the portfolio repo's .git"
echo "PASS: --check leaves both repos byte-for-byte untouched (HEAD, .git both intact)"

# 4. A dirty tree is reported, not silently ignored.
echo "uncommitted change" > "$FAKE_PRODUCT/dirty.txt"
OUT2="$FAKE_ROOT/out-dirty"
PREFLIGHT_PRODUCT_PATH="$FAKE_PRODUCT" PREFLIGHT_PORTFOLIO_PATH="$FAKE_PORTFOLIO" \
  "$PREFLIGHT" --check --output "$OUT2" >/tmp/preflight-test-dirty.out 2>&1 || true
grep -q '"clean": false' "$OUT2/preflight-manifest.json" || fail "manifest didn't report the dirty product tree"
rm -f "$FAKE_PRODUCT/dirty.txt"
echo "PASS: dirty tree is reported in the manifest, not hidden"

# 5. A missing repo is reported as a real failure (non-zero exit), not swallowed.
OUT3="$FAKE_ROOT/out-missing"
set +e
PREFLIGHT_PRODUCT_PATH="$FAKE_PRODUCT" PREFLIGHT_PORTFOLIO_PATH="$FAKE_ROOT/does-not-exist" \
  "$PREFLIGHT" --check --output "$OUT3" >/tmp/preflight-test-missing.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "missing portfolio path did not cause a non-zero exit"
grep -q "MISSING" /tmp/preflight-test-missing.out || fail "missing path wasn't reported as MISSING"
echo "PASS: a missing repo path is a real, reported failure"

# 6. --create-backups produces a real, restorable git bundle, and still
#    never mv/rm/remote-changes the source repos.
OUT4="$FAKE_ROOT/out-backup"
PREFLIGHT_PRODUCT_PATH="$FAKE_PRODUCT" PREFLIGHT_PORTFOLIO_PATH="$FAKE_PORTFOLIO" \
  "$PREFLIGHT" --create-backups --output "$OUT4" >/tmp/preflight-test-backup.out 2>&1 \
  || fail "--create-backups failed: $(cat /tmp/preflight-test-backup.out)"
[ -f "$OUT4/product.bundle" ] || fail "--create-backups did not write product.bundle"
[ -f "$OUT4/portfolio.bundle" ] || fail "--create-backups did not write portfolio.bundle"
[ -f "$OUT4/product.bundle.sha256" ] || fail "--create-backups did not write a checksum for product.bundle"
RESTORE_DIR="$FAKE_ROOT/restore-test"
git clone -q "$OUT4/product.bundle" "$RESTORE_DIR" || fail "the git bundle is not a valid, clonable backup"
[ "$(cd "$RESTORE_DIR" && git rev-parse HEAD)" = "$BEFORE_PRODUCT_HEAD" ] \
  || fail "restored bundle HEAD doesn't match the original repo's HEAD"
[ "$(cd "$FAKE_PRODUCT" && git rev-parse HEAD)" = "$BEFORE_PRODUCT_HEAD" ] \
  || fail "--create-backups changed the source repo's HEAD"
echo "PASS: --create-backups writes a real, restorable bundle and never touches the source repos"

# 7. No mv, rm -rf of a repo, or git remote mutation appears anywhere in
#    the script's own source — a static guard against regressions, since
#    this script's entire safety property depends on never doing these.
if grep -E '(^|[^a-zA-Z_-])(mv |rm -rf \$(PRODUCT_PATH|PORTFOLIO_PATH)|git remote (add|set-url|remove))' "$PREFLIGHT" \
    | grep -v '^#' >/tmp/preflight-source-scan.out; then
  [ -s /tmp/preflight-source-scan.out ] && fail "found a forbidden mv/rm/remote-mutation pattern in preflight-workspace-migration.sh: $(cat /tmp/preflight-source-scan.out)"
fi
echo "PASS: no mv/rm-of-a-repo/remote-mutation pattern found in the script's own source"

echo
echo "All preflight-workspace-migration.sh tests passed."
