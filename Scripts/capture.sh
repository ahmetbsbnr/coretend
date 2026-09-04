#!/bin/zsh
# capture.sh <out.png> [ModuleName] — activates CoreTend, selects sidebar row by name, captures window.
set -euo pipefail
out="${1:?Usage: $0 <out.png> [ModuleName]}"; name="${2:-}"
mkdir -p "$(dirname "$out")"
osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "CoreTend") to true'
sleep 0.6
if [[ -n "$name" ]]; then
osascript <<APPLESCRIPT >/dev/null
tell application "System Events" to tell process "CoreTend"
  set foundModule to false
  set theOutline to outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of front window
  repeat with r in rows of theOutline
    try
      if value of static text 1 of UI element 1 of r is "$name" then
        select r
        set foundModule to true
        exit repeat
      end if
    end try
  end repeat
  if foundModule is false then error "CoreTend sidebar module not found: $name"
end tell
APPLESCRIPT
sleep 1.2
fi
geo=$(osascript -e 'tell application "System Events" to tell (first process whose name is "CoreTend") to get {position, size} of front window' | tr -d ' ')
IFS=',' read x y w h <<< "$geo"
screencapture -x -R$x,$y,$w,$h "$out"
[ -s "$out" ] || { print -u2 "FAIL: empty capture: $out"; exit 1; }
print "PASS: $out"
