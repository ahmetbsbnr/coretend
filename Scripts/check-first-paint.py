#!/usr/bin/env python3
"""Regression gate for the CoreTend site's initial canvas.

The site is static, so the strongest deterministic checks are at the response
source: no renderable redirect document in production, an immediate paper
background and ink foreground in every page, and a CSP hash that authorizes
exactly that rule.

The bug this exists to catch is a flash of unstyled content — white canvas,
default blue links — before the external stylesheet lands. The colours below
are the site's own tokens (see Website/assets/style.css); the site renders a
single paper theme, matching the portfolio it shares an identity with, so one
background/foreground pair is the whole contract.

The CSP half is not decoration: an inline critical style that the policy does
not authorize is dropped by the browser, which reproduces exactly the white
flash this gate is meant to prevent. That has actually happened here before.
"""

import base64
import hashlib
import json
from pathlib import Path
import re
import sys

# The site's first-paint tokens, kept in one place so a palette change is a
# one-line edit here rather than a scatter of hex literals.
PAPER = "#f4f4f0"
INK = "#17191d"

repo = Path(__file__).resolve().parent.parent
site = repo / "Website"
config = json.loads((site / "vercel.json").read_text(encoding="utf-8"))

problems = []
redirects = config.get("redirects", [])
if not any(
    item.get("source") == "/"
    and item.get("destination") == "/en/index.html"
    for item in redirects
):
    problems.append("Vercel does not redirect / directly to /en/index.html")

pages = sorted((site / "en").glob("*.html")) + sorted((site / "fr").glob("*.html"))
for page in pages:
    html = page.read_text(encoding="utf-8")
    style = re.search(r"<style>(.*?)</style>", html, re.S)
    if not style:
        problems.append(f"{page.relative_to(repo)} has no critical style")
        continue
    rule = style.group(1)
    if PAPER not in rule or INK not in rule:
        problems.append(
            f"{page.relative_to(repo)} critical style does not set both the "
            f"paper background ({PAPER}) and the ink foreground ({INK})"
        )
    digest = base64.b64encode(hashlib.sha256(rule.encode()).digest()).decode()
    expected = f"sha256-{digest}"
    csp_values = [
        header["value"]
        for block in config.get("headers", [])
        for header in block.get("headers", [])
        if header.get("key") == "Content-Security-Policy"
    ]
    if not any(expected in value for value in csp_values):
        problems.append(f"{page.relative_to(repo)} critical style is blocked by CSP")

if problems:
    print("FAIL: first-paint regression")
    for problem in problems:
        print(f"  - {problem}")
    sys.exit(1)

print(f"PASS: direct root redirect and CSP-authorized paper first paint on {len(pages)} pages")
