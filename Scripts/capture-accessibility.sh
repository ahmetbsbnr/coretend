#!/bin/zsh
# capture-accessibility.sh — the same screens under the accessibility settings
# that change how they are drawn.
#
# Increase Contrast and Reduce Transparency are system-wide settings; there is
# no per-app switch and no environment variable. This script therefore changes
# them, captures, and puts them back — including on failure, via a trap, so an
# interrupted run does not leave someone's Mac reconfigured.
set -euo pipefail
cd "$(dirname "$0")/.."
out="Documentation/Captures/accessibility"
mkdir -p "$out"

before_contrast=$(defaults read com.apple.universalaccess increaseContrast 2>/dev/null || echo 0)
before_transparency=$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo 0)
before_accent=$(defaults read -g AppleAccentColor 2>/dev/null || echo "__unset__")
restore() {
  defaults write com.apple.universalaccess increaseContrast -int "$before_contrast"
  defaults write com.apple.universalaccess reduceTransparency -int "$before_transparency"
  if [[ "$before_accent" == "__unset__" ]]; then
    defaults delete -g AppleAccentColor 2>/dev/null || true
  else
    defaults write -g AppleAccentColor -int "$before_accent"
  fi
  print "restored: contrast=$before_contrast transparency=$before_transparency accent=$before_accent"
}
trap restore EXIT

seeds="seed-record.sh,seed-apps.sh"
shot () { # name module appearance
  zsh Scripts/capture-module.sh "$out/$1.png" "$2" "$3" standard "$seeds" >/dev/null \
    && print "ok   $1" || print "FAIL $1"
}

defaults write com.apple.universalaccess increaseContrast -int 1
defaults write com.apple.universalaccess reduceTransparency -int 0
shot "overview-increase-contrast-dark"  smartCare dark
shot "overview-increase-contrast-light" smartCare light
shot "record-increase-contrast-dark"    record    dark

defaults write com.apple.universalaccess increaseContrast -int 0
defaults write com.apple.universalaccess reduceTransparency -int 1
shot "overview-reduce-transparency-dark"  smartCare dark
shot "overview-reduce-transparency-light" smartCare light

defaults write com.apple.universalaccess reduceTransparency -int 0
# Four of the seven system accents, including the two furthest from teal.
for pair in "0:red" "3:green" "5:purple" "6:pink"; do
  defaults write -g AppleAccentColor -int "${pair%%:*}"
  shot "overview-accent-${pair##*:}-dark" smartCare dark
done
