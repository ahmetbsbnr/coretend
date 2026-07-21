#!/bin/sh
# Public-facing uninstaller for MacCare Local.
#
# Relationship to Scripts/uninstall-local.sh: that script is the original
# two-path remover (app bundle + Application Support) written during the
# open-source-foundation phase and is kept as-is for anyone already using it
# in a doc or muscle-memory. This script is the fuller replacement for
# public distribution: three explicit modes, a strict canonicalized
# allowlist, and quarantine handled as an opt-in rather than bundled in
# blindly. Prefer this one; Documentation/UNINSTALL.md points here.
#
# MacCare Local owns exactly one directory tree
# (~/Library/Application Support/MacCareLocal — the SQLite DB, which holds
# quarantine records, exclusions, and scan history) plus one prefs plist and
# the app bundle itself. No LaunchAgent, daemon, helper, or hidden file is
# installed anywhere else (see Documentation/UNINSTALL.md). This script
# never needs sudo because every path it touches is user-owned under $HOME
# or the top-level /Applications entry the user themselves dragged in.
#
# Modes:
#   --dry-run       (default if no mode flag given) list what would be
#                    removed, remove nothing, no confirmation prompt.
#   --keep-quarantine  same paths as --remove-all, but the SQLite DB is kept
#                    (quarantine + history + exclusions preserved). Requires
#                    confirmation.
#   --remove-all    removes the app bundle, Application Support dir
#                    (including quarantine), and prefs plist. Requires
#                    confirmation.
set -euo pipefail

MODE="dry-run"
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry-run" ;;
    --keep-quarantine) MODE="keep-quarantine" ;;
    --remove-all) MODE="remove-all" ;;
    --yes|-y) ASSUME_YES=1 ;;
    --help|-h)
      echo "Usage: $0 [--dry-run|--keep-quarantine|--remove-all] [--yes]"
      echo "  --dry-run          list what would be removed; removes nothing (default)"
      echo "  --keep-quarantine  remove app + prefs, keep the SQLite DB (quarantine/history/exclusions)"
      echo "  --remove-all       remove app, Application Support dir (incl. quarantine), and prefs"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

HOME_DIR="$HOME"
APP_PATH="/Applications/MacCare Local.app"
SUPPORT_DIR="$HOME_DIR/Library/Application Support/MacCareLocal"
DB_FILE="$SUPPORT_DIR/store.sqlite"
PREFS_FILE="$HOME_DIR/Library/Preferences/local.maccare.app.plist"

# --- Safety: canonicalize and refuse anything unexpected -------------------
# Never follow symlinks when resolving "the real path" of a target — if a
# path component is itself a symlink pointing somewhere unexpected, refuse
# rather than silently deleting through it. `cd -P` resolves symlinks in the
# parent chain without following a trailing symlink target itself.
canonical_dir() {
  # Prints the resolved absolute path of an existing directory, or nothing
  # if it doesn't exist / can't be resolved.
  dir="$1"
  if [ -d "$dir" ]; then
    (cd -P -- "$dir" 2>/dev/null && pwd -P)
  fi
}

# Refuse to ever act on / or the full home directory, even if some future
# edit to this script computed a target incorrectly.
FORBIDDEN_1="/"
FORBIDDEN_2="$(canonical_dir "$HOME_DIR")"

is_forbidden() {
  target="$1"
  [ "$target" = "$FORBIDDEN_1" ] && return 0
  [ -n "$FORBIDDEN_2" ] && [ "$target" = "$FORBIDDEN_2" ] && return 0
  return 1
}

# Strict allowlist: only these real (post-symlink-resolution-of-parents)
# paths may ever be passed to rm. Anything else aborts the whole run.
is_allowlisted() {
  case "$1" in
    "$APP_PATH") return 0 ;;
    "$SUPPORT_DIR") return 0 ;;
    "$DB_FILE") return 0 ;;
    "$PREFS_FILE") return 0 ;;
    *) return 1 ;;
  esac
}

check_target() {
  target="$1"
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    return 1 # not present, nothing to do
  fi
  if is_forbidden "$target"; then
    echo "REFUSING to touch forbidden path: $target" >&2
    exit 1
  fi
  if ! is_allowlisted "$target"; then
    echo "REFUSING to touch non-allowlisted path: $target" >&2
    exit 1
  fi
  # Refuse if this "file" is actually a symlink to somewhere outside the
  # allowlisted target itself (don't delete through a symlink).
  if [ -L "$target" ]; then
    echo "REFUSING to touch symlink (not following): $target" >&2
    exit 1
  fi
  return 0
}

# Newline-separated (not space-separated) because paths like APP_PATH
# contain spaces — word-splitting on a space-joined list would silently
# mangle "/Applications/MacCare Local.app" into two bogus, always-absent
# paths and skip it entirely.
case "$MODE" in
  dry-run) TARGETS="$APP_PATH
$SUPPORT_DIR
$PREFS_FILE" ;;
  keep-quarantine) TARGETS="$APP_PATH
$PREFS_FILE" ;;
  remove-all) TARGETS="$APP_PATH
$SUPPORT_DIR
$PREFS_FILE" ;;
esac

echo "MacCare Local — uninstall (mode: $MODE)"
echo "Paths that will be checked:"
printf '%s\n' "$TARGETS" | while IFS= read -r t; do
  echo "  $t"
done
if [ "$MODE" = "keep-quarantine" ]; then
  echo "  (kept: $DB_FILE — quarantine, history, exclusions)"
fi
echo

if [ "$MODE" = "dry-run" ]; then
  printf '%s\n' "$TARGETS" | while IFS= read -r t; do
    if check_target "$t" 2>/dev/null; then
      echo "  would remove: $t"
    else
      echo "  not present:  $t"
    fi
  done
  echo
  echo "(dry-run: nothing was deleted. Re-run with --remove-all or --keep-quarantine to actually uninstall.)"
  exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  printf "This will permanently delete the paths above. Proceed? [y/N] "
  read -r reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

printf '%s\n' "$TARGETS" | while IFS= read -r t; do
  if check_target "$t"; then
    echo "  removing: $t"
    rm -rf -- "$t"
  else
    echo "  not present: $t"
  fi
done

echo
echo "Done. No agent, daemon, helper, or hidden file is installed elsewhere by MacCare Local."
