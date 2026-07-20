#!/bin/zsh
# capture.sh <out.png> [ModuleName] — activates MacCareLocal, selects sidebar row by name, captures window.
set -e
out="$1"; name="$2"
osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "MacCareLocal") to true'
sleep 0.6
if [[ -n "$name" ]]; then
osascript <<APPLESCRIPT >/dev/null
tell application "System Events" to tell process "MacCareLocal"
  set theOutline to outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of front window
  repeat with r in rows of theOutline
    try
      if value of static text 1 of UI element 1 of r is "$name" then
        select r
        exit repeat
      end if
    end try
  end repeat
end tell
APPLESCRIPT
sleep 1.2
fi
geo=$(osascript -e 'tell application "System Events" to tell (first process whose name is "MacCareLocal") to get {position, size} of front window' | tr -d ' ')
IFS=',' read x y w h <<< "$geo"
screencapture -x -R$x,$y,$w,$h "$out"
