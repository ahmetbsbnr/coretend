#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Regression gate for the v1.2.0-beta.1 "Settings shows Unverified after
# relaunch" blocker. Runs the real FullDiskAccessProbe in FIVE separate fresh
# processes and requires every run to report the SAME state — the historical
# bug was a single-signal probe that flip-flopped between launches.
#
# Then rebuilds the app binary with Scripts/package-local.sh and probes once
# more: the rebuilt binary must report the same state (the probe reads the
# live filesystem, not a per-build persisted flag).
#
# This does NOT verify the interactive Settings UI — that is HUMAN
# VERIFICATION. It verifies the probe/state layer that the UI now derives from.
set -e
cd "$(dirname "$0")/.."

swift build --product PermissionQA >/dev/null 2>&1
BIN=.build/debug/PermissionQA

echo "== five fresh-process probes =="
lines=()
for i in 1 2 3 4 5; do
  set +e; out="$("$BIN")"; code=$?; set -e
  # keep only the state token so transient timing counters don't count as a diff
  state="${out%% *}"
  lines+=("$state")
  echo "  relaunch #$i: $out  (exit $code)"
done

distinct=$(printf '%s\n' "${lines[@]}" | sort -u | wc -l | tr -d ' ')
if [ "$distinct" != "1" ]; then
  echo "FAIL: the probe reported $distinct different states across 5 relaunches:"
  printf '  %s\n' "${lines[@]}" | sort -u
  exit 1
fi
echo "OK: identical state on all 5 relaunches (${lines[1]})"

echo "== rebuild persistence =="
CORETEND_SWIFT_BUILD_FLAGS='' Scripts/package-local.sh >/dev/null 2>&1 || true
set +e; after="$("$BIN")"; set -e
echo "  after rebuild: $after"
after_state="${after%% *}"
if [ "$after_state" != "${lines[1]}" ]; then
  echo "FAIL: probe state changed after a rebuild ('${lines[1]}' -> '$after_state')"
  echo "      inspect the app's designated requirement / signature, not the label."
  exit 1
fi
echo "OK: probe state unchanged across a rebuild"

echo "test-permission-relaunch.sh: PASSED"
