#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
# Starts the application-only part of the human media session. System,
# browser, Finder and Gatekeeper capture remains deliberately manual.
set -eu

full_name="$(id -F 2>/dev/null || true)"
if [[ "$full_name" != "CoreTend Demo" ]]; then
  print -u2 "FAIL: final capture is allowed only from the dedicated demo account"
  exit 1
fi

dataset="/tmp/coretend-demo-dataset"
store="$(mktemp -d /tmp/coretend-demo-store.XXXXXX)"
Scripts/prepare-demo-data.sh "$dataset"
bash Scripts/package-local.sh

print "PASS: dedicated account and synthetic dataset ready"
print "HUMAN_REVIEW_REQUIRED: enable Focus, inspect menu bar/Dock, then record"
CORETEND_TEST_MODE=1 CORETEND_TEST_STORE_DIR="$store" \
  build/CoreTend.app/Contents/MacOS/CoreTend
