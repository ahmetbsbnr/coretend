#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
set -eu

if (( $# != 3 )); then
  print -u2 "usage: Scripts/encode-media.sh input.mov output.webm output.mp4"
  exit 2
fi

input="$1"
webm="$2"
mp4="$3"

ffmpeg -y -i "$input" -map_metadata -1 -an \
  -vf "fps=24,scale=w='min(1440,iw)':h=-2:flags=lanczos" \
  -c:v libvpx-vp9 -crf 35 -b:v 0 -row-mt 1 "$webm"
ffmpeg -y -i "$input" -map_metadata -1 -an \
  -vf "fps=24,scale=w='min(1440,iw)':h=-2:flags=lanczos" \
  -c:v libx264 -preset slow -crf 25 -movflags +faststart \
  -pix_fmt yuv420p "$mp4"

printf '%s\n' "PASS: metadata-free, silent WebM and MP4 exports created"
