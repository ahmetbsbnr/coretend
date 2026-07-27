#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

roots=(Documentation/Images Website/assets/app Website/assets/demos)
files=()
for root in "${roots[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' file; do files+=("$file"); done \
    < <(find "$root" -type f -print0)
done

if (( ${#files[@]} == 0 )); then
  printf '%s\n' "HUMAN_REVIEW_REQUIRED: no final media is present"
  exit 0
fi

fail=0
allowed='png|webp|avif|mp4|webm|vtt|txt'
for file in "${files[@]}"; do
  base="${file##*/}"
  ext="${base##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  if [[ ! "$ext" =~ ^($allowed)$ ]]; then
    printf '%s\n' "FAIL: unapproved media extension"
    fail=1
  fi
  if [[ "$base" =~ '[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-' ]]; then
    printf '%s\n' "FAIL: identifier-like media filename"
    fail=1
  fi
  if (( $(stat -f %z "$file") > 10000000 )); then
    printf '%s\n' "FAIL: media exceeds 10 MB"
    fail=1
  fi
done

text_files=()
for file in "${files[@]}"; do
  case "$file" in
    *.png|*.webp|*.avif|*.mp4|*.webm) ;;
    *) text_files+=("$file") ;;
  esac
done
if (( ${#text_files[@]} > 0 )); then
  if rg -l -i '/Users/|file://|localhost|vercel\\.app|[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[A-Za-z]{2,}|api[_-]?key|secret|password|bearer[[:space:]]|ssh-rsa' "${text_files[@]}" >/dev/null; then
    printf '%s\n' "FAIL: private pattern found in media text"
    fail=1
  fi
fi

for file in "${files[@]}"; do
  case "$file" in
    *.mp4|*.webm)
      audio_count=$(ffprobe -v error -select_streams a -show_entries stream=index \
        -of csv=p=0 "$file" | wc -l | tr -d ' ')
      if (( audio_count != 0 )); then
        printf '%s\n' "FAIL: unexpected audio stream"
        fail=1
      fi
      ;;
    *.png|*.webp|*.avif)
      if command -v exiftool >/dev/null 2>&1; then
        if exiftool -s -Author -Creator -GPSPosition -UserComment "$file" \
          | rg -v '^$|: *$' >/dev/null; then
          printf '%s\n' "FAIL: sensitive image metadata field is populated"
          fail=1
        fi
      fi
      ;;
  esac
done

if (( fail )); then exit 1; fi
printf '%s\n' "PASS: automated media privacy checks"
if rg -q 'gatekeeper-blocked.*APPROVED' Documentation/VIDEO_MANIFEST.md \
  && rg -q 'menu-bar.*APPROVED' Documentation/SCREENSHOT_MANIFEST.md \
  && rg -q 'main-dark.*smart-care.*APPROVED' Documentation/SCREENSHOT_MANIFEST.md; then
  printf '%s\n' "PASS: human review evidence recorded for every published media source"
else
  printf '%s\n' "HUMAN_REVIEW_REQUIRED: inspect every image and sampled video frame"
fi
