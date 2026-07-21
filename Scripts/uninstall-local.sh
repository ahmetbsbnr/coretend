#!/bin/sh
# Removes MacCare Local's own app data from this Mac: the app bundle (if in
# /Applications), its Application Support folder (SQLite DB + quarantine),
# and its preferences plist. Mirrors Documentation/UNINSTALL.md exactly.
#
# Never touches files the app quarantined-and-restored, never touches any
# other app's data, never uses sudo. Requires interactive confirmation
# unless --yes is passed. Dry-run by default with --dry-run.
set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--yes]"
      echo "Removes MacCare Local's app bundle, Application Support data, and prefs."
      exit 0
      ;;
  esac
done

APP_PATH="/Applications/MacCare Local.app"
SUPPORT_DIR="$HOME/Library/Application Support/MacCareLocal"
PREFS_FILE="$HOME/Library/Preferences/local.maccare.app.plist"

echo "MacCare Local — uninstall-local"
echo "The following will be removed if present:"
echo "  $APP_PATH"
echo "  $SUPPORT_DIR  (SQLite database + quarantine — check Documentation/QUARANTINE.md first if you have items to restore)"
echo "  $PREFS_FILE"
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

echo
echo "Done. No agent, daemon, helper, or hidden file is installed elsewhere by MacCare Local."
