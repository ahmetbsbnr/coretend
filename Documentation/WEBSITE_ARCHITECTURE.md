# Website Architecture

## Stack

Plain static HTML/CSS, no JavaScript framework, no bundler, no backend, no
database. Chosen over a static-site generator because the page count (13
pages x 2 locales) and content complexity don't justify a new toolchain —
see the repo-wide constraint against introducing a large framework for a
handful of static bilingual pages.

`Website/generate.py` is the single build step: a small Python script
(stdlib only, no dependencies) that renders `en/*.html` and `fr/*.html`
from content tables in the script, sharing one header/footer/nav template
function so the 26 pages don't hand-duplicate markup. Output is committed
static HTML — nothing runs server-side at request time.

## Build

```
cd Website
python3 generate.py
```

Verified locally this session: regenerates all 26 pages without error.

## Local preview

```
cd Website
python3 -m http.server 8791
```

Verified locally this session: `en/index.html`, `en/download.html`,
`fr/index.html`, `fr/legal.html`, `en/404.html` all return HTTP 200 from
the local server.

## Structure

```
Website/
  generate.py       — the build script (source of truth for content)
  README.md         — dev notes, placeholder inventory
  index.html         — locale picker / redirect to en/
  assets/style.css   — shared styles, Orbital Ecology tokens
  en/*.html, fr/*.html — generated output (committed)
```

Pages per locale: Home, Features, Download, Documentation, Open Source,
Roadmap, Changelog, FAQ, Privacy, Security, Licenses, Legal, 404.

## Visual identity

`assets/style.css` mirrors `Sources/DesignSystem/Colors.swift` /
`Documentation/DESIGN_TOKENS.md`: coreMint, ionViolet, solarAmber,
pulseCoral as CSS custom properties with light/dark variants via
`prefers-color-scheme`, matching the app's adaptive-color approach. System
font stack only — no remote font loading.

## No tracking

No analytics, no ad pixels, no session replay, no third-party embeds, no
remote fonts, no cookies of any kind. See `WEBSITE_PRIVACY.md`.

## Deployment

Not deployed. See `WEBSITE_DEPLOYMENT.md` for the planned process once a
human decides to go live.
