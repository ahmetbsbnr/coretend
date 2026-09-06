#!/usr/bin/env python3
"""Ensure retired public pages are redirected and canonical pages are clean."""
import json, os, sys

site = sys.argv[1] if len(sys.argv) > 1 else "Website"
config = json.load(open(os.path.join(site, "vercel.json"), encoding="utf-8"))
redirects = {r.get("source"): r.get("destination", "") for r in config.get("redirects", [])}
rewrites = {r.get("source"): r.get("destination", "") for r in config.get("rewrites", [])}
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
# /download must resolve to a DMG. Two supported shapes:
#   old: a static redirect whose destination ends in .dmg
#   new: a rewrite to the channel-aware resolver (Website/api/download.js),
#        which reads Website/api/_lib/releases.json — 'stable' mirrors the
#        published release, 'beta' stays null until a real beta DMG exists
#        (?channel=beta then falls back to stable). This is DMG-first and
#        release-agnostic; no per-release vercel.json edit.
download_redirect = redirects.get("/download", "")
download_rewrite = rewrites.get("/download", "")
if download_redirect.endswith(".dmg"):
    pass
elif download_rewrite in ("/api/download", "/api/download.js"):
    resolver = os.path.join(site, "api", "download.js")
    table = os.path.join(site, "api", "_lib", "releases.json")
    if not os.path.exists(resolver):
        problems.append("/download rewrites to /api/download but Website/api/download.js is missing")
    if not os.path.exists(table):
        problems.append("/api/download has no channel table (Website/api/_lib/releases.json missing)")
    else:
        channels = json.load(open(table, encoding="utf-8"))
        stable = channels.get("stable") or {}
        if not str(stable.get("dmgURL", "")).endswith(".dmg"):
            problems.append("releases.json 'stable.dmgURL' does not point at a .dmg")
        # 'beta' must be null OR a real .dmg — never a placeholder/invented URL.
        beta = channels.get("beta")
        if beta is not None and not str((beta or {}).get("dmgURL", "")).endswith(".dmg"):
            problems.append("releases.json 'beta' is set but 'beta.dmgURL' is not a real .dmg URL")
else:
    problems.append("/download does not target the verified DMG (no .dmg redirect and no /api/download rewrite)")
print("\n".join(problems))
sys.exit(1 if problems else 0)
