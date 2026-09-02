#!/usr/bin/env python3
"""Deterministic first-paint contract for the canonical static entry point."""
from pathlib import Path
import json, re, sys

repo = Path(__file__).resolve().parent.parent
site = repo / "Website"
html = (site / "index.html").read_text(encoding="utf-8")
config = json.loads((site / "vercel.json").read_text(encoding="utf-8"))
problems = []
if "<style" not in html:
    problems.append("Website/index.html has no critical style")
if not re.search(r"--paper:\s*(var\(--ct-paper,\s*)?#f6f4ef", html, re.I):
    problems.append("critical style does not define the Paper token")
if not re.search(r"--ink:\s*(var\(--ct-ink,\s*)?#1b1e22", html, re.I):
    problems.append("critical style does not define the Ink token")
if not any(h.get("key") == "Content-Security-Policy" for b in config.get("headers", []) for h in b.get("headers", [])):
    problems.append("Vercel headers do not declare a Content-Security-Policy")
if "/en/index.html" in html or "/fr/index.html" in html:
    problems.append("entry point exposes a legacy locale file URL")
if problems:
    print("FAIL: first-paint regression")
    for problem in problems:
        print(f"  - {problem}")
    sys.exit(1)
print("PASS: styled canonical entry and CSP first-paint contract")
