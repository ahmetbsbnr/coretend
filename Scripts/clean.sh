#!/bin/sh
# Removes build artifacts only (.build, DerivedData under this repo, test
# result bundles). Never touches app-installed data, ~/Library, or files
# outside the repo. No sudo. Safe to run from any working directory.
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

echo "MacCare Local — clean"
echo "Removing build artifacts under: $ROOT_DIR"

for path in .build .swiftpm/xcode/DerivedData; do
  if [ -e "$path" ]; then
    echo "  removing $path"
    rm -rf -- "$path"
  fi
done

find . -maxdepth 2 -name "*.xcresult" -exec rm -rf -- {} + 2>/dev/null || true

echo "clean: done. Run Scripts/build.sh to rebuild."
