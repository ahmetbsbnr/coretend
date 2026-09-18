#!/usr/bin/env python3
"""Export the Swift design tokens into web-consumable, checked-in assets.

`CLAUDE.md` names the app's design system as the single source of truth for
the website's visual language. This script is what makes that true, and it had
stopped being true without anyone noticing.

The previous version parsed colours as `public static let name = (r, g, b)`
float tuples. When the palette moved to owned `UInt32` hex constants it matched
nothing, exported **zero colours**, and exited 0 — so the website kept serving
the old Porcelain/Slate/Teal values while the app rendered the new Slate/Teal
ones. A generator that produces nothing must fail; this one does.

Run `Scripts/check-design-tokens.py` to verify the checked-in output is current
without rewriting it.
"""
from pathlib import Path
import json, re, sys

ROOT = Path(__file__).resolve().parents[1]
COLORS = ROOT / "Sources/DesignSystem/Colors.swift"
TOKENS = ROOT / "Sources/DesignSystem/Tokens.swift"
OUT = ROOT / "Website/assets/tokens"


def parse_colors(source: str) -> dict[str, str]:
    """Canonical hex constants: `public static let ground: UInt32 = 0x14171A`."""
    found = re.findall(r"public static let (\w+):\s*UInt32\s*=\s*0x([0-9A-Fa-f]{6})", source)
    return {name: "#" + value.upper() for name, value in found}


def parse_spacing(source: str) -> dict[str, float]:
    return {k: float(v) for k, v in re.findall(
        r"public static let (\w+): CGFloat = ([0-9.]+)", source)}


def parse_motion(source: str) -> dict[str, float]:
    """Motion is now `Animation.smooth(duration: 0.4)` rather than a bare Double.

    The duration is the part the web can use; the curve family is a SwiftUI
    concept with no CSS equivalent, so it is deliberately not exported rather
    than approximated into a cubic-bezier nobody verified.
    """
    return {k: float(v) for k, v in re.findall(
        r"public static let (\w+) = Animation\.\w+\(duration: ([0-9.]+)\)", source)}


def main() -> int:
    colors = parse_colors(COLORS.read_text(encoding="utf-8"))
    tokens_source = TOKENS.read_text(encoding="utf-8")
    spacing = parse_spacing(tokens_source)
    motion = parse_motion(tokens_source)

    # Exiting 0 with an empty palette is how the website silently diverged for
    # an entire redesign. Each of these is a contract, not a nicety.
    problems = []
    if not colors:
        problems.append("no colours parsed — the Colors.swift format changed")
    if not spacing:
        problems.append("no spacing tokens parsed — the Tokens.swift format changed")
    if not motion:
        problems.append("no motion tokens parsed — the MCMotion format changed")
    for required in ("ground", "teal", "textPrimary"):
        if required not in colors:
            problems.append(f"canonical colour '{required}' is missing")
    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        return 1

    payload = {
        "source": "Sources/DesignSystem/Colors.swift + Tokens.swift",
        "colors": colors,
        "spacing": spacing,
        "motion": motion,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "design-tokens.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    css = [":root {"]
    css += [f"  --ct-{name}: {value};" for name, value in sorted(colors.items())]
    css += [f"  --ct-space-{name}: {value:g}px;" for name, value in sorted(spacing.items())]
    css += [f"  --ct-motion-{name}: {value:g}s;" for name, value in sorted(motion.items())]
    css.append("}\n")
    (OUT / "design-tokens.css").write_text("\n".join(css), encoding="utf-8")

    print(f"exported {len(colors)} colours, {len(spacing)} spacing tokens, "
          f"{len(motion)} motion tokens")
    return 0


if __name__ == "__main__":
    sys.exit(main())
