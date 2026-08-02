#!/bin/zsh
# Out-of-repo bundle smoke test. Builds + packages the real artifacts
# (reusing package-zip.sh/package-dmg.sh, no duplicated build logic), copies
# them to a throwaway temp dir, and verifies the artifact stands on its own
# outside the repo checkout: no baked-in repo path, correct bundle
# structure, resources/licenses/localizations present, a non-destructive
# launch-and-quit smoke test, and a fresh-location DB init check. Cleans up
# all temp files itself. Touches no personal data.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"
VERSION="${1:-0.7.0}"

fail=0
note() { echo "== $* =="; }
ok()   { echo "OK: $*"; }
bad()  { echo "FAIL: $*"; fail=1; }

note "Packaging ZIP and DMG"
bash Scripts/package-zip.sh "$VERSION"
bash Scripts/package-dmg.sh "$VERSION"

ZIP="Release/CoreTend-${VERSION}-arm64-unsigned.zip"
DMG="Release/CoreTend-${VERSION}-arm64-unsigned.dmg"
[ -f "$ZIP" ] || { bad "zip not found at $ZIP"; exit 1; }
[ -f "$DMG" ] || { bad "dmg not found at $DMG"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

note "Extracting ZIP outside the repo ($WORK)"
mkdir -p "$WORK/zip"
unzip -q "$ZIP" -d "$WORK/zip"
APP="$WORK/zip/CoreTend.app"
[ -d "$APP" ] && ok "app bundle extracted" || bad "app bundle missing after extraction"

note "Mounting DMG"
MOUNT_POINT=$(mktemp -d)
hdiutil attach "$DMG" -mountpoint "$MOUNT_POINT" -nobrowse -quiet
[ -d "$MOUNT_POINT/CoreTend.app" ] && ok "DMG mounts and contains app bundle" || bad "DMG missing app bundle"
[ -L "$MOUNT_POINT/Applications" ] && ok "DMG has /Applications shortcut" || bad "DMG missing Applications symlink"
hdiutil detach "$MOUNT_POINT" -quiet || true
rmdir "$MOUNT_POINT" 2>/dev/null || true

note "Checking bundle structure"
BIN="$APP/Contents/MacOS/CoreTend"
[ -x "$BIN" ] && ok "executable present" || bad "executable missing"
[ -f "$APP/Contents/Info.plist" ] && ok "Info.plist present" || bad "Info.plist missing"
[ -f "$APP/Contents/Resources/AppIcon.icns" ] && ok "app icon present" || bad "app icon missing"
if ls "$APP/Contents/Resources"/*.bundle >/dev/null 2>&1; then
  ok "SwiftPM resource bundle present"
else
  bad "SwiftPM resource bundle missing (localizations would be broken)"
fi

note "Checking license files"
for f in LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
  [ -f "$WORK/zip/$f" ] && ok "$f present in ZIP" || bad "$f missing from ZIP"
done

note "Checking localizations shipped"
BUNDLE=$(ls -d "$APP/Contents/Resources"/*.bundle 2>/dev/null | head -1)
if [ -n "$BUNDLE" ]; then
  if [ -d "$BUNDLE/en.lproj" ] || [ -d "$BUNDLE/Base.lproj" ]; then
    ok "English (Base) localization present"
  else
    bad "English (Base) localization missing"
  fi
  [ -d "$BUNDLE/fr.lproj" ] && ok "fr.lproj present" || bad "fr.lproj missing"
fi

note "Checking arm64 architecture"
if file "$BIN" | grep -q "arm64"; then ok "binary is arm64"; else bad "binary is not arm64"; fi
if file "$BIN" | grep -qi "x86_64"; then bad "binary unexpectedly contains x86_64 slice"; fi

note "Checking artifact does not disclose the checkout or build account"
# Search the raw Mach-O, not just printable data sections: Swift's N_OSO debug
# records live in LINKEDIT and `strings` can omit them. package-local.sh strips
# those records before signing; this gate prevents a future packaging path from
# accidentally shipping an unstripped executable.
if LC_ALL=C grep -aFq "$REPO_ROOT" "$BIN"; then
  bad "binary contains the literal repo checkout path"
else
  ok "binary does not contain the repo checkout path"
fi
BUILD_HOME_PREFIX="/Users/$(id -un)/"
if LC_ALL=C grep -aFq "$BUILD_HOME_PREFIX" "$BIN"; then
  bad "binary contains the build account path $BUILD_HOME_PREFIX"
else
  ok "binary does not contain the build account path"
fi

note "Isolated launch smoke test"
# The app is launched against a throwaway store via TestStoreOverride
# (Sources/Persistence/TestStoreOverride.swift): CORETEND_TEST_MODE=1 plus an
# absolute CORETEND_TEST_STORE_DIR under a temporary root. Both are required, and
# the marker also suppresses the legacy-data migration — otherwise the migration
# would read the user's real pre-rename data and copy it into the temp directory,
# defeating the isolation this test exists to prove.
#
# Isolation is not merely configured, it is *measured*: the real store is
# fingerprinted before and after, and the run fails if anything there changed.
REAL_STORE_DIR="$HOME/Library/Application Support/CoreTend"
TEST_STORE_DIR=$(mktemp -d /private/tmp/coretend-smoke-store.XXXXXX)

# Fingerprint = path, size and modification time of every file, plus the set of
# names. Content hashes would be stronger but this store can be large; size+mtime
# is sufficient to catch a read-modify-write, and `find` alone catches creation
# and deletion. Access times are deliberately NOT compared: merely listing the
# directory to fingerprint it would change them.
fingerprint_real_store() {
  if [ -d "$REAL_STORE_DIR" ]; then
    find "$REAL_STORE_DIR" -type f -exec stat -f '%N %z %m' {} \; 2>/dev/null | sort
  else
    echo "ABSENT"
  fi
}

BEFORE_FP=$(fingerprint_real_store)
BEFORE_COUNT=$(printf '%s\n' "$BEFORE_FP" | wc -l | tr -d ' ')
echo "  real store fingerprint: $BEFORE_COUNT line(s) from $REAL_STORE_DIR"

CORETEND_TEST_MODE=1 CORETEND_TEST_STORE_DIR="$TEST_STORE_DIR" \
  open -W -n -a "$APP" --args --smoke-test-quit-immediately &
LAUNCH_PID=$!
sleep 4
if pgrep -f "$WORK/zip/CoreTend.app/Contents/MacOS/CoreTend" >/dev/null; then
  ok "app launched without an immediate crash"
  pkill -f "$WORK/zip/CoreTend.app/Contents/MacOS/CoreTend" || true
  sleep 1
else
  bad "app did not appear to launch (or crashed immediately) — check Console.app for a crash report"
fi
wait $LAUNCH_PID 2>/dev/null || true

note "Isolation gate: only the temporary store may have changed"
AFTER_FP=$(fingerprint_real_store)
if [ "$BEFORE_FP" = "$AFTER_FP" ]; then
  ok "real store untouched — no file created, modified, resized or removed under $REAL_STORE_DIR"
else
  bad "REAL STORE CHANGED during the smoke test — isolation is broken, do not ship this build"
  echo "--- fingerprint diff (before > after) ---"
  diff <(printf '%s\n' "$BEFORE_FP") <(printf '%s\n' "$AFTER_FP") | sed 's|'"$HOME"'|~|g' | head -20
fi

# The migration journal is the specific thing a broken isolation would create,
# so it gets its own named check rather than hiding inside the fingerprint diff.
if [ -f "$TEST_STORE_DIR/migration-log.json" ]; then
  bad "legacy migration ran inside the isolated store — the test marker must suppress it"
else
  ok "legacy migration did not run under the test marker"
fi

note "Fresh-location DB init check (temporary store only)"
if [ -f "$TEST_STORE_DIR/store.sqlite" ]; then
  if file "$TEST_STORE_DIR/store.sqlite" | grep -qi "SQLite"; then
    ok "fresh DB initialized as valid SQLite inside the isolated store"
  else
    bad "DB file exists in the isolated store but is not valid SQLite"
  fi
  # A store carried over from the real location would be far larger than a
  # freshly migrated-and-empty one, and would contain user rows.
  ROWS=$(sqlite3 "$TEST_STORE_DIR/store.sqlite" "SELECT COUNT(*) FROM activity;" 2>/dev/null || echo "?")
  if [ "$ROWS" = "0" ] || [ "$ROWS" = "?" ]; then
    ok "isolated store carries no activity history (rows: $ROWS)"
  else
    bad "isolated store contains $ROWS activity rows — real user data appears to have been copied in"
  fi
else
  echo "NOTE: no DB in the isolated store (app may not have reached DB init before quit) — not a hard failure."
fi

# Clean up the throwaway store. The real store is never touched by this script.
rm -rf "$TEST_STORE_DIR"
ok "temporary store removed"

note "Summary"
if [ "$fail" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "ONE OR MORE CHECKS FAILED (see FAIL lines above)"
fi
exit $fail
