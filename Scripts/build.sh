#!/bin/zsh
# Debug or Release build. Usage: build.sh [release]
set -e
cd "$(dirname "$0")/.."
if [[ "$1" == "release" ]]; then
  swift build -c release
else
  swift build
fi
