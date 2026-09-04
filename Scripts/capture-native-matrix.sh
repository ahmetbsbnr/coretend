#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
# Captures every native module in EN/FR and light/dark. Screenshots are
# evidence candidates only: a human must inspect them before accepting them.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-Documentation/VisualAudit/Matrix}"
APP="${CORETEND_CAPTURE_APP:-build/CoreTend.app}"
STORE="$(mktemp -d /tmp/coretend-capture-store.XXXXXX)"

cleanup() {
  pkill -x CoreTend >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

[ -d "$APP" ] || { print -u2 "FAIL: $APP missing; run Scripts/package-local.sh"; exit 1; }
mkdir -p "$OUT"

modules_en=("Dashboard" "Storage" "Space Lens" "Duplicates" "Applications" "My Clutter" "Cloud Cleanup" "Performance" "Integrity" "Activity" "Settings")
modules_fr=("Tableau de bord" "Stockage" "Space Lens" "Doublons" "Applications" "Mes fichiers encombrants" "Cloud Cleanup" "Performance" "Intégrité" "Activité" "Réglages")
slugs=(dashboard storage space-lens duplicates applications my-clutter cloud-cleanup performance integrity activity settings)

for locale in en fr; do
  if [[ "$locale" == en ]]; then
    labels=("${modules_en[@]}")
    apple_locale="en_US"
  else
    labels=("${modules_fr[@]}")
    apple_locale="fr_FR"
  fi
  for appearance in light dark; do
    pkill -x CoreTend >/dev/null 2>&1 || true
    CORETEND_TEST_MODE=1 CORETEND_TEST_STORE_DIR="$STORE" \
      CORETEND_TEST_APPEARANCE="$appearance" \
      "$APP/Contents/MacOS/CoreTend" \
      -AppleLanguages "($locale)" -AppleLocale "$apple_locale" \
      -appLanguage "$locale" -onboardingDone YES \
      >/tmp/coretend-capture.log 2>&1 &
    sleep 3
    for (( i=1; i<=${#labels}; i++ )); do
      target="$OUT/${locale}-${appearance}-${slugs[$i]}.png"
      captured=0
      for attempt in 1 2 3; do
        if Scripts/capture.sh "$target" "${labels[$i]}"; then
          captured=1
          break
        fi
        print -u2 "WARN: capture retry $attempt/3 for ${labels[$i]}"
        sleep 2
      done
      [[ "$captured" == 1 ]] || { rm -f "$target"; print -u2 "FAIL: $target"; exit 1; }
    done
  done
done

count=$(find "$OUT" -type f -name '*.png' | wc -l | tr -d ' ')
[[ "$count" == 44 ]] || { print -u2 "FAIL: expected 44 PNGs, found $count"; exit 1; }
print "PASS: 44 native captures written to $OUT"
print "HUMAN_REVIEW_REQUIRED: inspect every image; capture success is not visual-QA acceptance"
