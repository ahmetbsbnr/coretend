#!/bin/zsh
# Publishes verified captures to the website's screenshot slots.
#
# The site's app images were hand-made and drifted: they showed a radial
# bubble map and a "Dashboard" long after neither existed. These come from
# Documentation/Captures, which the capture script refuses to write unless the
# app reported showing exactly that module, appearance and size — so what the
# marketing page claims and what the app does cannot diverge silently again.
#
# Run Scripts/capture-matrix.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."
src="Documentation/Captures"
dest="Website/assets/app"
mkdir -p "$dest"

# site slot <- capture. Light, because the page is paper-coloured.
typeset -A slots=(
  smart-care  "smartCare-idle-light-standard.png"
  space-lens  "spaceLens-ready-light-standard.png"
  cleanup     "cleanup-review-light-standard.png"
  record      "record-idle-light-standard.png"
)
for slot capture in ${(kv)slots}; do
  [[ -f "$src/$capture" ]] || { print -u2 "missing capture: $capture — run capture-matrix.sh"; exit 1; }
  cwebp -quiet -q 82 -resize 2024 0 "$src/$capture" -o "$dest/$slot.webp"
  print "published $slot.webp <- $capture"
done
