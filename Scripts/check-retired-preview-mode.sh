#!/bin/sh
# Prevent the retired product preview mode from returning. Historical release
# notes, audit snapshots, database columns and the uninstaller's own safe
# preview flag are intentionally outside this current-product contract.
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

pattern='dry[[:space:]_-]*run|dryRun'
failed=0

check_absent() {
  label=$1
  shift
  matches=$(grep -Ein "$pattern" "$@" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    echo "FAIL: retired preview-mode reference in $label:"
    echo "$matches"
    failed=1
  else
    echo "OK: $label has no retired preview-mode reference"
  fi
}

check_absent "current Swift product" \
  Sources/CoreTendApp Sources/SafetyCore \
  Sources/Persistence/TestStoreOverride.swift Sources/Persistence/LegacyDataMigration.swift

check_absent "current Xcode UI-test contract" Tests/CoreTendUITests

check_absent "public website" \
  Website/index.html Website/build.py

check_absent "public product fixture" Resources/DemoFixtures

check_absent "current product documentation" \
  README.md PRODUCT.md CONTRIBUTING.md \
  Documentation/APPLICATIONS.md Documentation/ARCHITECTURE.md \
  Documentation/ARCHITECTURE_OVERVIEW.md Documentation/CLEANUP_GUIDE.md \
  Documentation/FEATURE_INVENTORY.md Documentation/FEATURE_MATRIX.md \
  Documentation/FIRST_LAUNCH.md Documentation/FIRST_RUN_STATE_MACHINE.md \
  Documentation/PERSISTENCE.md Documentation/PRODUCT_REQUIREMENTS.md \
  Documentation/SAFETYCORE.md Documentation/SAFETY_MODEL.md \
  Documentation/SETTINGS.md Documentation/SETTINGS_MATRIX.md \
  Documentation/SMART_CARE.md Documentation/SPACE_LENS.md \
  Documentation/USER_GUIDE.md

for catalogue in \
  Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings \
  Sources/CoreTendApp/Resources/fr.lproj/Localizable.strings; do
  decoded=$(iconv -f UTF-16 -t UTF-8 "$catalogue")
  if printf '%s\n' "$decoded" | grep -Eiq "$pattern"; then
    echo "FAIL: retired preview-mode copy in $catalogue"
    failed=1
  else
    echo "OK: $catalogue has no retired preview-mode copy"
  fi
done

# Six old storage references are retained deliberately: the shipped v1 column,
# writes of the fixed false value, read filters, the v4 setting removal and the
# old audit-stage filter. They preserve upgrades/downgrades without exposing a
# current API that can create or select preview behavior.
store_matches=$(grep -Ein "$pattern" Sources/Persistence/Store.swift || true)
store_count=$(printf '%s\n' "$store_matches" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$store_count" -ne 6 ] || \
   ! printf '%s\n' "$store_matches" | grep -q 'dry_run INTEGER NOT NULL DEFAULT 1' || \
   ! printf '%s\n' "$store_matches" | grep -q "DELETE FROM settings WHERE key = 'dryRunDefault'" || \
   ! printf '%s\n' "$store_matches" | grep -q 'INSERT INTO activity.*dry_run' || \
   [ "$(printf '%s\n' "$store_matches" | grep -c 'dry_run = 0')" -ne 2 ] || \
   ! printf '%s\n' "$store_matches" | grep -q "stage <> 'dryRun'"; then
  echo "FAIL: Store.swift must contain only the six reviewed legacy-compatibility references"
  echo "$store_matches"
  failed=1
else
  echo "OK: Store.swift contains only the six reviewed legacy-compatibility references"
fi

for view in CleanupView DuplicatesView ApplicationsView LeftoversView PrivacyCleanerView SpaceLensView; do
  file="Sources/CoreTendApp/$view.swift"
  if grep -q '\.confirmationDialog' "$file"; then
    echo "OK: $view has an explicit confirmation"
  else
    echo "FAIL: destructive surface $view has no confirmationDialog"
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "retired preview-mode gate: FAILED"
  exit 1
fi

echo "retired preview-mode gate: passed"
