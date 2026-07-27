#!/bin/sh
# One-shot setup for a fresh clone: verifies toolchain, resolves packages.
# Idempotent, no sudo, no writes outside the repo and SwiftPM's own caches.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

echo "CoreTend — bootstrap"
echo "Repo: $ROOT_DIR"

if ! command -v swift >/dev/null 2>&1; then
  echo "FAIL: 'swift' not found. Install Xcode or the Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi

echo "OK: swift found -> $(swift --version 2>&1 | head -1)"

echo "Resolving Swift package graph (no external dependencies expected)..."
swift package resolve

echo "Bootstrap complete. Next: Scripts/doctor.sh, then Scripts/build.sh."
