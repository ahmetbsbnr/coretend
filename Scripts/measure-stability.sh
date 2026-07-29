#!/bin/zsh
# Startup, memory, CPU and handle measurements for the built app bundle.
#
# Runs entirely under a temporary HOME, so nothing here touches the user's real
# CoreTend state. Numbers land in Release/stability-metrics.txt.
#
# What each number is for: cold launch time is what a user feels; RSS growth
# across repeated launches is what turns into a leak report three weeks later;
# leftover file descriptors and stray child processes are what make the second
# launch behave differently from the first.
set -e
cd "$(dirname "$0")/.."
REPO="$PWD"

APP="${CORETEND_APP_UNDER_TEST:-$REPO/build/CoreTend.app}"
BIN="$APP/Contents/MacOS/CoreTend"
[ -x "$BIN" ] || { echo "measure-stability: no executable at $BIN"; exit 1; }

SANDBOX=$(mktemp -d)
OUT="$REPO/Release/stability-metrics.txt"
mkdir -p "$REPO/Release"
cleanup() { pkill -f "$BIN" 2>/dev/null || true; rm -rf "$SANDBOX"; }
trap cleanup EXIT

say() { echo "$1"; echo "$1" >> "$OUT"; }
: > "$OUT"

say "CoreTend stability measurements"
say "date:    $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
say "binary:  $BIN"
say "host:    macOS $(sw_vers -productVersion) $(uname -m)"
say ""

# ---------------------------------------------------------- cold launch time
say "-- cold launch (10 runs, fresh HOME each)"
total=0
for i in $(seq 1 10); do
  home="$SANDBOX/cold-$i"; mkdir -p "$home/tmp"
  start=$(python3 -c 'import time; print(time.time())')
  HOME="$home" TMPDIR="$home/tmp" "$BIN" >/dev/null 2>&1 &
  pid=$!
  # First window is not observable from outside without automation, so this
  # measures time to a live, settled process — the floor under that number.
  while ! ps -p "$pid" -o rss= >/dev/null 2>&1; do sleep 0.02; done
  end=$(python3 -c 'import time; print(time.time())')
  ms=$(python3 -c "print(round(($end - $start) * 1000))")
  total=$((total + ms))
  kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
done
say "  mean process-live time: $((total / 10)) ms over 10 runs"

# ------------------------------------------------------------- idle resources
say ""
say "-- idle footprint (settled 8 s after launch)"
home="$SANDBOX/idle"; mkdir -p "$home/tmp"
HOME="$home" TMPDIR="$home/tmp" "$BIN" >/dev/null 2>&1 &
idle_pid=$!
sleep 8
if kill -0 "$idle_pid" 2>/dev/null; then
  rss=$(ps -p "$idle_pid" -o rss= | tr -d ' ')
  cpu=$(ps -p "$idle_pid" -o %cpu= | tr -d ' ')
  fds=$(lsof -p "$idle_pid" 2>/dev/null | wc -l | tr -d ' ')
  threads=$(ps -M "$idle_pid" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
  say "  resident memory: $((rss / 1024)) MiB"
  say "  cpu at idle:     ${cpu}%"
  say "  open fds:        $fds"
  say "  threads:         $threads"

  say ""
  say "-- drift over a 60 s idle session"
  sleep 60
  if kill -0 "$idle_pid" 2>/dev/null; then
    rss2=$(ps -p "$idle_pid" -o rss= | tr -d ' ')
    fds2=$(lsof -p "$idle_pid" 2>/dev/null | wc -l | tr -d ' ')
    say "  resident memory: $((rss2 / 1024)) MiB (delta $(( (rss2 - rss) / 1024 )) MiB)"
    say "  open fds:        $fds2 (delta $((fds2 - fds)))"
  else
    say "  process exited during the idle window — investigate"
  fi
  kill -TERM "$idle_pid" 2>/dev/null || true; wait "$idle_pid" 2>/dev/null || true
else
  say "  process did not survive 8 s — no idle numbers"
fi

# ------------------------------------------------- repeated launch/quit churn
say ""
say "-- 100 launch/quit cycles against one reused HOME"
home="$SANDBOX/churn"; mkdir -p "$home/tmp"
first_rss=""; last_rss=""
for i in $(seq 1 100); do
  HOME="$home" TMPDIR="$home/tmp" "$BIN" >/dev/null 2>&1 &
  p=$!
  sleep 0.6
  if kill -0 "$p" 2>/dev/null; then
    r=$(ps -p "$p" -o rss= 2>/dev/null | tr -d ' ')
    [ -n "$r" ] && { [ -z "$first_rss" ] && first_rss=$r; last_rss=$r; }
    kill -TERM "$p" 2>/dev/null || true
  fi
  wait "$p" 2>/dev/null || true
done
if [ -n "$first_rss" ] && [ -n "$last_rss" ]; then
  say "  rss at cycle 1:   $((first_rss / 1024)) MiB"
  say "  rss at cycle 100: $((last_rss / 1024)) MiB"
  say "  drift:            $(( (last_rss - first_rss) / 1024 )) MiB"
fi
say "  support dir size after 100 cycles: $(du -sh "$home/Library/Application Support/CoreTend" 2>/dev/null | cut -f1 || echo n/a)"

# ------------------------------------------------------------------- residue
say ""
say "-- residue"
stray=$(pgrep -f "$BIN" | wc -l | tr -d ' ')
say "  stray CoreTend processes after the suite: $stray"
tmp_left=$(find "$SANDBOX" -name '*.tmp' -o -name 'coretend-*' 2>/dev/null | wc -l | tr -d ' ')
say "  temporary files left in the sandbox:      $tmp_left"

say ""
say "measurements written to Release/stability-metrics.txt"
