#!/bin/sh
# Shell-level tests for Scripts/uninstall.sh: dry-run must never delete
# anything, and the allowlist must reject paths it doesn't own. Uses a fake
# HOME so this never touches the real machine's CoreTend data.
set -euo pipefail
cd "$(dirname "$0")/.."
UNINSTALL="$PWD/Scripts/uninstall.sh"

FAKE_HOME="$(mktemp -d)"
FAKE_APP="$FAKE_HOME/CoreTend.app"
mkdir -p "$FAKE_APP/Contents/MacOS"
echo "fake-binary" > "$FAKE_APP/Contents/MacOS/CoreTend"
trap 'rm -rf "$FAKE_HOME"' EXIT
export CORETEND_UNINSTALL_APP_PATH_OVERRIDE="$FAKE_APP"

mkdir -p "$FAKE_HOME/Library/Application Support/CoreTend"
echo "fake-db" > "$FAKE_HOME/Library/Application Support/CoreTend/store.sqlite"
mkdir -p "$FAKE_HOME/Library/Preferences"
echo "fake-plist" > "$FAKE_HOME/Library/Preferences/com.ahmetbsbnr.coretend.plist"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. Dry-run (default, no flags) must not delete anything.
HOME="$FAKE_HOME" "$UNINSTALL" --dry-run >/tmp/uninstall-test-dryrun.out
[ -f "$FAKE_HOME/Library/Application Support/CoreTend/store.sqlite" ] \
  || fail "dry-run deleted the DB"
[ -f "$FAKE_HOME/Library/Preferences/com.ahmetbsbnr.coretend.plist" ] \
  || fail "dry-run deleted the prefs plist"
grep -q "would remove" /tmp/uninstall-test-dryrun.out \
  || fail "dry-run didn't report what it would remove"
echo "PASS: dry-run deletes nothing"

# 2. --remove-all with --yes actually removes the allowlisted paths.
HOME="$FAKE_HOME" "$UNINSTALL" --remove-all --yes >/tmp/uninstall-test-remove.out
[ ! -e "$FAKE_HOME/Library/Application Support/CoreTend" ] \
  || fail "--remove-all left the Application Support dir behind"
[ ! -e "$FAKE_HOME/Library/Preferences/com.ahmetbsbnr.coretend.plist" ] \
  || fail "--remove-all left the prefs plist behind"
echo "PASS: --remove-all removes allowlisted paths"

# 3. --keep-quarantine removes prefs but keeps the DB.
mkdir -p "$FAKE_HOME/Library/Application Support/CoreTend"
echo "fake-db" > "$FAKE_HOME/Library/Application Support/CoreTend/store.sqlite"
mkdir -p "$FAKE_HOME/Library/Preferences"
echo "fake-plist" > "$FAKE_HOME/Library/Preferences/com.ahmetbsbnr.coretend.plist"
HOME="$FAKE_HOME" "$UNINSTALL" --keep-quarantine --yes >/tmp/uninstall-test-keep.out
[ -f "$FAKE_HOME/Library/Application Support/CoreTend/store.sqlite" ] \
  || fail "--keep-quarantine deleted the DB"
[ ! -e "$FAKE_HOME/Library/Preferences/com.ahmetbsbnr.coretend.plist" ] \
  || fail "--keep-quarantine left the prefs plist behind"
echo "PASS: --keep-quarantine keeps the DB, removes prefs"

# 4. Refuses to follow a symlink planted where a real target should be —
# proves the "never follow symlinks" rule actually holds, not just the
# happy path. If it followed the link, the outside directory would be
# deleted or its contents exposed to rm -rf.
OUTSIDE_DIR="$(mktemp -d)"
echo "must-survive" > "$OUTSIDE_DIR/canary"
rm -rf "$FAKE_HOME/Library/Application Support/CoreTend"
ln -s "$OUTSIDE_DIR" "$FAKE_HOME/Library/Application Support/CoreTend"
if HOME="$FAKE_HOME" "$UNINSTALL" --remove-all --yes >/tmp/uninstall-test-symlink.out 2>&1; then
  fail "uninstall.sh exited 0 instead of refusing a symlinked target"
fi
[ -f "$OUTSIDE_DIR/canary" ] || fail "symlink target was deleted through the symlink"
grep -qi "symlink" /tmp/uninstall-test-symlink.out || fail "no symlink-refusal message printed"
rm -rf "$OUTSIDE_DIR"
echo "PASS: refuses to follow a symlinked target"

# 5. Legacy (pre-rename) data is left alone unless --include-legacy is given.
# The rename migration copies rather than moves, so this directory is a second
# intact copy of the user's history — and may belong to an old build still
# installed. Deleting it by implication would be a silent data loss.
rm -rf "$FAKE_HOME/Library/Application Support/CoreTend"
mkdir -p "$FAKE_HOME/Library/Application Support/CoreTend"
echo "fake-db" > "$FAKE_HOME/Library/Application Support/CoreTend/store.sqlite"
mkdir -p "$FAKE_HOME/Library/Application Support/MacCareLocal"
echo "legacy-db" > "$FAKE_HOME/Library/Application Support/MacCareLocal/store.sqlite"
echo "legacy-plist" > "$FAKE_HOME/Library/Preferences/local.maccare.app.plist"

HOME="$FAKE_HOME" "$UNINSTALL" --remove-all --yes >/tmp/uninstall-test-legacy-off.out
[ -f "$FAKE_HOME/Library/Application Support/MacCareLocal/store.sqlite" ] \
  || fail "--remove-all deleted pre-rename data without --include-legacy"
[ -f "$FAKE_HOME/Library/Preferences/local.maccare.app.plist" ] \
  || fail "--remove-all deleted the pre-rename prefs plist without --include-legacy"
[ ! -e "$FAKE_HOME/Library/Application Support/CoreTend" ] \
  || fail "--remove-all failed to remove the current identity's data"
echo "PASS: pre-rename data survives an uninstall that didn't ask for it"

# 6. --include-legacy removes it, and only then.
mkdir -p "$FAKE_HOME/Library/Application Support/CoreTend"
echo "fake-db" > "$FAKE_HOME/Library/Application Support/CoreTend/store.sqlite"
echo "fake-plist" > "$FAKE_HOME/Library/Preferences/com.ahmetbsbnr.coretend.plist"
mkdir -p "$FAKE_HOME/Library/Application Support/MacCare Local"
echo "legacy-alt" > "$FAKE_HOME/Library/Application Support/MacCare Local/store.sqlite"

HOME="$FAKE_HOME" "$UNINSTALL" --remove-all --include-legacy --yes >/tmp/uninstall-test-legacy-on.out
[ ! -e "$FAKE_HOME/Library/Application Support/MacCareLocal" ] \
  || fail "--include-legacy left the legacy Application Support dir behind"
[ ! -e "$FAKE_HOME/Library/Application Support/MacCare Local" ] \
  || fail "--include-legacy left the space-separated legacy dir behind"
[ ! -e "$FAKE_HOME/Library/Preferences/local.maccare.app.plist" ] \
  || fail "--include-legacy left the legacy prefs plist behind"
echo "PASS: --include-legacy removes pre-rename data"

# 7. The allowlist still refuses a legacy path when the flag is absent, even if
# something else on the command line names it. The flag gates the allowlist
# itself, not merely the target list.
mkdir -p "$FAKE_HOME/Library/Application Support/MacCareLocal"
echo "legacy-db" > "$FAKE_HOME/Library/Application Support/MacCareLocal/store.sqlite"
HOME="$FAKE_HOME" "$UNINSTALL" --dry-run >/tmp/uninstall-test-legacy-dry.out
grep -q "MacCareLocal" /tmp/uninstall-test-legacy-dry.out \
  && fail "dry-run listed a legacy path without --include-legacy"
[ -f "$FAKE_HOME/Library/Application Support/MacCareLocal/store.sqlite" ] \
  || fail "dry-run deleted legacy data"
echo "PASS: legacy paths are outside the allowlist without --include-legacy"

echo
echo "All uninstall.sh tests passed."
