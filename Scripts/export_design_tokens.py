#!/usr/bin/env python3
"""Export semantic website colors from the app's canonical Swift palette."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PALETTE = ROOT / "Sources/DesignSystem/Palette.swift"
OUTPUT = ROOT / "Website/design-tokens.css"

ROLE_NAMES = {
    "canvas": "canvas",
    "surface": "surface",
    "raisedSurface": "raised-surface",
    "separator": "separator",
    "ink": "ink",
    "secondaryInk": "secondary-ink",
    "accent": "accent",
    "onAccent": "on-accent",
    "caution": "caution",
    "danger": "danger",
    "focus": "focus",
}


def export_tokens() -> None:
    source = PALETTE.read_text(encoding="utf-8")
    values: dict[str, tuple[str, str]] = {}
    pattern = re.compile(
        r"public\s+static\s+let\s+(\w+)\s*=\s*PaletteRole\("
        r"name:\s*\"[^\"]+\",\s*light:\s*RGB\(hex:\s*0x([0-9A-Fa-f]{6})\),"
        r"\s*dark:\s*RGB\(hex:\s*0x([0-9A-Fa-f]{6})\)\)"
    )
    for role, light, dark in pattern.findall(source):
        if role in ROLE_NAMES:
            if role in values:
                raise ValueError(f"Duplicate semantic palette role: {role}")
            values[role] = (f"#{light.upper()}", f"#{dark.upper()}")

    missing = set(ROLE_NAMES) - values.keys()
    if missing:
        raise ValueError(f"Palette.swift is missing website roles: {', '.join(sorted(missing))}")

    def declarations(appearance: int) -> list[str]:
        return [
            f"  --ct-{css_name}: {values[swift_name][appearance]};"
            for swift_name, css_name in ROLE_NAMES.items()
        ]

    css = """/* Generated from Sources/DesignSystem/Palette.swift by Scripts/export_design_tokens.py. */
:root {
  color-scheme: dark;
"""
    css += "\n".join(declarations(1))
    css += "\n}\n\n@media (prefers-color-scheme: light) {\n  :root {\n    color-scheme: light;\n"
    css += "\n".join("  " + line for line in declarations(0))
    css += "\n  }\n}\n"
    OUTPUT.write_text(css, encoding="utf-8")


if __name__ == "__main__":
    export_tokens()
