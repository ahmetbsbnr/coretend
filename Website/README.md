# Website (dev notes)

Static, bilingual (en/fr) site for CoreTend. Plain HTML/CSS, no framework,
no backend, no database, no analytics.

## Build

```
python3 Website/build.py --output Website/dist
```

`index.html` is the visual source of truth and `build.py` creates the isolated,
gitignored `dist/` directory deployed by Vercel. `generate.py` and the tracked
`en/` and `fr/` trees are retained only for legacy media/client-journey gates;
that generator never owns or rewrites the production Vercel configuration.

## Local preview

```
python3 Website/build.py --output Website/dist
python3 -m http.server 8791 --directory Website/dist
# open http://localhost:8791/en
```

## Public release data

`Configuration/published-release.json` is the only reviewed public-release
record. `build.py` derives the Download UI, `/download`, `latest.json`,
`SHA256SUMS`, Support version and bilingual page copy from it. Keep that record
on the currently verified public release until a successor asset has been
published, downloaded and hash-checked.

`Scripts/check-placeholders.sh` and the isolated site gate reject unresolved
identity tokens. The visual regression gate records 79 reviewed fingerprints;
use `node Scripts/visual/capture.mjs --capture-only` for inspection before any
intentional baseline update.

See `Documentation/WEBSITE_ARCHITECTURE.md`, `WEBSITE_SECURITY.md`,
`WEBSITE_PRIVACY.md`, and `WEBSITE_DEPLOYMENT.md` for the rest.
