import json, os, sys
site = sys.argv[1]
retired = ["features", "demos", "download", "install", "verify", "documentation",
           "support", "faq", "roadmap", "changelog", "open-source", "security"]
config = json.load(open(os.path.join(site, "vercel.json")))
sources = {r.get("source"): r.get("destination", "") for r in config.get("redirects", [])}
problems = []
for slug in retired:
    for locale in ("en", "fr"):
        if os.path.exists(os.path.join(site, locale, f"{slug}.html")):
            problems.append(f"{locale}/{slug}.html was retired but is still generated")
        if f"/{locale}/{slug}.html" not in sources:
            problems.append(f"no redirect configured for /{locale}/{slug}.html")
target = sources.get("/download", "")
if not (target.endswith(".dmg") or target.endswith("/releases")):
    problems.append("the /download route is missing or does not target a DMG")
print("\n".join(problems))
