#!/bin/sh
# Gate: brand-rename and brand-publication preconditions.
#
# Two independent gates read the same approval record, because a local
# technical rename and a public release carry completely different risk:
#
#   --engineering (default)
#     Allows the local rename: code, docs, assets, bundle identifier,
#     user-data migration. Requires ALL of:
#       - Configuration/BrandRenameApproval.local.json exists, with
#         approvedByHuman == true and engineeringRenameApproved == true,
#         and approvedName matching the candidate being checked
#       - Documentation/brand-name-clearance.json records this exact name
#         with status CLEAR_FOR_ENGINEERING
#       - the research docs exist (BRAND_SEARCH_EVIDENCE.md,
#         BRAND_CONFLICT_REGISTER.md, BRAND_NAME_CLEARANCE.md)
#       - no OPEN conflict-register entry names this candidate
#       - git tree is clean
#       - the full test suite passes (real run, never a cached result)
#       - a workspace/data backup exists under Documentation/WorkspacePreflight/
#       - a rollback plan exists (PRODUCT_RENAME_ROLLBACK.md)
#
#   --publication
#     Allows anything outward-facing: push, deploy, public release, tags,
#     store listings. Requires everything --engineering requires, PLUS:
#       - legalReviewStatus == "accepted"
#       - publicReleaseAllowed == true
#
# Engineering clearance NEVER implies publication clearance. A name may be
# safe enough to build under locally and still be unsafe to ship under.
#
# Usage: Scripts/check-brand-clearance.sh [--engineering|--publication] [<candidate-name>]
#   If <candidate-name> is omitted, reads it from the approval file's
#   approvedName field.
set -eu
cd "${CHECK_BRAND_CLEARANCE_ROOT:-$(dirname "$0")/..}"

MODE="engineering"
CANDIDATE=""
for arg in "$@"; do
  case "$arg" in
    --engineering) MODE="engineering" ;;
    --publication) MODE="publication" ;;
    --*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) CANDIDATE="$arg" ;;
  esac
done

APPROVAL_FILE="Configuration/BrandRenameApproval.local.json"
CLEARANCE_FILE="Documentation/brand-name-clearance.json"

fail=0
blockers=""

block() {
  fail=1
  blockers="$blockers\n  - $1"
}

json_get() {
  /usr/bin/python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2],''))" "$1" "$2" 2>/dev/null || echo ""
}

# 1. Approval file must exist and approve the right thing.
if [ ! -f "$APPROVAL_FILE" ]; then
  block "$APPROVAL_FILE does not exist — no rename may proceed without explicit human approval"
else
  APPROVED_NAME=$(json_get "$APPROVAL_FILE" approvedName)
  APPROVED_BY_HUMAN=$(json_get "$APPROVAL_FILE" approvedByHuman)
  ENGINEERING_OK=$(json_get "$APPROVAL_FILE" engineeringRenameApproved)
  LEGAL_STATUS=$(json_get "$APPROVAL_FILE" legalReviewStatus)
  PUBLIC_OK=$(json_get "$APPROVAL_FILE" publicReleaseAllowed)

  [ "$APPROVED_BY_HUMAN" = "True" ] || block "$APPROVAL_FILE.approvedByHuman is not true"
  [ "$ENGINEERING_OK" = "True" ] || block "$APPROVAL_FILE.engineeringRenameApproved is not true"

  if [ "$MODE" = "publication" ]; then
    [ "$LEGAL_STATUS" = "accepted" ] \
      || block "$APPROVAL_FILE.legalReviewStatus is '$LEGAL_STATUS', expected 'accepted' — publication is blocked until final legal review lands"
    [ "$PUBLIC_OK" = "True" ] \
      || block "$APPROVAL_FILE.publicReleaseAllowed is not true — publication is blocked"
  fi

  if [ -z "$CANDIDATE" ]; then
    CANDIDATE="$APPROVED_NAME"
  fi
  if [ -n "$CANDIDATE" ] && [ "$CANDIDATE" != "$APPROVED_NAME" ]; then
    block "candidate name '$CANDIDATE' does not match $APPROVAL_FILE's approvedName '$APPROVED_NAME'"
  fi
fi

if [ -z "$CANDIDATE" ]; then
  block "no candidate name given and none found in $APPROVAL_FILE — cannot check clearance for an unspecified name"
fi

# 2. Research docs must exist.
for doc in Documentation/BRAND_SEARCH_EVIDENCE.md Documentation/BRAND_CONFLICT_REGISTER.md Documentation/BRAND_NAME_CLEARANCE.md; do
  [ -f "$doc" ] || block "$doc is missing — brand research must be documented before any rename"
done

# 3. Clearance status must be CLEAR_FOR_ENGINEERING for this exact candidate.
if [ -f "$CLEARANCE_FILE" ]; then
  CLEARANCE_STATUS=$(json_get "$CLEARANCE_FILE" status)
  CLEARANCE_NAME=$(json_get "$CLEARANCE_FILE" candidateName)
  if [ -n "$CANDIDATE" ] && [ "$CLEARANCE_NAME" = "$CANDIDATE" ]; then
    [ "$CLEARANCE_STATUS" = "CLEAR_FOR_ENGINEERING" ] \
      || block "$CLEARANCE_FILE status for '$CANDIDATE' is '$CLEARANCE_STATUS', not CLEAR_FOR_ENGINEERING"
  else
    block "$CLEARANCE_FILE documents a different name ('$CLEARANCE_NAME') than the candidate ('$CANDIDATE') — no clearance record exists for this exact name"
  fi
else
  block "$CLEARANCE_FILE is missing"
fi

# 4. No BLOCKING conflict register entry may name this candidate.
#
# The register uses a closed status vocabulary, documented in its own
# "Status vocabulary" section:
#
#   BLOCKING       a real conflict — the name must not be used   -> blocks
#   OPEN           legacy token, kept so older rows keep force   -> blocks
#   WATCH          recorded, non-blocking, carries a stated
#                  condition for a named future step             -> surfaced only
#   INFORMATIONAL  noted for completeness                        -> ignored
#   CLOSED         resolved or abandoned                         -> ignored
#
# WATCH exists because the previous single-token scheme could only express
# "unresolved", which forced genuinely non-blocking observations (an adjacent
# mark in an unrelated industry, a parked domain the project does not need) to
# read as though they barred publication. A WATCH row never silences anything:
# it is printed on every run so the condition stays visible.
if [ -f Documentation/BRAND_CONFLICT_REGISTER.md ] && [ -n "$CANDIDATE" ]; then
  CANDIDATE_ROWS=$(grep -i "$CANDIDATE" Documentation/BRAND_CONFLICT_REGISTER.md || true)

  if printf '%s\n' "$CANDIDATE_ROWS" | grep -qE '\*\*(BLOCKING|OPEN)\b|\bBLOCKING\b'; then
    block "Documentation/BRAND_CONFLICT_REGISTER.md has a BLOCKING/OPEN entry naming '$CANDIDATE'"
  fi

  WATCH_COUNT=$(printf '%s\n' "$CANDIDATE_ROWS" | grep -c '\*\*WATCH\.\*\*' || true)
  if [ "${WATCH_COUNT:-0}" -gt 0 ]; then
    echo "  NOTE: ${WATCH_COUNT} WATCH entry/entries name '$CANDIDATE' in"
    echo "        Documentation/BRAND_CONFLICT_REGISTER.md. These do not block a"
    echo "        free unsigned beta, but each carries a condition that must be met"
    echo "        before the future step it names (typically commercial use or a"
    echo "        trademark filing). Read them before any 1.0 or paid release."
  fi
fi

# 5. Git tree must be clean.
if [ -n "$(git status --short)" ]; then
  block "working tree is not clean — commit or stash before a rename gate can pass"
fi

# 6. Full test suite must pass — a real run, never a cached/assumed result.
if ! bash Scripts/test.sh >/tmp/check-brand-clearance-tests.log 2>&1; then
  block "Scripts/test.sh did not pass — see /tmp/check-brand-clearance-tests.log"
fi

# 7. A workspace/data backup must exist.
if [ ! -d Documentation/WorkspacePreflight ] || [ -z "$(find Documentation/WorkspacePreflight -name '*.bundle' 2>/dev/null)" ]; then
  block "no backup found — run Scripts/preflight-workspace-migration.sh --create-backups at least once first"
fi

# 8. A rollback plan must exist.
[ -f Documentation/PRODUCT_RENAME_ROLLBACK.md ] || block "Documentation/PRODUCT_RENAME_ROLLBACK.md is missing"

echo "== check-brand-clearance.sh: mode = $MODE, candidate = '${CANDIDATE:-<none>}' =="
if [ "$fail" -ne 0 ]; then
  printf 'BLOCKED — %s may not proceed:%b\n' "$MODE" "$blockers"
  exit 1
fi
echo "CLEAR — all $MODE preconditions hold for '$CANDIDATE'."
