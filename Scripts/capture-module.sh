#!/bin/zsh
# capture-module.sh <out.png> <module> [light|dark] [compact|standard|large] [seed-script] [state] [tab]
#
# Environment: CORETEND_CAPTURE_HOME_SEED=<script under Scripts/support> builds
# a stand-in home for scans; a [state] argument starts the module's scan and
# waits for the module to report that state before capturing.
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
# Module identifiers: smartCare record cleanup spaceLens duplicates
#                     applications protection performance
set -euo pipefail
out="${1:?usage: $0 <out.png> <module> [light|dark] [compact|standard|large] [seed]}"
module="${2:?usage: $0 <out.png> <module> [light|dark] [compact|standard|large] [seed]}"
appearance="${3:-dark}"
size="${4:-standard}"
seed="${5:-${CORETEND_CAPTURE_SEED:-}}"
state="${6:-}"
tab="${7:-}"
home_seed="${CORETEND_CAPTURE_HOME_SEED:-}"
app="${CORETEND_APP:-build/CoreTend.app}"
mkdir -p "$(dirname "$out")"

store="$(mktemp -d "${TMPDIR:-/tmp}/coretend-capture.XXXXXX")"
cleanup() { rm -rf "$store"; }
trap cleanup EXIT

# An empty screen proves nothing about a layout, so a capture may be seeded.
# Several seeds may be given, comma-separated; each receives the store dir.
if [[ -n "$seed" ]]; then
  for one in ${(s:,:)seed}; do
    bash "$(dirname "$0")/support/${one}" "$store" >/dev/null
  done
fi

fixture_home=""
if [[ -n "$home_seed" ]]; then
  fixture_home="$store/home"
  bash "$(dirname "$0")/support/${home_seed}" "$fixture_home" >/dev/null
fi

# Two states are scenes rather than phases of a module: they are reached by
# presenting something, not by scanning, so they must not start a scan and —
# for Settings — they are not even the same window.
want_onboarding=0
want_settings=0
[[ "$state" == "onboarding" ]] && want_onboarding=1
[[ "$state" == "settings" ]] && want_settings=1

pkill -x CoreTend 2>/dev/null || true
sleep 1
CORETEND_TEST_HOME="$fixture_home" \
CORETEND_TEST_TAB="$tab" \
CORETEND_TEST_ONBOARDING="$want_onboarding" \
CORETEND_TEST_SETTINGS="$want_settings" \
CORETEND_TEST_AUTOSTART="$([[ -n "$state" && "$want_onboarding" == 0 && "$want_settings" == 0 ]] && echo 1 || echo 0)" \
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
# If a tab was asked for, the module must report having selected it.
if [[ -n "$tab" ]]; then
  for _ in {1..40}; do
    grep -q "^tab=$tab\$" "$store/state.txt" 2>/dev/null && break
    sleep 0.25
  done
  if ! grep -q "^tab=$tab\$" "$store/state.txt" 2>/dev/null; then
    print -u2 "capture-module: asked for tab $tab but the module reports $(grep '^tab=' "$store/state.txt" 2>/dev/null | tail -1) — capture refused"
    exit 2
  fi
fi

# If a state was asked for, wait for the module to report reaching it.
if [[ -n "$state" ]]; then
  for _ in {1..120}; do
    grep -qx "$state" "$store/state.txt" 2>/dev/null && break
    sleep 0.25
  done
  if ! grep -qx "$state" "$store/state.txt" 2>/dev/null; then
    print -u2 "capture-module: asked for state '$state' but the module never reported it — capture refused"
    exit 2
  fi
fi
sleep 1.2

osascript -e 'tell application "System Events" to tell process "CoreTend" to set frontmost to true' >/dev/null 2>&1 || true
sleep 0.4

helper="${TMPDIR:-/tmp}/coretend-window-id"
if [[ ! -x "$helper" || Scripts/support/window-id.swift -nt "$helper" ]]; then
  swiftc -O -o "$helper" Scripts/support/window-id.swift
fi
id=""
if [[ "$want_settings" == 1 ]]; then
  # Settings is its own window, and "the frontmost one" is not proof of which
  # — nor is its title, which is in whatever language the app is running in.
  # The app writes the id of the window it drew Settings in; that is the one
  # photographed, or none is.
  for _ in {1..40}; do
    id=$(sed -n 's/^settingsWindow=//p' "$store/state.txt" 2>/dev/null | tail -1)
    [[ -n "$id" ]] && break
    sleep 0.25
  done
  if [[ -z "$id" ]]; then
    print -u2 "capture-module: Settings never reported its window — capture refused"
    exit 2
  fi
else
  for _ in {1..20}; do
    id=$("$helper" CoreTend 2>/dev/null || true)
    [[ -n "$id" ]] && break
    sleep 0.25
  done
fi
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
# And the window must actually be that size. It can refuse: a content minimum
# wider than the target leaves macOS holding it open, and the label alone would
# have called that a compact capture.
shown_size=$(sed -n 's/^size=//p' "$store/showing.txt")
case $size in
  compact)  want="1000x700";;
  standard) want="1180x800";;
  large)    want="1600x860";;
esac
if [[ "$shown_size" != "$want" ]]; then
  print -u2 "capture-module: asked for $size ($want) but the window is $shown_size — capture refused"
  rm -f "$out"; exit 2
fi
print "captured: $module $appearance $size ${seed:+seed=$seed }${state:+state=$state }${tab:+tab=$tab }-> $out"
