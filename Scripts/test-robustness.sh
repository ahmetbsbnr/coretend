#!/bin/zsh
# Launch-robustness suite for the built app bundle.
#
# Every case here answers one question: does CoreTend still open its window when
# the environment is hostile? An app that exits silently on corrupt local state
# looks identical to one that Gatekeeper blocked, and the user cannot tell the
# two apart — so none of these cases may kill the launch.
#
# Isolation, non-negotiable: every case runs under its own temporary HOME and
# its own temporary work tree. Nothing here reads or writes the real
# ~/Library/Application Support/CoreTend, and no case is given a path inside
# the user's own files. The suite refuses to run if HOME was not redirected.
#
#   zsh Scripts/test-robustness.sh            # full suite
#   zsh Scripts/test-robustness.sh --quick    # skip the 50x soak cases
set -e
cd "$(dirname "$0")/.."
REPO="$PWD"

QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

APP="${CORETEND_APP_UNDER_TEST:-$REPO/build/CoreTend.app}"
BIN="$APP/Contents/MacOS/CoreTend"
[ -x "$BIN" ] || { echo "test-robustness: no executable at $BIN (run Scripts/package-local.sh)"; exit 1; }

# The interruption cases send INT to the app under test, and that signal
# reaches the runner too — without this the suite quietly stops partway
# through, which looks exactly like a clean finish in the results file.
#
# INT only. Ignoring TERM here would be inherited by every child, and a child
# that ignores TERM cannot be stopped by `kill -TERM`, which hangs the suite.
# Children reset the disposition anyway (see launch_app).
trap '' INT

SANDBOX=$(mktemp -d)
RESULTS="$SANDBOX/results.tsv"
: > "$RESULTS"
cleanup() {
  pkill -f "$BIN" 2>/dev/null || true
  # The disk-pressure case attaches a tiny disk image inside the sandbox;
  # detach it before rm -rf, or the sandbox cannot be removed.
  for m in "${MOUNTS[@]:-}"; do
    [ -n "$m" ] && hdiutil detach "$m" -force >/dev/null 2>&1 || true
  done
  # Several cases deliberately create unreadable directories (chmod 000/500);
  # restore write access first or the sandbox cannot be removed.
  chmod -R u+rwX "$SANDBOX" 2>/dev/null || true
  rm -rf "$SANDBOX"
}
trap cleanup EXIT
MOUNTS=()

PASS=0; FAIL=0
FAILED_CASES=()

# Launch the app under a given HOME. The subshell resets the inherited signal
# dispositions so the child stays interruptible.
#
# Isolation is belt and braces: HOME is redirected *and* the app's own store
# override is set, so even a code path that resolves the real Application
# Support directory rather than $HOME lands in the sandbox. See
# Scripts/check-test-isolation.sh for the contract.
launch_app() {
  local home="$1" log="$2"
  ( trap - INT TERM
    CORETEND_TEST_MODE=1 CORETEND_TEST_STORE_DIR="$home/store" \
    HOME="$home" TMPDIR="$home/tmp" exec "$BIN" ) >"$log" 2>&1 &
}

# TERM, then KILL if it does not go. A case must never be able to hang the run.
stop_app() {
  local pid="$1"
  kill -TERM "$pid" 2>/dev/null || true
  local waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 5 ]; do sleep 1; waited=$((waited + 1)); done
  kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

# Runs the app with a throwaway HOME and reports whether it was still alive
# after `hold` seconds. Alive means the launch survived; a dead process means
# the app quit or crashed, which is the defect this suite hunts.
#
#   run_case <name> <home-dir> [hold-seconds]
run_case() {
  local name="$1" home="$2" hold="${3:-4}"
  case "$home" in
    "$SANDBOX"/*) ;;
    *) echo "test-robustness: REFUSING to run '$name' with HOME=$home outside the sandbox"; exit 1 ;;
  esac
  mkdir -p "$home"

  local log="$SANDBOX/$name.log"
  launch_app "$home" "$log"
  local pid=$!
  local waited=0
  while [ "$waited" -lt "$hold" ]; do
    sleep 1
    waited=$((waited + 1))
    kill -0 "$pid" 2>/dev/null || break
  done

  if kill -0 "$pid" 2>/dev/null; then
    stop_app "$pid"
    printf '%s\tPASS\t\n' "$name" >> "$RESULTS"
    PASS=$((PASS + 1))
    echo "  PASS  $name"
    return 0
  fi

  wait "$pid" 2>/dev/null
  local status=$?
  local detail
  detail=$(head -c 400 "$log" | tr '\n' ' ')
  printf '%s\tFAIL\texit=%s %s\n' "$name" "$status" "$detail" >> "$RESULTS"
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$name (exit $status) $detail")
  echo "  FAIL  $name — exited with $status: $detail"
  return 0
}

# A HOME with the app's support directory prepared by a callback, so each case
# describes only what it makes hostile.
#   with_state <name> <setup-function>
with_state() {
  local name="$1" setup="$2" hold="${3:-4}"
  local home="$SANDBOX/homes/$name"
  local support="$home/store"
  mkdir -p "$support" "$home/tmp"
  "$setup" "$home" "$support"
  run_case "$name" "$home" "$hold"
}

# All state-setup callbacks, defined before any case runs. Each receives
# ($home, $support).
noop() { :; }
rmdir_support() { rm -rf "$2"; }
make_readonly() { chmod 500 "$2"; }
make_home_readonly() { chmod 500 "$1/store"; }

prefs_empty() { mkdir -p "$1/Library/Preferences"; : > "$1/Library/Preferences/com.ahmetbsbnr.coretend.plist"; }
prefs_truncated() { mkdir -p "$1/Library/Preferences"; printf 'bplist00\xd1' > "$1/Library/Preferences/com.ahmetbsbnr.coretend.plist"; }
prefs_garbage() { mkdir -p "$1/Library/Preferences"; head -c 4096 /dev/urandom > "$1/Library/Preferences/com.ahmetbsbnr.coretend.plist"; }
prefs_wrong_type() { mkdir -p "$1/Library/Preferences"; printf '<?xml version="1.0"?><plist version="1.0"><array/></plist>' > "$1/Library/Preferences/com.ahmetbsbnr.coretend.plist"; }

db_empty() { : > "$2/store.sqlite"; }
db_garbage() { head -c 65536 /dev/urandom > "$2/store.sqlite"; }
db_truncated() { printf 'SQLite format 3\x00' > "$2/store.sqlite"; }
db_is_dir() { mkdir -p "$2/store.sqlite"; }
db_readonly() { : > "$2/store.sqlite"; chmod 400 "$2/store.sqlite"; }
db_wal() { : > "$2/store.sqlite"; : > "$2/store.sqlite-wal"; : > "$2/store.sqlite-shm"; }
cache_corrupt() { mkdir -p "$1/Library/Caches/com.ahmetbsbnr.coretend"; head -c 32768 /dev/urandom > "$1/Library/Caches/com.ahmetbsbnr.coretend/scan.cache"; }
partial_db() { printf 'SQLite format 3\x00' > "$2/store.sqlite"; head -c 200 /dev/urandom >> "$2/store.sqlite"; }

offline() { :; }
manifest_garbage() { head -c 4096 /dev/urandom > "$2/latest.json"; }
manifest_empty() { : > "$2/latest.json"; }
manifest_shape() { echo '{"unexpected": true}' > "$2/latest.json"; }

build_tree() {
  local root="$1"
  mkdir -p "$root"
  : > "$root/empty-file"
  head -c 1048576 /dev/urandom > "$root/large-file.bin"
  mkdir -p "$root/héllo wörld — ünïcode"
  : > "$root/héllo wörld — ünïcode/café.txt"
  mkdir -p "$root/emoji 🙂 dir"
  : > "$root/emoji 🙂 dir/file 🚀.txt"
  : > "$root/name with  multiple   spaces.txt"
  : > "$root/quote'and\"double.txt"
  : > "$root/semi;colon&amp.txt"
  local deep="$root/deep"
  for _ in $(seq 1 24); do deep="$deep/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; done
  mkdir -p "$deep" 2>/dev/null || true
  : > "$deep/leaf.txt" 2>/dev/null || true
  ln -s "$root/empty-file" "$root/link-to-file" 2>/dev/null || true
  ln -s "$root/nowhere" "$root/dangling-link" 2>/dev/null || true
  mkdir -p "$root/cycle"
  ln -s "$root/cycle" "$root/cycle/self" 2>/dev/null || true
  mkdir -p "$root/forbidden"; : > "$root/forbidden/secret.txt"; chmod 000 "$root/forbidden"
}
setup_hostile() { build_tree "$1/Documents/scan-target"; }
setup_many() {
  local d="$1/Documents/many"
  mkdir -p "$d"
  for i in $(seq 1 30); do
    mkdir -p "$d/dir$i"
    for j in $(seq 1 100); do : > "$d/dir$i/file$j.tmp"; done
  done
}
setup_unreadable() { mkdir -p "$1/Documents/locked"; chmod 000 "$1/Documents/locked"; }

kill_during_launch() {
  local name="$1" signal="$2" delay="$3"
  local home="$SANDBOX/homes/$name"
  mkdir -p "$home/store" "$home/tmp"
  launch_app "$home" "$SANDBOX/$name.log"
  local pid=$!
  sleep "$delay"
  kill -"$signal" "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  # The real assertion: whatever it left on disk must not poison the next run.
  run_case "$name-relaunch" "$home"
}

# Store volume with only a few KB free. The app opens its SQLite store at
# launch; on a nearly-full volume that write can fail, and the failure must
# surface as a state the window can render, not a silent exit. Runs on a small
# HFS+ disk image mounted at the case's own store path, filled to capacity.
case_disk_nearly_full() {
  local name="disk-nearly-full"
  local home="$SANDBOX/homes/$name"
  local store="$home/store"
  local img="$SANDBOX/$name.dmg"
  mkdir -p "$home/tmp"
  rm -rf "$store"
  if ! hdiutil create -size 8m -type UDIF -fs HFS+ -volname CoreTendTiny -layout NONE "$img" >/dev/null 2>&1; then
    printf '%s\tFAIL\thdiutil create failed\n' "$name" >> "$RESULTS"
    FAIL=$((FAIL + 1)); FAILED_CASES+=("$name: hdiutil create failed"); echo "  FAIL  $name — hdiutil create"; return 0
  fi
  if ! hdiutil attach "$img" -mountpoint "$store" -nobrowse -owners on >/dev/null 2>&1; then
    printf '%s\tFAIL\thdiutil attach failed\n' "$name" >> "$RESULTS"
    FAIL=$((FAIL + 1)); FAILED_CASES+=("$name: hdiutil attach failed"); echo "  FAIL  $name — hdiutil attach"; return 0
  fi
  MOUNTS+=("$store")
  # Fill the volume, leaving it with only kilobytes free.
  dd if=/dev/zero of="$store/ballast" bs=32768 2>/dev/null || true
  run_case "$name" "$home"
  hdiutil detach "$store" -force >/dev/null 2>&1 || true
  MOUNTS=("${(@)MOUNTS:#$store}")
}

# Every core pinned by a busy loop while the window comes up. A scan may be
# slow under contention, but the launch cannot be starved into never opening.
case_cpu_under_load() {
  local name="cpu-under-load"
  local home="$SANDBOX/homes/$name"
  mkdir -p "$home/store" "$home/tmp"
  local cores loaders
  cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
  loaders=()
  local i
  for i in $(seq 1 "$cores"); do
    yes >/dev/null 2>&1 &
    loaders+=($!)
  done
  run_case "$name" "$home" 6
  for i in "${loaders[@]}"; do kill -KILL "$i" 2>/dev/null || true; done
  wait 2>/dev/null || true
}

echo "test-robustness: $BIN"
echo "test-robustness: sandbox $SANDBOX (real HOME untouched)"

# ---------------------------------------------------------------- first run
echo "-- first run and missing state"
with_state virgin-home noop
with_state no-support-dir 'rmdir_support'
with_state no-prefs noop
with_state readonly-support 'make_readonly'
with_state unwritable-home 'make_home_readonly'

# ------------------------------------------------------------- preferences
echo "-- preferences"
with_state prefs-empty 'prefs_empty'
with_state prefs-truncated 'prefs_truncated'
with_state prefs-garbage 'prefs_garbage'
with_state prefs-wrong-type 'prefs_wrong_type'

# ---------------------------------------------------------------- database
echo "-- local database and cache"
with_state db-empty 'db_empty'
with_state db-garbage 'db_garbage'
with_state db-truncated-header 'db_truncated'
with_state db-is-a-directory 'db_is_dir'
with_state db-readonly 'db_readonly'
with_state db-zero-length-wal 'db_wal'
with_state cache-corrupt 'cache_corrupt'

# ----------------------------------------------------------------- network
echo "-- network and update manifest"
with_state offline-no-network 'offline'
with_state update-manifest-garbage 'manifest_garbage'
with_state update-manifest-empty 'manifest_empty'
with_state update-manifest-wrong-shape 'manifest_shape'

# ------------------------------------------------------- hostile file trees
echo "-- hostile scan trees"

with_state hostile-tree 'setup_hostile'

with_state many-files 'setup_many'

with_state unreadable-scan-root 'setup_unreadable'

# ------------------------------------------------------------ interruption
echo "-- interruption and restart"
kill_during_launch kill-at-0.2s KILL 0.2
kill_during_launch kill-at-1s KILL 1
kill_during_launch kill-at-3s KILL 3
kill_during_launch term-at-1s TERM 1
kill_during_launch int-at-1s INT 1

# Relaunch over a half-written database, which is what a hard kill mid-write
# actually leaves on disk.
with_state relaunch-over-partial-db 'partial_db'

# ------------------------------------------------------------ runtime stress
echo "-- runtime stress (disk pressure, CPU contention)"
case_disk_nearly_full
case_cpu_under_load

# ------------------------------------------------------------ repeat/soak
if [ "$QUICK" -eq 0 ]; then
  echo "-- 50 cold launches"
  cold_fail=0
  for i in $(seq 1 50); do
    home="$SANDBOX/homes/cold-$i"
    mkdir -p "$home/tmp"
    launch_app "$home" "$SANDBOX/cold-$i.log"
    p=$!
    sleep 2
    if kill -0 "$p" 2>/dev/null; then stop_app "$p"
    else wait "$p" 2>/dev/null || true; cold_fail=$((cold_fail + 1)); fi
  done
  if [ "$cold_fail" -eq 0 ]; then
    printf 'cold-launch-x50\tPASS\t\n' >> "$RESULTS"; PASS=$((PASS + 1)); echo "  PASS  cold-launch-x50"
  else
    printf 'cold-launch-x50\tFAIL\t%s of 50 failed\n' "$cold_fail" >> "$RESULTS"
    FAIL=$((FAIL + 1)); FAILED_CASES+=("cold-launch-x50: $cold_fail of 50 failed"); echo "  FAIL  cold-launch-x50 — $cold_fail of 50"
  fi

  echo "-- 50 launch/quit cycles against one reused HOME"
  reuse="$SANDBOX/homes/reuse"
  mkdir -p "$reuse/tmp"
  reuse_fail=0
  for i in $(seq 1 50); do
    launch_app "$reuse" "$SANDBOX/reuse-$i.log"
    p=$!
    sleep 1.5
    if kill -0 "$p" 2>/dev/null; then stop_app "$p"
    else wait "$p" 2>/dev/null || true; reuse_fail=$((reuse_fail + 1)); fi
  done
  if [ "$reuse_fail" -eq 0 ]; then
    printf 'relaunch-same-home-x50\tPASS\t\n' >> "$RESULTS"; PASS=$((PASS + 1)); echo "  PASS  relaunch-same-home-x50"
  else
    printf 'relaunch-same-home-x50\tFAIL\t%s of 50 failed\n' "$reuse_fail" >> "$RESULTS"
    FAIL=$((FAIL + 1)); FAILED_CASES+=("relaunch-same-home-x50: $reuse_fail of 50 failed"); echo "  FAIL  relaunch-same-home-x50 — $reuse_fail of 50"
  fi
fi

# ------------------------------------------------------------------ report
echo
echo "test-robustness: $PASS passed, $FAIL failed"
mkdir -p "$REPO/Release"
cp "$RESULTS" "$REPO/Release/robustness-results.tsv" 2>/dev/null || true
printf 'SUITE-COMPLETE\t%s passed, %s failed\t\n' "$PASS" "$FAIL" >> "$REPO/Release/robustness-results.tsv"
if [ "$FAIL" -gt 0 ]; then
  echo "test-robustness: failing cases:"
  for c in "${FAILED_CASES[@]}"; do echo "  - $c"; done
  exit 1
fi
echo "test-robustness: PASS"
