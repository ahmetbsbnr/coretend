#!/usr/bin/env python3
"""Check the App Store listing (Documentation/Release/AppStore-listing.md) against Apple's limits."""
import re
from pathlib import Path

LIMITS = {"Subtitle": 30, "Sous-titre": 30, "Promotional text": 170, "Texte promotionnel": 170,
          "Keywords": 100, "Mots-clés": 100}
text = (Path(__file__).resolve().parents[1] / "Documentation/Release/AppStore-listing.md").read_text()
errors = []
for language in ("en", "fr"):
    block = re.search(rf"<!-- listing:{language} -->(.*?)<!-- /listing:{language} -->", text, re.S).group(1)
    for label, limit in LIMITS.items():
        found = re.search(rf"\*\*{re.escape(label)} ?:\*\* (.+)", block)
        if found:
            value = found.group(1).strip()
            print(f"{language} {label}: {len(value)}/{limit}")
            if len(value) > limit:
                errors.append(f"{language} {label} is {len(value)} characters (limit {limit})")
    description = block.split("**Description", 1)[1].split("\n", 1)[1].strip()
    print(f"{language} description: {len(description)}/4000")
    if len(description) > 4000:
        errors.append(f"{language} description is {len(description)} characters")
if errors:
    raise SystemExit("\n".join(errors))
print("App Store listing within limits.")
