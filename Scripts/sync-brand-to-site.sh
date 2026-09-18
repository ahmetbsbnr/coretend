#!/bin/zsh
# Publishes the generated brand assets to the website.
#
# This step did not exist. The generator wrote to Resources/Brand/Generated and
# somebody copied files into Website/assets/brand by hand, which is how the two
# came to hold different artwork: the app icon, the DMG background and the Open
# Graph card were regenerated in a new palette while every favicon the site
# serves stayed in the previous one — and a favicon is the identity a browser
# tab shows before anyone has opened anything.
#
# Run after `swift Resources/Brand/Sources/generate-brand-assets.swift`.
# `--check` verifies without writing, and is what CI runs.
set -euo pipefail
cd "$(dirname "$0")/.."

GEN="Resources/Brand/Generated"
SITE="Website/assets/brand"

# generated file -> published name. Written out rather than inferred: the
# site's names are a public URL contract (they appear in index.html, the web
# manifest and every cached link preview), so a rename must be a deliberate
# edit here, not a side effect of renaming a source file.
typeset -A MAP=(
  "Favicon-16.png"            "favicon-v2-16.png"
  "Favicon-32.png"            "favicon-v2-32.png"
  "Favicon-180.png"           "favicon-v2-180.png"
  "Favicon-512.png"           "favicon-v2-512.png"
  "Mark-dark.svg"             "mark-dark.svg"
  "Mark-light.svg"            "mark-light.svg"
  "OpenGraph-1200x630.png"    "opengraph.png"
)

check_only=0
[[ "${1:-}" == "--check" ]] && check_only=1

drift=0
for source published in "${(@kv)MAP}"; do
  src="$GEN/$source"
  dst="$SITE/$published"
  if [[ ! -f "$src" ]]; then
    print -u2 "missing generated asset: $src"
    print -u2 "  run: swift Resources/Brand/Sources/generate-brand-assets.swift"
    exit 1
  fi
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    continue
  fi
  if (( check_only )); then
    print -u2 "drifted: $dst does not match $src"
    drift=1
  else
    cp "$src" "$dst"
    print "synced: $source -> $published"
  fi
done

if (( check_only )); then
  if (( drift )); then
    print -u2 ""
    print -u2 "The website is serving different brand artwork from the app."
    print -u2 "Run: zsh Scripts/sync-brand-to-site.sh && git add Website/assets/brand"
    exit 1
  fi
  print "brand assets: app and website match"
fi
