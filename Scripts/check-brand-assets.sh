#!/bin/sh
# Gate: every brand asset the product, installer, and website reference must
# exist, at the right pixel size, and carry no trace of the old name.
#
# The asset matrix is documented prose elsewhere; this is the executable copy.
# A missing favicon or a 511-pixel icon fails silently at runtime — a broken
# image in a menu bar or a link preview is exactly the kind of defect nobody
# notices until someone else does.
#
# Regenerate with: swift Resources/Brand/Sources/generate-brand-assets.swift
#              and iconutil -c icns Resources/Brand/Generated/AppIcon.iconset \
#                    -o Resources/Brand/Generated/AppIcon.icns
set -eu
cd "${CHECK_BRAND_ASSETS_ROOT:-$(dirname "$0")/..}"

GEN="Resources/Brand/Generated"
fail=0
problems=""
note() { fail=1; problems="$problems\n  - $1"; }

# Pixel dimensions of a PNG, read from the IHDR chunk. No dependency on
# sips/ImageMagick being present.
png_size() {
  /usr/bin/python3 -c "
import struct, sys
with open(sys.argv[1], 'rb') as f:
    data = f.read(33)
w, h = struct.unpack('>II', data[16:24])
print(f'{w}x{h}')
" "$1" 2>/dev/null || echo "unreadable"
}

require_png() {
  path="$GEN/$1"; expected="$2"
  if [ ! -f "$path" ]; then
    note "missing: $1"
    return
  fi
  actual=$(png_size "$path")
  if [ "$actual" != "$expected" ]; then
    note "$1 is $actual, expected $expected"
  fi
}

require_file() {
  [ -f "$GEN/$1" ] || note "missing: $1"
}

# The horizontal lockup's width follows the wordmark's measured text width, so
# it is a function of system font metrics rather than a constant this repo
# controls. Pinning it exactly would make the gate fail on an OS update that
# changed those metrics by a pixel — which is not a brand defect. Height is
# fixed by the generator, so that is asserted exactly, and width only has to
# stay in a sane band around the mark.
require_png_height() {
  path="$GEN/$1"; expected_h="$2"; min_w="$3"; max_w="$4"
  if [ ! -f "$path" ]; then
    note "missing: $1"
    return
  fi
  actual=$(png_size "$path")
  w=${actual%x*}; h=${actual#*x}
  [ "$h" = "$expected_h" ] || note "$1 is $actual, expected height ${expected_h}"
  if [ "$w" -lt "$min_w" ] || [ "$w" -gt "$max_w" ]; then
    note "$1 is ${w}px wide, outside the expected ${min_w}-${max_w}px band"
  fi
}

echo "== check-brand-assets.sh =="

# App icon: every size macOS asks for, at 1x and 2x.
for size in 16 32 128 256 512; do
  require_png "AppIcon.iconset/icon_${size}x${size}.png" "${size}x${size}"
  require_png "AppIcon.iconset/icon_${size}x${size}@2x.png" "$((size * 2))x$((size * 2))"
done
require_png "AppIcon-1024.png" "1024x1024"
require_file "AppIcon.icns"

# Menu bar: template images, which macOS recolours itself.
require_png "MenuBarTemplate.png" "18x18"
require_png "MenuBarTemplate@2x.png" "36x36"

# Web.
require_png "Favicon-16.png" "16x16"
require_png "Favicon-32.png" "32x32"
require_png "Favicon-48.png" "48x48"
require_png "Favicon-180.png" "180x180"
require_png "Favicon-512.png" "512x512"
require_png "OpenGraph-1200x630.png" "1200x630"
require_png "SocialPreview-1280x640.png" "1280x640"

# Lockups, light and dark, plus single-ink for print.
require_png_height "Logo-Horizontal-dark.png" 128 380 540
require_png_height "Logo-Horizontal-light.png" 128 380 540
require_png_height "Logo-Horizontal-dark@2x.png" 256 760 1080
require_png_height "Logo-Horizontal-light@2x.png" 256 760 1080
require_png "Logo-Compact-dark.png" "512x512"
require_png "Logo-Compact-light.png" "512x512"
require_file "Logo-Horizontal-mono-dark-ink.png"
require_file "Logo-Horizontal-mono-light-ink.png"

# App and installer surfaces.
require_png "Onboarding-Hero.png" "768x768"
require_png "DMG-Background.png" "600x400"
require_png "DMG-Background@2x.png" "1200x800"

# Vector sources — the ones a designer actually opens.
require_file "Mark-dark.svg"
require_file "Mark-light.svg"
require_file "Mark-monochrome.svg"
require_file "Mark-dark.pdf"
require_file "Mark-light.pdf"

# The SVG must be a real, self-describing, accessible mark rather than an
# empty shell — three arcs, a nucleus, and a title.
for svg in Mark-dark.svg Mark-light.svg Mark-monochrome.svg; do
  if [ -f "$GEN/$svg" ]; then
    paths=$(grep -c '<path ' "$GEN/$svg" || echo 0)
    [ "$paths" -eq 3 ] || note "$svg has $paths arc paths, expected 3"
    grep -q '<circle ' "$GEN/$svg" || note "$svg has no nucleus circle"
    grep -q '<title>CoreTend</title>' "$GEN/$svg" || note "$svg has no accessible title"
    grep -q 'role="img"' "$GEN/$svg" || note "$svg is missing role=\"img\""
  fi
done

# The monochrome variant must inherit its colour, not hardcode one — that is
# the whole reason it exists.
if [ -f "$GEN/Mark-monochrome.svg" ]; then
  grep -q 'currentColor' "$GEN/Mark-monochrome.svg" \
    || note "Mark-monochrome.svg does not use currentColor, so it cannot adapt"
fi

# No asset may carry the pre-rename name in its filename.
stale=$(find "$GEN" -iname '*maccare*' 2>/dev/null || true)
[ -z "$stale" ] || note "assets still named after the old brand: $stale"

# The generator itself must stay in the repo: assets without their source are
# assets nobody can change.
[ -f Resources/Brand/Sources/generate-brand-assets.swift ] \
  || note "the asset generator is missing — the generated files would be unreproducible"

if [ "$fail" -ne 0 ]; then
  printf 'FAIL — brand assets incomplete:%b\n' "$problems"
  exit 1
fi
echo "OK — every brand asset present, correctly sized, and named for the current brand."
