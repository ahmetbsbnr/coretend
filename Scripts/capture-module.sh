#!/bin/zsh
# capture-module.sh <out.png> <moduleRawValue>
#
# Launches a fresh, isolated CoreTend on the named module and captures its
# window. Replaces the AppleScript sidebar walk in capture.sh, which bound every
# screenshot to one AppKit view hierarchy (and broke the moment the sidebar
# stopped being a List) and which is flaky across rapid relaunches — the AX tree
# intermittently reports an empty window.
#
# Module raw values: smartCare cleanup protection performance applications
#                    duplicates myClutter spaceLens cloudCleanup myActivity settings
set -euo pipefail
out="${1:?usage: $0 <out.png> <module>}"
module="${2:?usage: $0 <out.png> <module>}"
app="${CORETEND_APP:-build/CoreTend.app}"
mkdir -p "$(dirname "$out")"

store="$(mktemp -d "${TMPDIR:-/tmp}/coretend-capture.XXXXXX")"
cleanup() { rm -rf "$store"; }
trap cleanup EXIT

pkill -x CoreTend 2>/dev/null || true
sleep 1
CORETEND_TEST_MODE=1 \
CORETEND_TEST_STORE_DIR="$store" \
CORETEND_TEST_MODULE="$module" \
  open -n "$app"

# Wait for the window rather than sleeping a fixed amount.
for _ in {1..40}; do
  if osascript -e 'tell application "System Events" to tell process "CoreTend" to return count of windows' 2>/dev/null | grep -qv '^0$'; then
    break
  fi
  sleep 0.25
done
sleep 1.5

osascript -e 'tell application "System Events" to tell process "CoreTend" to set frontmost to true' >/dev/null 2>&1 || true
sleep 0.5

# Capture the window itself, by its CoreGraphics window id.
#
# Two earlier attempts were wrong and both failed silently, which is worse than
# failing loudly:
#   - `AXWindowNumber` is not a real accessibility attribute, so `-l` received
#     nothing and the script fell back to capturing the whole screen.
#   - Capturing the window's AX rectangle with `-R` captures a screen *region*,
#     so anything overlapping CoreTend — a browser, this terminal — ended up in
#     the "app screenshot".
#
# `screencapture -l <cgWindowID>` captures that window's own surface regardless
# of what is in front of it. The id comes from CGWindowListCopyWindowInfo via a
# tiny helper, because no shell tool exposes it.
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
print "captured: $module -> $out  (window $id)"
