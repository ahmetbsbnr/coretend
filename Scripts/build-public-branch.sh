#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Builds the sanitised public branch from the current tree.
#
# The internal history is not publishable as-is. Seven files have carried an
# absolute /Users/<name> path at some point across 244 commits, several
# documents are internal session-continuity and migration logs that were never
# written for an audience, and the working notes name a private workspace
# layout. Rewriting 244 commits to fix that would be slow, lossy, and would
# still leave every intermediate state of every internal document in the public
# record.
#
# So the public branch is an orphan: one clean commit containing exactly the
# files a user or contributor needs, built from a tree that is verified clean
# before the commit is made. The full internal history is preserved privately
# in a git bundle (see Scripts/... and .private-backups/) and is not thrown
# away — it is simply not published.
#
# This is deliberately a script and not a sequence someone runs by hand: the
# exclusion list is the security boundary, and a boundary that lives in
# somebody's shell history is not reviewable.
#
# Usage:
#   Scripts/build-public-branch.sh [--branch <name>] [--dry-run]
#
# Exits non-zero and creates nothing if the verification step finds anything.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

BRANCH="public-main"
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

SOURCE_REF=$(git rev-parse HEAD)
SOURCE_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# ---------------------------------------------------------------- excluded ---
# Everything here is internal working material, not product. Each entry is a
# path prefix matched against `git ls-files` output.
#
# The test is not "is this embarrassing" but "was this written for an audience
# outside the project". Session logs, migration manifests and audit packages
# were not; they also happen to be where the private workspace paths live.
EXCLUDE_PREFIXES=(
  # Session continuity and internal planning — written agent-to-agent.
  "Documentation/CONTINUATION.md"
  "Documentation/AUDIT_COMMANDS.log"
  "Documentation/PROJECT_COMPLETE_AUDIT.md"
  "Documentation/PUBLICATION_AUDIT.md"
  "Documentation/CURRENT_AUDIT_STATE.json"
  "Documentation/CURRENT_PROJECT_STATE.json"
  "Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md"
  "Documentation/NON_COMPLIANCE_REGISTER.md"
  "Documentation/HUMAN_BLOCKERS.md"

  # Workspace migration — describes a private directory layout on one machine.
  "Documentation/WorkspacePreflight/"
  "Documentation/WORKSPACE_TARGET_STRUCTURE.md"
  "Documentation/WORKSPACE_MIGRATION_PLAN.md"
  "Documentation/workspace-migration-manifest.json"
  "Documentation/PORTFOLIO_REPOSITORY_INVENTORY.md"
  "Documentation/portfolio-repository-inventory.json"
  "Scripts/preflight-workspace-migration.sh"
  "Scripts/test-preflight-workspace-migration.sh"
  "Scripts/check-workspace-migration-readiness.sh"
  "Scripts/test-check-workspace-migration-readiness.sh"
  "Scripts/check-workspace-layout.sh"
  "Scripts/test-check-workspace-layout.sh"

  # Rebrand-era internal records. The rename is explained in the public
  # history note instead; these are the working files behind it.
  "Documentation/PRODUCT_RENAME_INVENTORY.md"
  "Documentation/product-rename-inventory.json"
  "Documentation/PRODUCT_RENAME_PLAN.md"
  "Documentation/PRODUCT_RENAME_ROLLBACK.md"
  "Documentation/PRE_REBRAND_BASELINE.md"
  "Documentation/user-data-rename-migration.json"

  # Build outputs and audit bundles — regenerable, and large.
  "AuditPackages/"
  "Documentation/VisualAudit/"
  "build/"
  "dist/"
)

is_excluded() {
  local f="$1" p
  for p in "${EXCLUDE_PREFIXES[@]}"; do
    case "$p" in
      */) [ "${f##"$p"}" != "$f" ] && return 0 ;;
      *)  [ "$f" = "$p" ] && return 0 ;;
    esac
  done
  return 1
}

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

INCLUDED=0
SKIPPED=0
while IFS= read -r f; do
  if is_excluded "$f"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  mkdir -p "$STAGING/$(dirname "$f")"
  git show "HEAD:$f" > "$STAGING/$f" 2>/dev/null || continue
  INCLUDED=$((INCLUDED + 1))
done < <(git ls-files)

echo "public export: $INCLUDED file(s) included, $SKIPPED excluded"

# ------------------------------------------------------------- verification ---
# Runs against the staged tree, before any commit exists. Anything found here
# aborts: it is much cheaper to fail now than to force-push over a public
# branch that already leaked.
FAILED=0
fail() { echo "  BLOCK: $1" >&2; FAILED=1; }

echo "verifying staged tree..."

# 1. No private workspace layout.
for pattern in 'MAC_ORGANISE' '00_DOCUMENTS_EXISTANTS' '01_PROJETS_ACTIFS'; do
  if hits=$(grep -rIl "$pattern" "$STAGING" 2>/dev/null); then
    if [ -n "$hits" ]; then
      # check-website.sh legitimately contains these as *detection* patterns —
      # it is the script whose job is to find them in generated output.
      real=$(printf '%s\n' "$hits" | grep -v 'Scripts/check-website.sh' || true)
      [ -n "$real" ] && fail "pattern '$pattern' present in: $(printf '%s' "$real" | head -3 | tr '\n' ' ')"
    fi
  fi
done

# 2. No absolute path naming the real account this was built from.
#
# Blocking every /Users/<name> would be wrong: the test suite is full of
# deliberately synthetic home paths (/Users/x, /Users/alice, /Users/testuser)
# and those are fixtures, not leaks. What must never ship is the builder's
# actual account name, so that is matched exactly.
REAL_USER=$(basename "$HOME")
if [ -n "$REAL_USER" ] && grep -rIl "/Users/$REAL_USER" "$STAGING" >/dev/null 2>&1; then
  fail "the building account's home path (/Users/$REAL_USER) appears in the export"
fi

# Any /Users/<name> outside the known-synthetic set is surfaced for a human to
# look at. Not fatal — a new fixture name is normal — but it must not pass
# silently, because "it looked like a fixture" is how a real one gets through.
KNOWN_FIXTURE_USERS='^(x|u|me|someone|testuser|alice|bob|jsmith1985|user|test)$'
UNKNOWN=$(grep -rhoIE "/Users/[A-Za-z0-9_.-]+" "$STAGING" 2>/dev/null \
          | sed 's#/Users/##' | sort -u \
          | grep -vE "$KNOWN_FIXTURE_USERS" || true)
if [ -n "$UNKNOWN" ]; then
  echo "  NOTE: /Users/ paths with unrecognised names (verify these are fixtures):"
  printf '%s\n' "$UNKNOWN" | sed 's/^/        \/Users\//'
fi

# 3. No credential-shaped material.
for pattern in 'gh[pousr]_[A-Za-z0-9]\{36,\}' 'AKIA[0-9A-Z]\{16\}' 'xox[baprs]-' \
               'BEGIN [A-Z ]*PRIVATE KEY' 'sk-ant-[A-Za-z0-9]\{20,\}' 'npm_[A-Za-z0-9]\{36\}'; do
  if grep -rIlE "$pattern" "$STAGING" >/dev/null 2>&1; then
    fail "credential-shaped match for /$pattern/"
  fi
done

# 4. No local-only configuration may ever be staged.
for f in Configuration/PublicIdentity.local.json Configuration/BrandRenameApproval.local.json; do
  [ -e "$STAGING/$f" ] && fail "$f is a local-only file and must never be published"
done

# 5. The things a public repository must have.
for f in LICENSE README.md SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md Package.swift; do
  [ -e "$STAGING/$f" ] || fail "$f is missing from the export"
done

if [ "$FAILED" -ne 0 ]; then
  echo "build-public-branch.sh: BLOCKED — nothing was created." >&2
  exit 1
fi
echo "  OK: no personal paths, no credentials, no local-only config, required files present"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "build-public-branch.sh: dry run, branch '$BRANCH' not created."
  exit 0
fi

# ------------------------------------------------------------------ commit ---
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "branch '$BRANCH' already exists — refusing to overwrite it." >&2
  echo "Delete it deliberately (git branch -D $BRANCH) if that is what you want." >&2
  exit 1
fi

git checkout -q --orphan "$BRANCH"
git rm -rq --cached . 2>/dev/null || true
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null || true
cp -R "$STAGING"/. .
git add -A

git commit -q -F - <<COMMIT_MSG
CoreTend $(git show "$SOURCE_REF:Documentation/../Package.swift" >/dev/null 2>&1 && echo "" || echo "")— first public source release

CoreTend is a free, open-source macOS maintenance utility: cleanup, storage
analysis, duplicate and similar-image detection, privacy cleaning, optional
ClamAV-backed scanning, and an activity view. It runs locally, collects no
telemetry, requires no account, and every destructive action is reversible.

This is the first public commit. The project was developed privately before
this point, and that history is intentionally not published: it contains
session-continuity logs, workspace migration manifests, and absolute paths
from the machine it was built on — internal working material that was never
written for an audience. Documentation/PROJECT_HISTORY.md explains what came
before, including the project's earlier name, MacCare Local.

Nothing about the software is hidden by that choice. The full source, tests,
build scripts, and gates are here; only the private record of how the sausage
was made is omitted.

Built from internal $SOURCE_BRANCH at $SOURCE_REF.
COMMIT_MSG

echo "build-public-branch.sh: created '$BRANCH' at $(git rev-parse --short HEAD)"
echo "  source: $SOURCE_BRANCH @ ${SOURCE_REF:0:12}"
echo "  return with: git checkout $SOURCE_BRANCH"
