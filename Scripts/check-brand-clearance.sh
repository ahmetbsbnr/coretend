#!/bin/sh
# Gate: blocks any future rename until every brand-clearance precondition
# is real, not assumed. Exits non-zero (blocking) unless ALL of:
#   - Documentation/brand-name-clearance.json status == CLEAR_FOR_ENGINEERING
#   - Configuration/BrandRenameApproval.local.json exists, approvedByHuman
#     is true, legalReviewStatus is "accepted", and approvedName matches
#     the name this gate is checking
#   - the research docs (BRAND_SEARCH_EVIDENCE.md, BRAND_CONFLICT_REGISTER.md,
#     BRAND_NAME_CLEARANCE.md) exist
#   - no OPEN entry in BRAND_CONFLICT_REGISTER.md for that exact name
#   - git tree is clean
#   - the full test suite passes (Scripts/test.sh — real run, not cached)
#   - a workspace/data-migration backup exists (Scripts/preflight-workspace-migration.sh
#     has been run with --create-backups at least once, evidenced by a
#     manifest under Documentation/WorkspacePreflight/)
#   - a rollback plan exists (PRODUCT_RENAME_ROLLBACK.md)
#
# Usage: Scripts/check-brand-clearance.sh [<candidate-name>]
#   If <candidate-name> is omitted, reads it from
#   Configuration/BrandRenameApproval.local.json's approvedName field.
set -eu
cd "${CHECK_BRAND_CLEARANCE_ROOT:-$(dirname "$0")/..}"

CANDIDATE="${1:-}"
APPROVAL_FILE="Configuration/BrandRenameApproval.local.json"
CLEARANCE_FILE="Documentation/brand-name-clearance.json"

fail=0
blockers=""

block() {
  fail=1
  blockers="$blockers\n  - $1"
}

# 1. Approval file must exist.
if [ ! -f "$APPROVAL_FILE" ]; then
  block "$APPROVAL_FILE does not exist — no rename may proceed without explicit human approval"
else
  APPROVED_NAME=$(/usr/bin/python3 -c "import json; print(json.load(open('$APPROVAL_FILE')).get('approvedName',''))" 2>/dev/null || echo "")
  APPROVED_BY_HUMAN=$(/usr/bin/python3 -c "import json; print(json.load(open('$APPROVAL_FILE')).get('approvedByHuman', False))" 2>/dev/null || echo "False")
  LEGAL_STATUS=$(/usr/bin/python3 -c "import json; print(json.load(open('$APPROVAL_FILE')).get('legalReviewStatus',''))" 2>/dev/null || echo "")

  [ "$APPROVED_BY_HUMAN" = "True" ] || block "$APPROVAL_FILE.approvedByHuman is not true"
  [ "$LEGAL_STATUS" = "accepted" ] || block "$APPROVAL_FILE.legalReviewStatus is '$LEGAL_STATUS', expected 'accepted'"

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
  CLEARANCE_STATUS=$(/usr/bin/python3 -c "import json; print(json.load(open('$CLEARANCE_FILE')).get('status',''))" 2>/dev/null || echo "")
  CLEARANCE_NAME=$(/usr/bin/python3 -c "import json; print(json.load(open('$CLEARANCE_FILE')).get('candidateName',''))" 2>/dev/null || echo "")
  if [ -n "$CANDIDATE" ] && [ "$CLEARANCE_NAME" = "$CANDIDATE" ]; then
    [ "$CLEARANCE_STATUS" = "CLEAR_FOR_ENGINEERING" ] \
      || block "$CLEARANCE_FILE status for '$CANDIDATE' is '$CLEARANCE_STATUS', not CLEAR_FOR_ENGINEERING"
  else
    block "$CLEARANCE_FILE documents a different name ('$CLEARANCE_NAME') than the candidate ('$CANDIDATE') — no clearance record exists for this exact name"
  fi
else
  block "$CLEARANCE_FILE is missing"
fi

# 4. No OPEN conflict register entry may name this candidate.
if [ -f Documentation/BRAND_CONFLICT_REGISTER.md ] && [ -n "$CANDIDATE" ]; then
  if grep -qi "OPEN" Documentation/BRAND_CONFLICT_REGISTER.md && grep -qi "$CANDIDATE" Documentation/BRAND_CONFLICT_REGISTER.md; then
    if grep -i "$CANDIDATE" Documentation/BRAND_CONFLICT_REGISTER.md | grep -qi "OPEN"; then
      block "Documentation/BRAND_CONFLICT_REGISTER.md still has an OPEN entry naming '$CANDIDATE'"
    fi
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

echo "== check-brand-clearance.sh: candidate = '${CANDIDATE:-<none>}' =="
if [ "$fail" -ne 0 ]; then
  printf 'BLOCKED — rename may not proceed:%b\n' "$blockers"
  exit 1
fi
echo "CLEAR — all rename preconditions hold for '$CANDIDATE'."
