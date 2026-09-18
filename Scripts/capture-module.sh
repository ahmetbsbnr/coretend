#!/bin/zsh
# capture-module.sh <out.png> <module> [light|dark] [compact|standard|large] [seed-script]
#
# Launches a fresh, isolated CoreTend on the named module, in the named
# appearance and window size, optionally on a seeded store, and captures its
# window by CoreGraphics window id.
#
# The capture is refused unless the app itself reports showing what was asked
# for. This script once photographed the Dashboard eleven times while claiming
# eleven modules, because the identifiers it passed did not resolve and the app
# fell back silently; every check run against those images passed. A tool that
# cannot detect that it is wrong produces confident, wrong reports.
#
# Module identifiers: smartCare record cleanup spaceLens duplicates applications
#                     myClutter cloudCleanup performance protection myActivity
set -euo pipefail
out="${1:?usage: $0 <out.png> <module> [light|dark] [compact|standard|large] [seed]}"
module="${2:?usage: $0 <out.png> <module> [light|dark] [compact|standard|large] [seed]}"
appearance="${3:-dark}"
size="${4:-standard}"
seed="${5:-${CORETEND_CAPTURE_SEED:-}}"
app="${CORETEND_APP:-build/CoreTend.app}"
mkdir -p "$(dirname "$out")"

store="$(mktemp -d "${TMPDIR:-/tmp}/coretend-capture.XXXXXX")"
cleanup() { rm -rf "$store"; }
trap cleanup EXIT

# An empty screen proves nothing about a layout, so a capture may be seeded.
if [[ -n "$seed" ]]; then
  bash "$(dirname "$0")/support/${seed}" "$store" >/dev/null
fi

pkill -x CoreTend 2>/dev/null || true
sleep 1
CORETEND_TEST_MODE=1 \
CORETEND_TEST_STORE_DIR="$store" \
CORETEND_TEST_MODULE="$module" \
CORETEND_TEST_APPEARANCE="$appearance" \
CORETEND_TEST_WINDOW="$size" \
  open -n "$app"

# Wait for the app to write its evidence rather than for a fixed delay: the
# evidence file exists only once the main window's content has appeared and
# been resized, which is the earliest moment a capture is meaningful.
for _ in {1..60}; do
  [[ -f "$store/showing.txt" ]] && break
  sleep 0.25
done
if [[ ! -f "$store/showing.txt" ]]; then
  print -u2 "capture-module: CoreTend never reported what it was showing"
  exit 1
fi
sleep 1.2

osascript -e 'tell application "System Events" to tell process "CoreTend" to set frontmost to true' >/dev/null 2>&1 || true
sleep 0.4

helper="${TMPDIR:-/tmp}/coretend-window-id"
if [[ ! -x "$helper" || Scripts/support/window-id.swift -nt "$helper" ]]; then
  swiftc -O -o "$helper" Scripts/support/window-id.swift
fi
id=""
for _ in {1..20}; do
  id=$("$helper" CoreTend 2>/dev/null || true)
  [[ -n "$id" ]] && break
  sleep 0.25
done
if [[ -z "$id" ]]; then
  print -u2 "capture-module: no on-screen CoreTend window found"
  exit 1
fi

screencapture -o -x -l "$id" "$out"

# Refuse the capture unless the app reports exactly what was requested.
shown_module=$(sed -n 's/^module=//p' "$store/showing.txt")
shown_appearance=$(sed -n 's/^appearance=//p' "$store/showing.txt")
shown_window=$(sed -n 's/^window=//p' "$store/showing.txt")
normalise() { print -r -- "${1//[[:space:]]/}" | tr '[:upper:]' '[:lower:]'; }
if [[ "$(normalise "$shown_module")" != "$(normalise "$module")" \
   && "$(normalise "$shown_module")" != "$(normalise "$(print -r -- "$module" | sed 's/smartcare/Smart Care/i')")" ]]; then
  # ModuleID raw values are display-shaped ("Space Lens"); identifiers are not.
  # Compare with spaces and case removed, which is how the app resolves them.
  if [[ "$(normalise "$shown_module")" != "$(normalise "$module")" ]]; then
    print -u2 "capture-module: asked for '$module' but the app shows '$shown_module' — capture refused"
    rm -f "$out"; exit 2
  fi
fi
if [[ "$shown_appearance" != "$appearance" ]]; then
  print -u2 "capture-module: asked for $appearance but the app is $shown_appearance — capture refused"
  rm -f "$out"; exit 2
fi
if [[ "$shown_window" != "$size" ]]; then
  print -u2 "capture-module: asked for $size window but the app reports $shown_window — capture refused"
  rm -f "$out"; exit 2
fi
print "captured: $module $appearance $size ${seed:+seed=$seed }-> $out"
