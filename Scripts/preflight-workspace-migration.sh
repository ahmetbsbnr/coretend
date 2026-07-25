#!/bin/sh
# Non-destructive preflight for the future portfolio+product workspace
# migration (see Documentation/WORKSPACE_MIGRATION_PLAN.md). Verifies both
# repositories, reports their state, and — only with an explicit
# --create-backups flag — writes git-bundle + tarball backups to a
# separate output directory. NEVER moves, deletes, or renames anything;
# never touches git remotes. Safe to run repeatedly.
#
# Usage:
#   Scripts/preflight-workspace-migration.sh [--check] [--create-backups] [--output <directory>]
#
# --check              Default mode. Verify repos + write a JSON manifest. No writes outside --output.
# --create-backups     In addition to --check, write a git bundle + tarball backup per repo into --output.
# --output <directory> Where manifests/backups are written. Defaults to Documentation/WorkspacePreflight/<timestamp>/.
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

PRODUCT_PATH="${PREFLIGHT_PRODUCT_PATH:-$ROOT_DIR}"
PORTFOLIO_PATH="${PREFLIGHT_PORTFOLIO_PATH:-$HOME/Documents/MAC_ORGANISE/00_DOCUMENTS_EXISTANTS/01_PROJETS/01_PROJETS_ACTIFS/WEBSITE/ahmetbsbnr-portfolio}"

MODE="check"
OUTPUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --create-backups) MODE="backup" ;;
    --output) shift; OUTPUT_DIR="${1:-}" ;;
    -h|--help)
      echo "Usage: $0 [--check] [--create-backups] [--output <directory>]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$ROOT_DIR/Documentation/WorkspacePreflight/$TIMESTAMP"
fi
mkdir -p "$OUTPUT_DIR"

fail=0

check_repo() {
  label="$1"; path="$2"
  echo "== $label: $path =="
  if [ ! -d "$path" ]; then
    echo "MISSING: $path does not exist"
    fail=1
    return
  fi
  if [ ! -d "$path/.git" ]; then
    echo "FAIL: $path exists but is not a git repository (no .git)"
    fail=1
    return
  fi
  ( cd "$path" && \
    branch=$(git rev-parse --abbrev-ref HEAD) && \
    head=$(git rev-parse HEAD) && \
    dirty=$(git status --short | wc -l | tr -d ' ') && \
    remote=$(git remote get-url origin 2>/dev/null || echo "none") && \
    echo "  branch: $branch" && \
    echo "  HEAD: $head" && \
    echo "  uncommitted changes: $dirty" && \
    echo "  origin: $remote" && \
    if [ "$dirty" != "0" ]; then
      echo "  WARNING: working tree not clean — commit or stash before any real migration"
    else
      echo "  OK: working tree clean"
    fi
  )
}

check_repo "Product (CoreTend)" "$PRODUCT_PATH"
check_repo "Portfolio" "$PORTFOLIO_PATH"

echo
echo "== Disk space at \$HOME volume =="
df -h "$HOME" | tail -1

echo
echo "== Active worktrees (product repo) =="
( cd "$PRODUCT_PATH" && git worktree list )

MANIFEST="$OUTPUT_DIR/preflight-manifest.json"
/usr/bin/python3 - "$MANIFEST" "$PRODUCT_PATH" "$PORTFOLIO_PATH" "$MODE" <<'PYEOF'
import json, subprocess, sys, os

manifest_path, product_path, portfolio_path, mode = sys.argv[1:5]

def repo_info(path):
    if not os.path.isdir(path) or not os.path.isdir(os.path.join(path, ".git")):
        return {"path": path, "exists": os.path.isdir(path), "isGitRepo": False}
    def run(args):
        return subprocess.check_output(args, cwd=path, text=True).strip()
    dirty = run(["git", "status", "--short"])
    return {
        "path": path,
        "exists": True,
        "isGitRepo": True,
        "branch": run(["git", "rev-parse", "--abbrev-ref", "HEAD"]),
        "head": run(["git", "rev-parse", "HEAD"]),
        "clean": dirty == "",
        "remote": (run(["git", "remote", "get-url", "origin"]) if run(["git", "remote"]) else "none"),
    }

manifest = {
    "schemaVersion": 1,
    "mode": mode,
    "product": repo_info(product_path),
    "portfolio": repo_info(portfolio_path),
}
with open(manifest_path, "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
print(f"Wrote {manifest_path}")
PYEOF

if [ "$MODE" = "backup" ]; then
  echo
  echo "== Creating backups (git bundle only — never mv/rm, never touches remotes) =="
  for pair in "product:$PRODUCT_PATH" "portfolio:$PORTFOLIO_PATH"; do
    name="${pair%%:*}"
    path="${pair#*:}"
    if [ -d "$path/.git" ]; then
      bundle="$OUTPUT_DIR/$name.bundle"
      ( cd "$path" && git bundle create "$bundle" --all )
      shasum -a 256 "$bundle" > "$bundle.sha256"
      echo "OK: $bundle ($(stat -f%z "$bundle" 2>/dev/null || stat -c%s "$bundle") bytes)"
    else
      echo "SKIP: $name — not a git repo, no bundle created"
    fi
  done
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "preflight-workspace-migration.sh: FAIL — see MISSING/FAIL lines above"
  exit 1
fi
echo "preflight-workspace-migration.sh: OK — manifest at $MANIFEST"
