#!/bin/zsh
# Runs the Swift Testing suite with CommandLineTools (no Xcode needed).
set -e
cd "$(dirname "$0")/.."
FWK=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
# Several suites deliberately saturate the filesystem. Running those suites
# against each other makes wall-clock cancellation assertions measure runner
# contention instead of cancellation latency. Individual engine tests still
# create concurrent tasks; one test worker only isolates independent fixtures.
swift test --disable-xctest --no-parallel \
  -Xswiftc -F -Xswiftc "$FWK" \
  -Xlinker -F -Xlinker "$FWK" \
  -Xlinker -rpath -Xlinker "$FWK" \
  -Xlinker -rpath -Xlinker "$LIB" "$@"
