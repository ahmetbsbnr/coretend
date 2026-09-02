# Website Architecture

## Stack

Plain static HTML/CSS/JavaScript — no framework, no bundler, no backend, no
database. Chosen over a static-site generator because the page count and content
complexity don't justify a new toolchain (see the repo-wide constraint against
introducing a large framework for a handful of static bilingual pages).

`Website/index.html` is the single visual source of truth: one hand-authored
document that carries the English copy in the DOM and the matching French in
`data-fr` attributes. `Website/build.py` turns it into the deployable site.

## Build

```
python3 Website/build.py --output Website/dist
```

`build.py`:

- renders the landing pages for `/`, `/en` and `/fr`, pre-rendering the French
  `data-fr` content at build time (no client-side language swap);
- renders the standalone info pages (`/privacy`, `/support`, `/legal`,
  `/licenses`) and their `/fr/…` counterparts, plus a branded `404`;
- substitutes `@@CORETEND_*@@` tokens from
  `Configuration/published-release.json` (version, checksum, minimum macOS,
  architecture, signing status) so page copy can never disagree with the
  published release;
- externalises every inline `<style>` and executable `<script>` into
  `assets/generated/*.css|*.js` so the deployed pages satisfy a strict
  `script-src 'self'` CSP (non-JS `<script>` data blocks such as JSON-LD are
  left inline);
- writes `robots.txt`, `sitemap.xml`, `manifest.webmanifest`, `latest.json` and
  `SHA256SUMS`.

`Website/dist/` is gitignored. `Website/vercel.json` (redirects, rewrites,
security headers) is hand-maintained — `build.py` never rewrites it.

## Local preview

```
python3 Website/build.py --output Website/dist
python3 -m http.server 8791 --directory Website/dist
# open http://localhost:8791/en
```

## Structure

```
Website/
  index.html        — visual source of truth (EN in DOM, FR in data-fr)
  build.py          — the build step
  vercel.json       — redirects / rewrites / security headers (hand-maintained)
  README.md         — dev notes
  assets/tokens/    — design-tokens.css, generated from the Swift design system
  assets/shell/     — boot.js and the shared info-page shell
  assets/brand/     — marks, favicons, Open Graph image
  assets/app/       — privacy-reviewed screenshots of the real app
  assets/fonts/     — self-hosted subset woff2 (no remote fonts)
  dist/             — build output (gitignored, deployed by Vercel)
```

## Visual identity

`assets/tokens/design-tokens.css` is generated from
`Sources/DesignSystem/Colors.swift` and verified by
`Scripts/check-design-tokens.py`, so the site and the app cannot drift. Porcelain
`#F6F4EF` / Slate `#1B1E22` / Teal `#0B6E6C` (teal-bright `#5FD3C6` on dark),
exposed as CSS custom properties with `prefers-color-scheme` variants. System
font stack plus the self-hosted subset only — no remote font loading.

## Gate

`bash Scripts/check-website.sh` runs `build.py` into a throwaway directory,
`check-design-tokens.py`, then `Scripts/site/test-site.mjs` — a Playwright suite
(32 checks: route contracts, canonical/hreflang/Open Graph, the branded 404,
Axe WCAG A/AA on every page, no-JavaScript fallback, seven viewports in both
languages, first paint, favicons). `Scripts/visual/capture.mjs` holds the
reviewed visual-regression fingerprints.

## No tracking

No analytics, no ad pixels, no session replay, no third-party embeds, no remote
fonts, no cookies of any kind. See `WEBSITE_PRIVACY.md`.

## Deployment

Production deployment and verification are recorded in `WEBSITE_DEPLOYMENT.md`.
