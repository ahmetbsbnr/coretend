#!/bin/zsh
# Runs the Swift Testing suite with CommandLineTools (no Xcode needed).
set -e
cd "$(dirname "$0")/.."
FWK=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib

# Sweep preference plists left by killed test runs. Every test's isolated
# UserDefaults suite is named `coretend.tests.<UUID>`; its `defer` calls
# removePersistentDomain (which clears cfprefsd's copy) but macOS still leaves a
# ~42-byte stub file in ~/Library/Preferences, and a run killed with SIGKILL
# skips the defer entirely. `defaults delete` cannot touch a file cfprefsd no
# longer tracks, so remove the files directly. Nothing outside the suite uses
# this prefix, so this is safe and keeps the directory clean. `find` (not a
# glob) so the line is inert whether the script is invoked as zsh or bash.
find "$HOME/Library/Preferences" -maxdepth 1 -name 'coretend.tests.*.plist' -delete 2>/dev/null || true
# Several suites deliberately saturate the filesystem. Running those suites
# against each other makes wall-clock cancellation assertions measure runner
# contention instead of cancellation latency. Individual engine tests still
# create concurrent tasks; one test worker only isolates independent fixtures.
swift test --disable-xctest --no-parallel \
  -Xswiftc -F -Xswiftc "$FWK" \
  -Xlinker -F -Xlinker "$FWK" \
  -Xlinker -rpath -Xlinker "$FWK" \
  -Xlinker -rpath -Xlinker "$LIB" "$@"
