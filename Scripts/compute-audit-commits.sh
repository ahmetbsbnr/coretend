#!/bin/sh
# Prints the four commit identities the audit docs must never collapse into
# one "auditedSourceCommit" field again (see Documentation/CURRENT_AUDIT_STATE.json):
#
#   CURRENT_HEAD             - git rev-parse HEAD right now
#   PRODUCT_SOURCE_COMMIT     - latest commit touching Sources/ or Tests/ (the app itself)
#   REQUIREMENTS_AUDIT_COMMIT - latest commit touching the requirements/compliance doc set
#   AUDIT_PACKAGE_COMMIT      - HEAD at the moment the external ZIP is built (caller supplies
#                               this after zipping, since it must be recorded post-hoc)
set -eu
cd "$(dirname "$0")/.."

CURRENT_HEAD=$(git rev-parse HEAD)
PRODUCT_SOURCE_COMMIT=$(git log -1 --format=%H -- Sources/ Tests/)
REQUIREMENTS_AUDIT_COMMIT=$(git log -1 --format=%H -- \
  Documentation/DEFERRED_REQUIREMENTS.md \
  Documentation/FINAL_COMPLIANCE_SCORECARD.md \
  Documentation/MASTER_REQUIREMENTS_BASELINE.md \
  Documentation/NON_COMPLIANCE_REGISTER.md \
  Documentation/PRODUCT_REQUIREMENTS.md \
  Documentation/PUBLIC_READINESS_SCORECARD.md \
  Documentation/REQUIREMENTS_COMPLIANCE_SUMMARY.md \
  Documentation/REQUIREMENTS_DECISION_HISTORY.md \
  Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md \
  Documentation/REQUIREMENTS_VERIFICATION_EVIDENCE.md \
  Documentation/requirements-traceability.csv \
  Documentation/requirements-traceability.json \
  Documentation/feature-inventory.json)

if [ "${1:-}" = "--json" ]; then
  cat <<EOF
{
  "CURRENT_HEAD": "$CURRENT_HEAD",
  "PRODUCT_SOURCE_COMMIT": "$PRODUCT_SOURCE_COMMIT",
  "REQUIREMENTS_AUDIT_COMMIT": "$REQUIREMENTS_AUDIT_COMMIT"
}
EOF
else
  echo "CURRENT_HEAD=$CURRENT_HEAD"
  echo "PRODUCT_SOURCE_COMMIT=$PRODUCT_SOURCE_COMMIT"
  echo "REQUIREMENTS_AUDIT_COMMIT=$REQUIREMENTS_AUDIT_COMMIT"
fi
