#!/bin/zsh
# Runs the Swift Testing suite with CommandLineTools (no Xcode needed).
set -e
cd "$(dirname "$0")/.."
FWK=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
swift test --disable-xctest \
  -Xswiftc -F -Xswiftc "$FWK" \
  -Xlinker -F -Xlinker "$FWK" \
  -Xlinker -rpath -Xlinker "$FWK" \
  -Xlinker -rpath -Xlinker "$LIB" "$@"
