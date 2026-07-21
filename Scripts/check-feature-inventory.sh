#!/bin/sh
# Recomputes total/status-count/module numbers straight from
# Documentation/feature-inventory.json and fails if FEATURE_INVENTORY.md or
# feature-inventory.csv have drifted from it — the regression this guards
# against: status_counts (or the .md/.csv) hand-edited independently of the
# features array, going stale (this happened: declared 26/5/5 while the
# array actually held 42 entries at 34/4/4).
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"
python3 Scripts/generate-feature-inventory.py --check
