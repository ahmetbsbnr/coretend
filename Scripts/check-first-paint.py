#!/usr/bin/env python3
"""Regression gate for the CoreTend site's initial canvas.

The site is static, so the strongest deterministic checks are at the response
source: no renderable redirect document in production, an immediate light/dark
background in every page, and a CSP hash that authorizes exactly that rule.
"""

import base64
import hashlib
import json
from pathlib import Path
import re
import sys

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
    if "#f4f6f3" not in rule or "#0b0f14" not in rule:
        problems.append(f"{page.relative_to(repo)} lacks both initial theme backgrounds")
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

print(f"PASS: direct root redirect and CSP-authorized light/dark first paint on {len(pages)} pages")
