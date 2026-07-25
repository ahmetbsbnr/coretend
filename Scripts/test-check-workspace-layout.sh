#!/bin/sh
# Tests for Scripts/check-workspace-layout.sh, against fixture workspaces.
# A gate that has only ever been seen passing is a gate nobody has tested.
set -eu
cd "$(dirname "$0")/.."
GATE="$PWD/Scripts/check-workspace-layout.sh"

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# Builds a valid workspace: two independent repos plus the expected folders.
build_workspace() {
  root="$1"
  rm -rf "$root"
  mkdir -p "$root/products/coretend/app" "$root/ahmetbsbnr-portfolio" \
           "$root/products/coretend/website" "$root/products/coretend/documentation" \
           "$root/products/coretend/release" "$root/projects" \
           "$root/shared/design-language" "$root/shared/brand-assets" \
           "$root/shared/deployment-docs"
  echo "# workspace" > "$root/WORKSPACE.md"
  for r in "$root/products/coretend/app" "$root/ahmetbsbnr-portfolio"; do
    ( cd "$r" && git init -q && git config user.email t@example.com && git config user.name T \
      && echo x > f.txt && git add -A && git commit -q -m init )
  done
}

W="$FIXTURE/WEBSITE"

# 1. A valid workspace passes.
build_workspace "$W"
CHECK_WORKSPACE_ROOT="$W" "$GATE" >/tmp/cwl-1.out 2>&1 \
  || fail "gate rejected a valid workspace: $(cat /tmp/cwl-1.out)"
grep -q "^OK — " /tmp/cwl-1.out || fail "no OK verdict on the valid workspace"
echo "PASS: a valid workspace passes"

# 2. A git repository at the workspace root is the worst case and must fail.
build_workspace "$W"
( cd "$W" && git init -q )
set +e
CHECK_WORKSPACE_ROOT="$W" "$GATE" >/tmp/cwl-2.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with a git repository at the workspace root"
grep -q "must never be a git repository" /tmp/cwl-2.out || fail "root-repo blocker not reported"
echo "PASS: a repository at the workspace root blocks the gate"

# 3. A missing repository fails.
build_workspace "$W"
rm -rf "$W/ahmetbsbnr-portfolio"
set +e
CHECK_WORKSPACE_ROOT="$W" "$GATE" >/tmp/cwl-3.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with the portfolio repository missing"
grep -q "portfolio repository missing" /tmp/cwl-3.out || fail "missing-repo blocker not reported"
echo "PASS: a missing repository blocks the gate"

# 4. A directory that exists but is not a repository fails — this is what a
#    re-clone-gone-wrong or an over-eager cleanup actually looks like.
build_workspace "$W"
rm -rf "$W/ahmetbsbnr-portfolio/.git"
set +e
CHECK_WORKSPACE_ROOT="$W" "$GATE" >/tmp/cwl-4.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with a portfolio directory that has no .git"
grep -q "has no .git" /tmp/cwl-4.out || fail "not-a-repo blocker not reported"
echo "PASS: a directory without .git blocks the gate"

# 5. Missing workspace subdirectories fail.
build_workspace "$W"
rm -rf "$W/shared/design-language"
set +e
CHECK_WORKSPACE_ROOT="$W" "$GATE" >/tmp/cwl-5.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "gate passed with shared/design-language missing"
grep -q "missing workspace directory: shared/design-language" /tmp/cwl-5.out \
  || fail "missing-directory blocker not reported"
echo "PASS: a missing workspace directory blocks the gate"

echo
echo "All check-workspace-layout.sh tests passed."
