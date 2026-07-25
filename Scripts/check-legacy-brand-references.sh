#!/bin/sh
# Gate: no unexplained reference to the pre-rename identity may survive.
#
# The old name is legitimate in exactly four situations, and every one of them
# is a case where erasing it would either falsify a record or break working
# code:
#
#   1. Rename history — the abandoned-candidate research and the old->new
#      mapping documents. Rewriting these would destroy the audit trail that
#      justifies the rename.
#   2. Historical release artifacts — the 0.7.0/0.8.0 notes and bundle
#      inventories describe binaries that really were built under the old
#      name. Renaming them retroactively would be a lie about what shipped.
#   3. User-data compatibility — the migration code, its tests, and the
#      uninstaller must name the old directories and the old bundle
#      identifier, because those strings are what is actually on users' disks.
#   4. The Apache-2.0 licence text, which is never edited.
#
# Anything outside that allowlist is a leftover, and this gate fails on it.
#
# Usage: Scripts/check-legacy-brand-references.sh [--list]
#   --list  print every allowed file and its match count, then exit 0.
set -eu
cd "${CHECK_LEGACY_REFS_ROOT:-$(dirname "$0")/..}"

# Matched case-insensitively (rg -i). Until the 0.8.1 audit resync this scan was
# case-sensitive, which let a screaming-case leftover (a dead
# MACCARELOCAL_STORE_DIR export in Scripts/test-distribution.sh) sit in the tree
# with the gate reporting green. Keep the -i: the old identity was spelled in at
# least three casings across sources, scripts and env vars.
PATTERN='MacCare Local|MacCareLocal|MacCareApp|MacCare|MACCLEAN|mac-care-local|maccare|local\.maccare\.app'

# Every entry needs a stated reason. A path added here without one is an
# unexplained reference wearing an allowlist as a disguise.
allowed_reason() {
  case "$1" in
    Documentation/RebrandHistory/*)
      echo "rename history: research for the abandoned candidate name, and the pre-implementation migration design/test plan preserved verbatim" ;;
    Documentation/AuditHistory/*)
      echo "audit history: frozen state snapshots from earlier versions, never rewritten to match a later state" ;;
    Documentation/PRE_REBRAND_BASELINE.md)
      echo "rename history: the pre-rename baseline being compared against" ;;
    Documentation/CONTINUATION.md)
      echo "rename record: the phase handoff states the old->new name mapping" ;;
    Documentation/CURRENT_PROJECT_STATE.json|Documentation/CURRENT_AUDIT_STATE.json|Documentation/KNOWN_LIMITATIONS.md|Documentation/NON_COMPLIANCE_REGISTER.md|Documentation/DOCUMENT_INDEX.md)
      echo "audit record: names the pre-rename identity when describing the rename itself, the data migration that reads the old paths, and the dead pre-rename env var removed in the 0.8.1 resync" ;;
    Documentation/AUDIT_COMMANDS.log)
      echo "raw evidence log: append-only transcript of real commands, including runs made from the pre-rename checkout path — editing it would falsify the evidence" ;;
    Documentation/CORETEND_DATA_MIGRATION_REPORT.md)
      echo "user-data compatibility: the delivered-state report on the old->new data migration" ;;
    Documentation/FEATURE_INVENTORY.md|Documentation/feature-inventory.json|Documentation/feature-inventory.csv)
      echo "user-data compatibility: generated inventory whose migration entries name the old identity the migration reads from" ;;
    Documentation/WORKSPACE_TARGET_STRUCTURE.md|Documentation/workspace-migration-manifest.json)
      echo "workspace migration record: states the pre-move path a rollback moves back to" ;;
    Documentation/PORTFOLIO_REPOSITORY_INVENTORY.md|Documentation/PROJECT_COMPLETE_AUDIT.md|Documentation/PUBLICATION_AUDIT.md)
      echo "historical audit: records the working-copy path as it was when the audit ran" ;;
    Documentation/PRODUCT_RENAME_INVENTORY.md|Documentation/product-rename-inventory.json)
      echo "rename mapping: the inventory of identifiers the rename had to change" ;;
    Documentation/PRODUCT_RENAME_PLAN.md|Documentation/PRODUCT_RENAME_ROLLBACK.md)
      echo "rename mapping: the plan and its rollback, which must name both identities" ;;
    Documentation/USER_DATA_RENAME_MIGRATION.md|Documentation/user-data-rename-migration.json)
      echo "user-data compatibility: the design of the old->new data migration" ;;
    Documentation/REBRAND_MIGRATION_TEST_PLAN.md)
      echo "user-data compatibility: the migration's own test matrix" ;;
    Documentation/BRAND_NAME_CLEARANCE.md|Documentation/BRAND_CONFLICT_REGISTER.md|Documentation/BRAND_SEARCH_EVIDENCE.md|Documentation/BRAND_NAME_ALTERNATIVES.md)
      echo "rename history: brand clearance record naming the abandoned candidate" ;;
    Documentation/DATA_LOCATIONS.md)
      echo "user-data compatibility: documents where pre-rename data still lives" ;;
    Documentation/UNINSTALL.md)
      echo "user-data compatibility: documents removal of pre-rename data" ;;
    Release/Notes/0.7.0.*.md|Release/Notes/0.7.1.*.md|Release/Notes/0.8.0.*.md)
      echo "historical release: release notes for a version built under the old name" ;;
    Release/Notes/0.8.1.*.md|Documentation/CHANGELOG.md)
      echo "rename announcement: tells users where their pre-rename data is" ;;
    Release/BUNDLE_INVENTORY_0.8.0.md|Release/LAUNCH_VERIFICATION_0.8.0.md)
      echo "historical release: inventory of artifacts built under the old name" ;;
    Sources/Persistence/LegacyDataMigration.swift)
      echo "user-data compatibility: the migration itself must name the old paths" ;;
    Tests/PersistenceTests/LegacyDataMigrationTests.swift)
      echo "user-data compatibility: tests for the migration" ;;
    Sources/CoreTendApp/AppEnvironment.swift|Sources/CoreTendApp/SettingsView.swift)
      echo "user-data compatibility: runs and reports the migration by name" ;;
    Sources/CoreTendApp/Resources/*.lproj/Localizable.strings)
      echo "user-data compatibility: comment marking the migration's strings" ;;
    Scripts/uninstall.sh|Scripts/uninstall-local.sh|Scripts/test-uninstall.sh)
      echo "user-data compatibility: uninstallers must name pre-rename paths" ;;
    Scripts/test-distribution.sh)
      echo "removal record: names the dead pre-rename env var deleted in the 0.8.1 resync, so the deletion stays auditable instead of silently vanishing" ;;
    Scripts/check-legacy-brand-references.sh|Scripts/test-check-legacy-brand-references.sh)
      echo "this gate and its tests: the patterns they search for are their own source" ;;
    Scripts/check-brand-assets.sh)
      echo "asset gate: refuses any generated file still named after the old brand" ;;
    Documentation/PROJECT_STATE.json|Documentation/PROJECT_STATE.md)
      echo "rename record: the phase description states what was renamed from what" ;;
    LICENSE|LICENSES/*)
      echo "licence text: never edited" ;;
    *) return 1 ;;
  esac
}

MATCHES=$(rg -li --hidden \
  --glob '!.git/**' \
  --glob '!.build/**' \
  --glob '!build/**' \
  --glob '!AuditPackages/**' \
  --glob '!.serena/**' \
  --glob '!.claude/**' \
  --glob '!node_modules/**' \
  --glob '!Documentation/WorkspacePreflight/**' \
  "$PATTERN" . 2>/dev/null | sed 's|^\./||' | sort || true)

if [ "${1:-}" = "--list" ]; then
  echo "== files still naming the pre-rename identity =="
  echo "$MATCHES" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    count=$(rg -ci "$PATTERN" "$f" 2>/dev/null || echo 0)
    if reason=$(allowed_reason "$f"); then
      printf '  ALLOWED  %-60s %4s  (%s)\n' "$f" "$count" "$reason"
    else
      printf '  UNKNOWN  %-60s %4s\n' "$f" "$count"
    fi
  done
  exit 0
fi

unexplained=""
for f in $MATCHES; do
  [ -z "$f" ] && continue
  if ! allowed_reason "$f" >/dev/null; then
    unexplained="$unexplained
  - $f"
  fi
done

echo "== check-legacy-brand-references.sh =="
if [ -n "$unexplained" ]; then
  printf 'FAIL — unexplained pre-rename references:%b\n' "$unexplained"
  echo
  echo "Either finish the rename in those files, or add the path to"
  echo "allowed_reason() in this script together with the reason it must keep"
  echo "the old name. An entry without a reason is not allowed."
  exit 1
fi
echo "OK — every remaining pre-rename reference is in an allowlisted file with a stated reason."
