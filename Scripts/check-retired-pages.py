#!/usr/bin/env python3
"""Ensure retired public pages are redirected and canonical pages are clean."""
import json, os, sys

site = sys.argv[1] if len(sys.argv) > 1 else "Website"
config = json.load(open(os.path.join(site, "vercel.json"), encoding="utf-8"))
redirects = {r.get("source"): r.get("destination", "") for r in config.get("redirects", [])}
problems = []
# Trailing-slash variants (/site/, /Website/) are handled by Vercel's
# "trailingSlash": false normalisation (308 to the non-slash path, which then
# redirects), so they need no explicit rule here. test-site.mjs verifies that
# end to end.
for path in ("/index.html", "/en.html", "/fr.html", "/site", "/Website", "/en/index.html", "/fr/index.html"):
    if path not in redirects:
        problems.append(f"no explicit redirect configured for {path}")
if not os.path.exists(os.path.join(site, "index.html")):
    problems.append("canonical root entry is missing")
download = redirects.get("/download", "")
if not download.endswith(".dmg"):
    problems.append("/download does not target the verified DMG")
print("\n".join(problems))
sys.exit(1 if problems else 0)
