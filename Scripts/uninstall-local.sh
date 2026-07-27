#!/bin/sh
# Removes CoreTend's own app data from this Mac: the app bundle (if in
# /Applications), its Application Support folder (SQLite DB + quarantine),
# and its preferences plist. Mirrors Documentation/UNINSTALL.md exactly.
#
# Never touches files the app quarantined-and-restored, never touches any
# other app's data, never uses sudo. Requires interactive confirmation
# unless --yes is passed. Dry-run by default with --dry-run.
set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
INCLUDE_LEGACY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --include-legacy) INCLUDE_LEGACY=1 ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--yes] [--include-legacy]"
      echo "Removes CoreTend's app bundle, Application Support data, and prefs."
      echo "--include-legacy also removes data left by the pre-rename version"
      echo "(MacCare Local), which the rename migration copied rather than moved."
      exit 0
      ;;
  esac
done

APP_PATH="/Applications/CoreTend.app"
SUPPORT_DIR="$HOME/Library/Application Support/CoreTend"
PREFS_FILE="$HOME/Library/Preferences/com.ahmetbsbnr.coretend.plist"

# Pre-rename identity. The migration copies out of these and never deletes
# them, so on a migrated machine they still hold a full second copy of the
# user's history. Removing them is opt-in: they may also belong to an old
# build the user still has installed.
LEGACY_PATHS="$HOME/Library/Application Support/MacCareLocal
$HOME/Library/Application Support/MacCare Local
$HOME/Library/Preferences/local.maccare.app.plist"

echo "CoreTend — uninstall-local"
echo "The following will be removed if present:"
echo "  $APP_PATH"
echo "  $SUPPORT_DIR  (SQLite database + quarantine — check Documentation/QUARANTINE.md first if you have items to restore)"
echo "  $PREFS_FILE"
if [ "$INCLUDE_LEGACY" -eq 1 ]; then
  echo "  ...and pre-rename (MacCare Local) data:"
  echo "$LEGACY_PATHS" | while IFS= read -r p; do
    [ -n "$p" ] && echo "      $p"
  done
else
  legacy_found=0
  while IFS= read -r p; do
    [ -n "$p" ] && [ -e "$p" ] && legacy_found=1
  done <<EOF
$LEGACY_PATHS
EOF
  if [ "$legacy_found" -eq 1 ]; then
    echo
    echo "Note: data from the pre-rename version (MacCare Local) is also on this Mac."
    echo "It is NOT removed by default — the rename copied it rather than moving it,"
    echo "so it is a second, intact copy of your history. Re-run with --include-legacy"
    echo "to remove it too."
  fi
fi
echo

if [ "$DRY_RUN" -eq 1 ]; then
  echo "(dry-run: no changes will be made)"
fi

if [ "$ASSUME_YES" -ne 1 ] && [ "$DRY_RUN" -ne 1 ]; then
  printf "Proceed? [y/N] "
  read -r reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

remove() {
  target="$1"
  if [ -e "$target" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  would remove: $target"
    else
      echo "  removing: $target"
      rm -rf -- "$target"
    fi
  else
    echo "  not present: $target"
  fi
}

remove "$APP_PATH"
remove "$SUPPORT_DIR"
remove "$PREFS_FILE"

if [ "$INCLUDE_LEGACY" -eq 1 ]; then
  while IFS= read -r p; do
    [ -n "$p" ] && remove "$p"
  done <<EOF
$LEGACY_PATHS
EOF
fi

echo
echo "Done. No agent, daemon, helper, or hidden file is installed elsewhere by CoreTend."
