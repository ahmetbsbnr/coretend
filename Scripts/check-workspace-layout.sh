#!/bin/sh
# Gate: the WEBSITE workspace holds two independent repositories, and the
# invariants that keep them independent are easy to break by accident.
#
# Checks, in order of how bad the failure would be:
#   1. WEBSITE/ is not itself a git repository. A repo above two repos makes
#      git silently ignore the inner ones — the fastest way to lose track of
#      which history is real.
#   2. Both repositories exist at their expected paths with their own .git.
#   3. Neither repository's .git is shared with, or nested inside, the other.
#   4. No tracked file in this repository reaches outside its own root by
#      relative path. Such a path builds only on a machine where this exact
#      folder layout happens to exist, so a fresh clone would fail.
#   5. The expected workspace subdirectories exist.
#
# Passing means the workspace can be reorganised, backed up, or cloned
# elsewhere without either project quietly depending on the other's location.
#
# Usage: Scripts/check-workspace-layout.sh
#   CHECK_WORKSPACE_ROOT can override the workspace root (used by tests).
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
# app -> coretend -> products -> WEBSITE
WORKSPACE_ROOT="${CHECK_WORKSPACE_ROOT:-$(cd "$REPO_ROOT/../../.." && pwd)}"

PRODUCT_PATH="$WORKSPACE_ROOT/products/coretend/app"
PORTFOLIO_PATH="$WORKSPACE_ROOT/ahmetbsbnr-portfolio"

fail=0
problems=""
note() { fail=1; problems="$problems\n  - $1"; }

echo "== check-workspace-layout.sh: $WORKSPACE_ROOT =="

# 1. The workspace root must not be a git repository.
if [ -e "$WORKSPACE_ROOT/.git" ]; then
  note "$WORKSPACE_ROOT/.git exists — the workspace root must never be a git repository (see WORKSPACE.md)"
fi

# 2. Both repositories present, each with its own .git.
for pair in "product:$PRODUCT_PATH" "portfolio:$PORTFOLIO_PATH"; do
  name="${pair%%:*}"
  path="${pair#*:}"
  if [ ! -d "$path" ]; then
    note "$name repository missing at $path"
  elif [ ! -e "$path/.git" ]; then
    note "$name at $path has no .git — it is not a repository"
  fi
done

# 3. The two repositories must be genuinely separate.
if [ -e "$PRODUCT_PATH/.git" ] && [ -e "$PORTFOLIO_PATH/.git" ]; then
  # --absolute-git-dir, not --git-dir: the latter prints a bare ".git" for a
  # repository you are standing in, which would compare equal for any two
  # repositories and report a merged history that isn't there.
  product_dir=$(git -C "$PRODUCT_PATH" rev-parse --absolute-git-dir 2>/dev/null || echo "")
  portfolio_dir=$(git -C "$PORTFOLIO_PATH" rev-parse --absolute-git-dir 2>/dev/null || echo "")
  product_top=$(git -C "$PRODUCT_PATH" rev-parse --show-toplevel 2>/dev/null || echo "")
  portfolio_top=$(git -C "$PORTFOLIO_PATH" rev-parse --show-toplevel 2>/dev/null || echo "")

  [ -n "$product_dir" ] || note "product repository is not readable by git"
  [ -n "$portfolio_dir" ] || note "portfolio repository is not readable by git"

  if [ -n "$product_dir" ] && [ "$product_dir" = "$portfolio_dir" ]; then
    note "both paths resolve to the same git directory ($product_dir) — the histories have been merged"
  fi
  # A repository whose toplevel is not its own directory is nested inside
  # another one, which is check 1's failure in a different disguise.
  if [ -n "$product_top" ] && [ "$product_top" != "$(cd "$PRODUCT_PATH" && pwd -P)" ]; then
    note "product repository's git toplevel is $product_top, not its own directory — it is nested in another repository"
  fi
  if [ -n "$portfolio_top" ] && [ "$portfolio_top" != "$(cd "$PORTFOLIO_PATH" && pwd -P)" ]; then
    note "portfolio repository's git toplevel is $portfolio_top, not its own directory — it is nested in another repository"
  fi
fi

# 4. No tracked file may reach outside this repository's own root.
# Matches ../.. sequences deep enough to escape (three or more levels), and
# any absolute reference to the workspace root itself.
#
# The two workspace maintenance scripts are exempt: inspecting both
# repositories is their entire purpose, and each takes the other repository's
# path as an overridable environment default rather than a build-time
# dependency, so a fresh clone still builds without that path existing.
if [ -d "$REPO_ROOT/.git" ]; then
  escapes=$(git -C "$REPO_ROOT" grep -n -E '(\.\./){3,}|/01_PROJETS_ACTIFS/WEBSITE/' -- \
    ':!Documentation/*' \
    ':!Scripts/check-workspace-layout.sh' \
    ':!Scripts/preflight-workspace-migration.sh' \
    ':!Scripts/check-workspace-migration-readiness.sh' 2>/dev/null || true)
  if [ -n "$escapes" ]; then
    note "tracked files reference a path outside this repository root (a fresh clone would not build):
$escapes"
  fi
fi

# 5. Expected workspace subdirectories.
for d in products/coretend/website products/coretend/documentation products/coretend/release \
         projects shared/design-language shared/brand-assets shared/deployment-docs; do
  [ -d "$WORKSPACE_ROOT/$d" ] || note "missing workspace directory: $d"
done
[ -f "$WORKSPACE_ROOT/WORKSPACE.md" ] || note "missing $WORKSPACE_ROOT/WORKSPACE.md"

if [ "$fail" -ne 0 ]; then
  printf 'FAIL — workspace invariants broken:%b\n' "$problems"
  exit 1
fi
echo "OK — two independent repositories, no repository above them, no path escaping either root."
