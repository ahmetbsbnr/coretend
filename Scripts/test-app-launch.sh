#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Launch smoke test for the packaged app — the gate v1.0.0 did not have.
#
# Every release check CoreTend ran was a check on *metadata*: signature,
# notarization, staple, checksums, manifest fields. All of them passed for
# v1.0.0 and the app still could not open on a single user's Mac, because
# nothing ever started the binary that was about to ship.
#
# The v1.0.0 failure mode is the one this guards: SwiftPM's generated
# Bundle.module accessor resolved only through the *build machine's* scratch
# directory, so the app launched for whoever built it and trapped (SIGTRAP,
# fatalError in resource_bundle_accessor.swift) for everyone else. A launch
# test catches that class of defect — missing resources, unresolved dylibs,
# a bad Info.plist — while a checksum never can.
#
# The app is started from a copy outside the build tree, with the build's
# scratch path removed from view, so a stale build directory cannot mask the
# failure the way it masked it in v1.0.0.
#
# Usage: Scripts/test-app-launch.sh [path/to/CoreTend.app]
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-build/CoreTend.app}"
[ -d "$APP" ] || { echo "test-app-launch.sh: FAIL — $APP not found. Run Scripts/package-local.sh first."; exit 1; }

WORK=$(mktemp -d)

# The heart of the test. SwiftPM compiles the build machine's scratch path into
# the binary as Bundle.module's fallback, and that directory exists right after
# a build — which is exactly why v1.0.0 launched for its author and for nobody
# else. Hiding it for the duration makes this machine behave like a user's.
SCRATCH="${CORETEND_SCRATCH_PATH:-/tmp/coretend-release-build}"
HIDDEN=""
if [ -d "$SCRATCH" ]; then
  HIDDEN="${SCRATCH}.hidden-for-launch-test.$$"
  mv "$SCRATCH" "$HIDDEN"
fi
restore() {
  [ -n "$HIDDEN" ] && [ -d "$HIDDEN" ] && mv "$HIDDEN" "$SCRATCH"
  rm -rf "$WORK"
}
trap restore EXIT

# A copy outside the build tree: relative-path luck must not count as a pass.
ditto "$APP" "$WORK/CoreTend.app"
BIN="$WORK/CoreTend.app/Contents/MacOS/CoreTend"
[ -x "$BIN" ] || { echo "test-app-launch.sh: FAIL — no executable at Contents/MacOS/CoreTend"; exit 1; }

echo "== Launching $APP =="
LOG="$WORK/launch.log"
"$BIN" > "$LOG" 2>&1 &
PID=$!

# Long enough for Bundle.module's initializer, dyld and the first window;
# short enough to stay a test. The failure this guards is immediate.
SECONDS_WAITED=0
while [ "$SECONDS_WAITED" -lt 10 ]; do
  kill -0 "$PID" 2>/dev/null || break
  sleep 1
  SECONDS_WAITED=$((SECONDS_WAITED + 1))
done

if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  echo "test-app-launch.sh: OK — the app stayed up for ${SECONDS_WAITED}s."
  exit 0
fi

wait "$PID" 2>/dev/null || STATUS=$?
echo "test-app-launch.sh: FAIL — the app exited after ${SECONDS_WAITED}s (status ${STATUS:-?})."
echo "  This is what a user sees as \"the app does not open\"."
if [ -s "$LOG" ]; then
  echo "  Output:"
  sed 's/^/    /' "$LOG"
else
  echo "  No output; check ~/Library/Logs/DiagnosticReports/CoreTend-*.ips"
fi
exit 1
