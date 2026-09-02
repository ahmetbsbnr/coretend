#!/usr/bin/env python3
"""Export the Swift design tokens into web-consumable, checked-in assets."""
from pathlib import Path
import json, re

ROOT = Path(__file__).resolve().parents[1]
COLORS = ROOT / "Sources/DesignSystem/Colors.swift"
TOKENS = ROOT / "Sources/DesignSystem/Tokens.swift"
OUT = ROOT / "Website/assets/tokens"

def hex_from_tuple(value: str) -> str:
    nums = [float(x.strip()) for x in value.split(",")]
    return "#" + "".join(f"{round(n*255):02X}" for n in nums)

source = COLORS.read_text(encoding="utf-8")
palette = {}
for name, value in re.findall(r"public static let (\w+)\s*=\s*\(([^)]+)\)", source):
    if value.count(",") == 2:
        palette[name] = hex_from_tuple(value)

spacing_source = TOKENS.read_text(encoding="utf-8")
spacing = {k: float(v) for k, v in re.findall(r"public static let (\w+): CGFloat = ([0-9.]+)", spacing_source)}
motion = {k: float(v) for k, v in re.findall(r"public static let (quick|standard|gentle): Double = ([0-9.]+)", spacing_source)}
tokens = {"source": "Sources/DesignSystem/Colors.swift + Tokens.swift", "colors": palette, "spacing": spacing, "motion": motion}
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "design-tokens.json").write_text(json.dumps(tokens, indent=2, sort_keys=True) + "\n", encoding="utf-8")
css = [":root {"]
for name, value in sorted(palette.items()): css.append(f"  --ct-{name}: {value};")
for name, value in sorted(spacing.items()): css.append(f"  --ct-space-{name}: {value:g}px;")
for name, value in sorted(motion.items()): css.append(f"  --ct-motion-{name}: {value:g}s;")
css.append("}\n")
(OUT / "design-tokens.css").write_text("\n".join(css), encoding="utf-8")
print(f"exported {len(palette)} colors, {len(spacing)} spacing tokens, {len(motion)} motion tokens")
