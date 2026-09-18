#!/bin/zsh
# capture-matrix.sh — the UI QA matrix (docs/UI_QA_MATRIX.md), as pictures.
#
# Builds the app, then captures every module in both appearances at the sizes
# that matter for it, on seeded fixtures and — where a module has a
# data-bearing state — waiting for that state. Each file name encodes what it
# is; the capture script refuses any image whose module, appearance, size or
# state differ from what was asked, so a file that exists is a file that shows
# what its name says. Ends by writing Documentation/Captures/index.html.
set -euo pipefail
cd "$(dirname "$0")/.."
out="Documentation/Captures"
mkdir -p "$out"
bash Scripts/package-local.sh >/dev/null

seeds="seed-record.sh,seed-apps.sh"
export CORETEND_CAPTURE_HOME_SEED=seed-cleanup-home.sh

# module:state:sizes — sizes "csl" = compact, standard, large
specs=(
  "smartCare::csl"
  "record::csl"
  "cleanup:review:cs"
  "spaceLens:ready:csl"
  "duplicates:results:cs"
  "applications::cs"
  "protection::s"
  "performance:charting:s"
)
failed=0
for spec in $specs; do
  module="${spec%%:*}"; rest="${spec#*:}"; state="${rest%%:*}"; sizes="${rest#*:}"
  for appearance in dark light; do
    for c in ${(s::)sizes}; do
      case $c in c) size=compact;; s) size=standard;; l) size=large;; esac
      name="$out/${module}-${state:-idle}-${appearance}-${size}.png"
      if zsh Scripts/capture-module.sh "$name" "$module" "$appearance" "$size" "$seeds" "$state" >/dev/null 2>&1; then
        print "ok   $name"
      else
        print "FAIL $module $appearance $size $state"; failed=$((failed+1))
      fi
    done
  done
done
python3 Scripts/check-sidebar-rendered.py "$out"/*.png | tail -1
python3 Scripts/build-gallery.py "$out"
print "matrix done, $failed failed"
[[ $failed -eq 0 ]]
