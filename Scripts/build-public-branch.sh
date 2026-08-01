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
#   Scripts/build-public-branch.sh [--branch <name>] [--parent <ref>] [--dry-run]
#
# Exits non-zero and creates nothing if the verification step finds anything.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

BRANCH="public-main"
PARENT=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --parent) PARENT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

SOURCE_REF=$(git rev-parse HEAD)
SOURCE_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Files are staged by copying from the working tree, not by `git show`, because
# .gitattributes gives some files a working-tree-encoding (the .strings
# catalogues are UTF-16) and `git show` emits the UTF-8 blob without its BOM,
# which git then refuses to re-add. Copying preserves the on-disk encoding.
#
# That only holds if the working tree matches HEAD, so require it. Publishing
# from a dirty tree would ship whatever happened to be lying around anyway.
if [ -n "$(git status --porcelain)" ]; then
  echo "working tree is not clean — commit or stash first." >&2
  echo "The export copies from the working tree, so it must match HEAD." >&2
  exit 1
fi

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
  "Documentation/NEXT_SESSION_PROMPT.md"
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
# (trap is reinstalled below once TMP_INDEX exists)
trap 'rm -rf "$STAGING"' EXIT

INCLUDED=0
SKIPPED=0
while IFS= read -r f; do
  if is_excluded "$f"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  mkdir -p "$STAGING/$(dirname "$f")"
  cp -p "$f" "$STAGING/$f" 2>/dev/null || continue
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
      # The scanners themselves contain these strings as *detection* patterns:
      # check-website.sh looks for them in generated output, and this script
      # looks for them here. A scanner matching its own pattern list is not a
      # leak, and excluding the scanners from publication instead would ship a
      # repository whose gates cannot be re-run by anyone else.
      real=$(printf '%s\n' "$hits" \
             | grep -v 'Scripts/check-website.sh' \
             | grep -v 'Scripts/build-public-branch.sh' || true)
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

# The branch is built with a throwaway index and commit-tree, so the working
# tree and HEAD are never touched.
#
# The obvious implementation — checkout --orphan, delete everything, copy the
# staging tree in, commit — destroys the working tree as its second step. If any
# later step fails (and one did: a UTF-16 catalogue that `git add` rejected),
# it strands the repository on an unborn branch with the real tree already
# gone, and recovering means knowing to reach for `git checkout -f`. A script
# whose failure mode is "your checkout is now the export" is not one to hand
# someone at release time.
#
# Building the commit object directly has no such state to lose: on failure
# nothing has changed at all, and the branch only appears once the commit exists.
TMP_INDEX=$(mktemp -u)
trap 'rm -rf "$STAGING" "$TMP_INDEX"' EXIT

GIT_INDEX_FILE="$TMP_INDEX" GIT_WORK_TREE="$STAGING" git add -A
TREE=$(GIT_INDEX_FILE="$TMP_INDEX" GIT_WORK_TREE="$STAGING" git write-tree)

# The message goes via a file rather than a heredoc piped into the command
# substitution: bash 3.2, which is what ships with macOS, mis-parses an
# apostrophe inside a heredoc nested in $( ), and this message contains one.
MSG_FILE="$STAGING.msg"
if [ -n "$PARENT" ]; then
  COMMIT_TITLE="CoreTend — publish media and website update"
  COMMIT_CONTEXT="This commit updates the existing sanitised public source tree. The internal development history remains private for the same path and workspace-safety reasons documented in the first public commit."
else
  COMMIT_TITLE="CoreTend — first public source release"
  COMMIT_CONTEXT="This is the first public commit. The project was developed privately before this point, and that history is intentionally not published: it contains session-continuity logs, workspace migration manifests, and absolute paths from the machine it was built on — internal working material that was never written for an audience. Documentation/PROJECT_HISTORY.md explains what came before, including the project's earlier name, MacCare Local."
fi
cat > "$MSG_FILE" <<COMMIT_MSG
$COMMIT_TITLE

CoreTend is a free, open-source macOS maintenance utility: cleanup, storage
analysis, duplicate and similar-image detection, privacy cleaning, optional
local integrity checks, and an activity view. It runs locally, collects no
telemetry, requires no account, and every destructive action is reversible.

$COMMIT_CONTEXT

Nothing about the software is hidden by that choice. The full source, tests,
build scripts, and gates are here; only the private record of how the sausage
was made is omitted.

Built from internal $SOURCE_BRANCH at $SOURCE_REF.
COMMIT_MSG
if [ -n "$PARENT" ]; then
  PARENT_COMMIT=$(git rev-parse "$PARENT^{commit}")
  COMMIT=$(git commit-tree "$TREE" -p "$PARENT_COMMIT" -F "$MSG_FILE")
else
  COMMIT=$(git commit-tree "$TREE" -F "$MSG_FILE")
fi
rm -f "$MSG_FILE"

git branch "$BRANCH" "$COMMIT"

echo "build-public-branch.sh: created '$BRANCH' at $(git rev-parse --short "$COMMIT")"
echo "  source:  $SOURCE_BRANCH @ ${SOURCE_REF:0:12}"
if [ -n "$PARENT" ]; then
  echo "  parent:  $PARENT @ ${PARENT_COMMIT:0:12}"
fi
echo "  files:   $INCLUDED included, $SKIPPED excluded"
echo "  working tree untouched — you are still on $(git rev-parse --abbrev-ref HEAD)"
echo "  inspect: git show --stat $BRANCH"
