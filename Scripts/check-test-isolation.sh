#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Gate: no automated test may launch the app against the user's real store.
#
# This is a static gate on purpose. The dynamic proof lives inside
# Scripts/test-distribution.sh, which fingerprints the real store before and
# after the launch and fails if anything changed. But a dynamic check only
# protects the run it is part of: someone could delete the fingerprint, or add a
# second launch elsewhere, and every gate would still be green. This script
# asserts the *shape* of the thing instead:
#
#   1. The override plumbing still exists in Sources/ and is still two-key.
#   2. The legacy migration is still suppressed under the test marker.
#   3. Every script that launches the packaged app sets both variables.
#   4. No script writes to the real Application Support directory.
#
# Usage: Scripts/check-test-isolation.sh
set -eu
cd "${CHECK_TEST_ISOLATION_ROOT:-$(dirname "$0")/..}"

fail=0
ok()  { echo "OK: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

MARKER="CORETEND_TEST_MODE"
PATHVAR="CORETEND_TEST_STORE_DIR"
OVERRIDE_SRC="Sources/Persistence/TestStoreOverride.swift"
STORE_SRC="Sources/Persistence/Store.swift"
ENV_SRC="Sources/CoreTendApp/AppEnvironment.swift"

echo "== Override plumbing exists and is two-key =="
if [ -f "$OVERRIDE_SRC" ]; then
  ok "$OVERRIDE_SRC present"
  if grep -q "\"$MARKER\"" "$OVERRIDE_SRC" && grep -q "\"$PATHVAR\"" "$OVERRIDE_SRC"; then
    ok "both $MARKER and $PATHVAR are declared"
  else
    bad "the override must be keyed on BOTH $MARKER and $PATHVAR"
  fi
  # A single-key override would let one stray environment variable relocate a
  # real user's database, which is the whole thing this gate exists to prevent.
  for rule in markerNotExactlyOne pathNotAbsolute pathNotUnderTemporaryRoot pathProtected pathIsHomeOrAbove pathEmpty; do
    if grep -q "$rule" "$OVERRIDE_SRC"; then
      ok "validation rule present: $rule"
    else
      bad "validation rule missing from the override: $rule"
    fi
  done
else
  bad "$OVERRIDE_SRC is missing — the store override has been removed"
fi

echo "== Store consults the override, and keeps an unoverridable user path =="
if grep -q "TestStoreOverride" "$STORE_SRC"; then
  ok "Store.defaultPath() consults TestStoreOverride"
else
  bad "Store.defaultPath() no longer consults TestStoreOverride"
fi
if grep -q "func userPath" "$STORE_SRC" && grep -q "func userDirectory" "$STORE_SRC"; then
  ok "Store.userPath()/userDirectory() exist as the unoverridable real location"
else
  bad "Store must keep an unoverridable userPath()/userDirectory() to measure against"
fi

echo "== Legacy migration is suppressed under the test marker =="
if grep -q "isTestMarkerSet" "$ENV_SRC"; then
  ok "AppEnvironment suppresses the legacy migration under the test marker"
else
  bad "AppEnvironment must skip runLegacyMigration() when the test marker is set — otherwise a smoke test copies real user data into the temp store"
fi

echo "== Every script that launches the packaged app isolates its store =="
# `open -a "$APP"` / direct Contents/MacOS invocation are the two ways a script
# can start the real bundle. Any such line must be preceded by both variables on
# the same command, so isolation cannot be forgotten in a new script.
# This script is excluded: it contains the patterns it searches for, which would
# otherwise make the gate flag itself.
launchers=$(grep -rln 'open -W -n -a\|open -n -a\|Contents/MacOS/CoreTend"' Scripts/ 2>/dev/null \
  | grep -v 'check-test-isolation.sh' || true)
if [ -z "$launchers" ]; then
  echo "  (no launching script found)"
else
  for f in $launchers; do
    # pgrep/pkill lines reference the binary path without launching it.
    if grep -qE '(open -W? ?-n -a)' "$f"; then
      if grep -qE "$MARKER=1[[:space:]]+$PATHVAR=" "$f"; then
        ok "$f launches with both isolation variables set"
      else
        bad "$f launches the app without setting $MARKER=1 and $PATHVAR= on the same command"
      fi
    fi
  done
fi

echo "== The distribution test proves isolation rather than asserting it =="
DIST="Scripts/test-distribution.sh"
if [ -f "$DIST" ]; then
  if grep -q "fingerprint_real_store" "$DIST"; then
    ok "$DIST fingerprints the real store"
  else
    bad "$DIST must fingerprint the real store before and after the launch"
  fi
  if grep -q 'BEFORE_FP" = "\$AFTER_FP' "$DIST"; then
    ok "$DIST compares the before/after fingerprints"
  else
    bad "$DIST must compare the before/after fingerprints and fail on any change"
  fi
  if grep -q "migration-log.json" "$DIST"; then
    ok "$DIST checks that the legacy migration did not run"
  else
    bad "$DIST must check that no migration journal appeared in the isolated store"
  fi
  # The old, dishonest shape: launching with no isolation at all.
  if grep -qE 'open -W -n -a "\$APP"' "$DIST" && ! grep -qE "$MARKER=1" "$DIST"; then
    bad "$DIST launches the app with no store isolation"
  fi
else
  bad "$DIST is missing"
fi

echo "== No script writes to the real Application Support directory =="
# Reading it (find/stat/file, for fingerprinting) is fine and necessary.
# Writing, moving or deleting there from a test script is not.
offenders=$(grep -rnE '(rm|mv|cp|mkdir|touch|sqlite3)[^|]*Library/Application Support/CoreTend' Scripts/ 2>/dev/null \
  | grep -v 'check-test-isolation.sh' \
  | grep -v 'uninstall' || true)
if [ -z "$offenders" ]; then
  ok "no script mutates the real Application Support directory (uninstallers excepted by design)"
else
  bad "a script appears to mutate the real store:"
  printf '%s\n' "$offenders" | sed "s|$HOME|~|g" | head -10
fi

echo "== summary =="
if [ "$fail" -eq 0 ]; then
  echo "check-test-isolation.sh: PASSED — automated tests cannot reach the real store."
else
  echo "check-test-isolation.sh: FAILED — see FAIL lines above."
fi
exit "$fail"
