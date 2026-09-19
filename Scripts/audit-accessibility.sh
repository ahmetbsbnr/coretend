#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Walks the accessibility tree of every module and fails if any control a
# screen reader can reach has no name.
#
# This is not the VoiceOver pass and does not replace it: VoiceOver reads a
# label, a role description, a value and a help, in an order that depends on
# the rotor and on what came before, and only a person listening can say
# whether what it says is useful. What this proves is narrower — that nothing
# is nameless — and it proves it on every module, every time, which a person
# listening does not.
set -uo pipefail
cd "$(dirname "$0")/.."

app="build/CoreTend.app"
[[ -d "$app" ]] || bash Scripts/package-local.sh >/dev/null

audit="${TMPDIR:-/tmp}/coretend-ax-audit"
if [[ ! -x "$audit" || Scripts/support/ax-audit.swift -nt "$audit" ]]; then
  swiftc -O -o "$audit" Scripts/support/ax-audit.swift || exit 1
fi

screens=(smartCare record cleanup spaceLens duplicates applications protection performance)
failed=0
for module in $screens; do
  store="$(mktemp -d "${TMPDIR:-/tmp}/coretend-ax.XXXXXX")"
  bash Scripts/support/seed-record.sh "$store" >/dev/null 2>&1 || true
  pkill -x CoreTend 2>/dev/null || true
  sleep 1
  CORETEND_TEST_MODE=1 CORETEND_TEST_STORE_DIR="$store" \
  CORETEND_TEST_MODULE="$module" CORETEND_TEST_APPEARANCE=light \
  CORETEND_TEST_WINDOW=standard open -n "$app"
  for _ in {1..40}; do
    [[ -f "$store/showing.txt" ]] && break
    sleep 0.25
  done
  sleep 1
  osascript -e 'tell application "System Events" to tell process "CoreTend" to set frontmost to true' >/dev/null 2>&1 || true
  sleep 0.5
  if output=$("$audit" 2>&1); then
    print "ok   $module — ${output%%$'\n'*}"
  else
    print "FAIL $module"
    print "$output" | sed 's/^/     /'
    failed=$((failed+1))
  fi
  rm -rf "$store"
done
pkill -x CoreTend 2>/dev/null || true
print "accessibility audit done, $failed failed"
exit $(( failed > 0 ))
