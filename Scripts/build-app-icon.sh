#!/bin/zsh
# Builds the app icon through Apple's own icon renderer.
#
# ## Why this replaces hand-drawing the icon
#
# `generate-brand-assets.swift` drew the icon itself: its own rounded
# rectangle, its own margin, its own glow behind each arc. Apple's app-icon
# guidance forbids all three, in as many words:
#
#   "Produce appropriately shaped, unmasked layers. The system masks all layer
#    edges to produce an icon's final shape... Providing layers with
#    pre-defined masking negatively impacts specular highlight effects and
#    makes edges look jagged."
#
#   "Let the system handle blurring and other visual effects... there's no need
#    to include specular highlights, drop shadows between layers, beveled
#    edges, blurs, glows, and other effects."
#
# And the shape was wrong regardless: CGPath(roundedRect:) is a circular-arc
# rounded rectangle, while Apple's is a continuous-curvature squircle. At the
# icon's radius the two diverge by roughly 43 px on a 1024 canvas.
#
# So the mark is emitted as unmasked, effect-free SVG layers, composed into an
# Icon Composer document, and rendered by `ictool` — the same renderer the
# system uses. The shape, the specular highlights, the inter-layer shadows and
# every appearance variant come from macOS rather than from us.
#
# ## What this does not yet do
#
# macOS 26+ prefers a compiled layered icon (Assets.car) so the system can
# re-render per appearance at runtime. Producing one needs `actool`, which
# ships only with full Xcode. This script produces the .icns instead, rendered
# from the same document — correct shape, correct effects, one static
# rendition. The .icon document is committed so the layered path is a
# packaging change rather than a redesign.
set -euo pipefail
cd "$(dirname "$0")/.."

ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
if [[ ! -x "$ICTOOL" ]]; then
  print -u2 "build-app-icon: ictool not found."
  print -u2 "  It ships inside Xcode's Icon Composer. Install Xcode, or keep"
  print -u2 "  the committed Resources/Brand/Generated/AppIcon.icns as-is."
  exit 1
fi

DOC="Resources/Brand/Sources/CoreTend.icon"
OUT="Resources/Brand/Generated"
SET="$OUT/AppIcon.iconset"

python3 Resources/Brand/Sources/make-icon-layers.py "$DOC/Assets"

rm -rf "$SET"
mkdir -p "$SET"

# The sizes an .icns carries. Rendered individually rather than downscaled from
# 1024: the renderer adjusts effect strength to the size, which is the reason
# a 16 px system icon stays legible and a downscaled one does not.
render() {
  local px="$1" name="$2"
  "$ICTOOL" "$DOC" --export-image --output-file "$SET/$name" \
    --platform macOS --rendition Default \
    --width "$px" --height "$px" --scale 1 --design-generation 27 >/dev/null
}

for entry in 16:icon_16x16.png 32:icon_16x16@2x.png 32:icon_32x32.png \
             64:icon_32x32@2x.png 128:icon_128x128.png 256:icon_128x128@2x.png \
             256:icon_256x256.png 512:icon_256x256@2x.png 512:icon_512x512.png \
             1024:icon_512x512@2x.png; do
  render "${entry%%:*}" "${entry##*:}"
done

iconutil -c icns "$SET" -o "$OUT/AppIcon.icns"
"$ICTOOL" "$DOC" --export-image --output-file "$OUT/AppIcon-1024.png" \
  --platform macOS --rendition Default --width 1024 --height 1024 --scale 1 \
  --design-generation 27 >/dev/null

print "built AppIcon.icns from $DOC (rendered by ictool, design generation 27)"
