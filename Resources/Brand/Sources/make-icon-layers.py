#!/usr/bin/env python3
"""Emit CoreTend's mark as unmasked, effect-free SVG layers for Icon Composer.

Apple's app-icon guidance is explicit on three points the existing generator
breaks:

  "Produce appropriately shaped, unmasked layers. The system masks all layer
   edges... Providing layers with pre-defined masking negatively impacts
   specular highlight effects and makes edges look jagged."

  "Let the system handle blurring and other visual effects... there's no need
   to include specular highlights, drop shadows between layers, beveled edges,
   blurs, glows, and other effects."

  "Prefer vector graphics when bringing layers into Icon Composer."

So: square 1024 canvas, no rounded-rect clip, no background, no glow, one
concern per layer. Icon Composer supplies the background, the shape and every
effect.
"""
import math, pathlib, sys

SIDE = 1024.0
C = SIDE / 2
# Same geometry as the app's mark, so the icon and the in-app logo stay one
# drawing: (start angle, span, radius as a fraction of the half-side).
ARCS = [(-30.0, 150.0, 0.94), (105.0, 115.0, 0.72), (250.0, 80.0, 0.50)]
NUCLEUS = 0.24
# Apple: "you don't need to fill the entire icon canvas with content", and the
# system masks the corners. 0.78 keeps the whole mark inside the safe circle
# at every corner radius the system might apply.
CONTENT = 0.78
STROKE = 0.075   # of the half-side


def point(radius: float, degrees: float) -> tuple[float, float]:
    rad = math.radians(degrees)
    return C + radius * math.cos(rad), C - radius * math.sin(rad)


def arc_path(start: float, span: float, fraction: float) -> str:
    r = C * CONTENT * fraction
    x0, y0 = point(r, start)
    x1, y1 = point(r, start + span)
    large = 1 if span > 180 else 0
    # Sweep 0: angles increase counter-clockwise in maths, clockwise in SVG's
    # inverted-y space.
    return f"M {x0:.3f} {y0:.3f} A {r:.3f} {r:.3f} 0 {large} 0 {x1:.3f} {y1:.3f}"


def svg(body: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'viewBox="0 0 {SIDE:.0f} {SIDE:.0f}" '
            f'width="{SIDE:.0f}" height="{SIDE:.0f}">\n{body}\n</svg>\n')


def main(out: pathlib.Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    width = C * CONTENT * STROKE * 2

    # One layer per arc, so Icon Composer can give each its own depth,
    # translucency and specular treatment — which is the whole point of the
    # layered format, and what a single flattened PNG cannot express.
    for index, (start, span, fraction) in enumerate(ARCS, start=1):
        path = (f'  <path d="{arc_path(start, span, fraction)}" fill="none" '
                f'stroke="#FFFFFF" stroke-width="{width:.3f}" '
                f'stroke-linecap="round"/>')
        (out / f"arc-{index}.svg").write_text(svg(path), encoding="utf-8")

    nucleus = (f'  <circle cx="{C:.1f}" cy="{C:.1f}" '
               f'r="{C * CONTENT * NUCLEUS:.3f}" fill="#FFFFFF"/>')
    (out / "nucleus.svg").write_text(svg(nucleus), encoding="utf-8")

    # White artwork, tinted per layer in icon.json: the system's dark, tinted
    # and clear variants recolour from the layer fill, and baking the brand
    # teal into the geometry would fight that.
    print(f"wrote 4 layers to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "layers")))
