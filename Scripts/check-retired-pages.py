#!/usr/bin/env python3
"""Ensure retired public pages are redirected and canonical pages are clean."""
import json, os, sys

site = sys.argv[1] if len(sys.argv) > 1 else "Website"
config = json.load(open(os.path.join(site, "vercel.json"), encoding="utf-8"))
redirects = {r.get("source"): r.get("destination", "") for r in config.get("redirects", [])}
problems = []
for path in ("/index.html", "/en.html", "/fr.html", "/site", "/site/", "/Website", "/Website/", "/en/index.html", "/fr/index.html"):
    if path not in redirects:
        problems.append(f"no explicit redirect configured for {path}")
if not os.path.exists(os.path.join(site, "index.html")):
    problems.append("canonical root entry is missing")
download = redirects.get("/download", "")
if not download.endswith(".dmg"):
    problems.append("/download does not target the verified DMG")
print("\n".join(problems))
sys.exit(1 if problems else 0)
