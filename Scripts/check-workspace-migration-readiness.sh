#!/bin/sh
# Gate: blocks the actual workspace migration (WORKSPACE_MIGRATION_PLAN.md
# Phase D) until every readiness precondition is real. Read-only — never
# moves, deletes, or creates anything itself; run
# Scripts/preflight-workspace-migration.sh separately to produce the
# backups this gate checks for.
set -eu
cd "${CHECK_WORKSPACE_READINESS_ROOT:-$(dirname "$0")/..}"

PRODUCT_PATH="${WORKSPACE_PRODUCT_PATH:-$PWD}"
PORTFOLIO_PATH="${WORKSPACE_PORTFOLIO_PATH:-$HOME/Documents/MAC_ORGANISE/00_DOCUMENTS_EXISTANTS/01_PROJETS/01_PROJETS_ACTIFS/WEBSITE/ahmetbsbnr-portfolio}"

fail=0
blockers=""
block() { fail=1; blockers="$blockers\n  - $1"; }

check_repo_clean_and_remote() {
  label="$1"; path="$2"
  if [ ! -d "$path/.git" ]; then
    block "$label repo not found or not a git repo at: $path"
    return
  fi
  if [ -n "$(cd "$path" && git status --short)" ]; then
    block "$label repo has an unclean working tree: $path"
  fi
  if [ -z "$(cd "$path" && git remote 2>/dev/null)" ]; then
    echo "NOTE: $label repo has no remote configured — recorded, not itself a blocker (matches this project's current no-remote state)"
  fi
  worktree_count=$(cd "$path" && git worktree list | wc -l | tr -d ' ')
  if [ "$worktree_count" -gt 1 ]; then
    block "$label repo has $worktree_count worktrees registered — an active external worktree must be removed or accounted for before moving the repo"
  fi
}

# 1 & 2. Both repos identified, clean, remotes recorded, no stray worktrees.
check_repo_clean_and_remote "Product" "$PRODUCT_PATH"
check_repo_clean_and_remote "Portfolio" "$PORTFOLIO_PATH"

# 3. Backups present (git bundle from preflight script).
if [ ! -d Documentation/WorkspacePreflight ] || [ -z "$(find Documentation/WorkspacePreflight -name '*.bundle' 2>/dev/null)" ]; then
  block "no workspace backup found — run Scripts/preflight-workspace-migration.sh --create-backups first"
fi

# 4. Disk space: require at least 5 GiB free on the volume backing $HOME
#    (both repos plus working copies are small; 5 GiB is a conservative
#    floor, not a tight measurement of actual repo size).
AVAIL_KB=$(df -k "$HOME" | tail -1 | awk '{print $4}')
AVAIL_GIB=$((AVAIL_KB / 1024 / 1024))
if [ "$AVAIL_GIB" -lt 5 ]; then
  block "only ${AVAIL_GIB}GiB free at \$HOME's volume — need at least 5GiB before migrating"
fi

# 5. No other worktree/process holding either repo open (best-effort: this
#    just re-confirms worktree count above; a running `swift build`/`next dev`
#    process cannot be reliably detected from a static check, so this is
#    explicitly a partial guarantee, not a full one).
echo "NOTE: process-level lock detection (e.g. a running 'next dev' or 'swift build') is not checked here — verify manually before migrating."

# 6. Target structure resolved.
if [ -f Documentation/workspace-migration-manifest.json ]; then
  PARENT=$(/usr/bin/python3 -c "import json; print(json.load(open('Documentation/workspace-migration-manifest.json')).get('workspaceParent',''))" 2>/dev/null || echo "")
  if [ -z "$PARENT" ] || [ "$PARENT" = "UNRESOLVED_BLOCKED_HUMAN" ]; then
    block "Documentation/workspace-migration-manifest.json's workspaceParent is still unresolved (BLOCKED_HUMAN)"
  fi
else
  block "Documentation/workspace-migration-manifest.json is missing"
fi

# 7. No unresolved brand-name conflict for the product slug the manifest names.
if [ -f Documentation/brand-name-clearance.json ]; then
  STATUS=$(/usr/bin/python3 -c "import json; print(json.load(open('Documentation/brand-name-clearance.json')).get('status',''))" 2>/dev/null || echo "")
  if [ "$STATUS" != "CLEAR_FOR_ENGINEERING" ]; then
    block "Documentation/brand-name-clearance.json status is '$STATUS', not CLEAR_FOR_ENGINEERING — the product slug this migration would use is not resolved"
  fi
else
  block "Documentation/brand-name-clearance.json is missing"
fi

# 8. Rollback plan exists.
[ -f Documentation/WORKSPACE_ROLLBACK_PLAN.md ] || block "Documentation/WORKSPACE_ROLLBACK_PLAN.md is missing"

# 9. Human approval recorded (same file the brand-clearance gate checks —
#    a workspace migration that includes renaming the product folder is
#    gated on the same human sign-off).
[ -f Configuration/BrandRenameApproval.local.json ] || block "Configuration/BrandRenameApproval.local.json is missing — no migration without recorded human approval"

echo "== check-workspace-migration-readiness.sh =="
if [ "$fail" -ne 0 ]; then
  printf 'BLOCKED — workspace migration may not proceed:%b\n' "$blockers"
  exit 1
fi
echo "READY — all workspace migration preconditions hold."
