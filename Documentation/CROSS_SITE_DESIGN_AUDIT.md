# Cross-Site Design Audit

Read-only comparison of the portfolio's live design language against the
MacCare Local product site's. **Neither site was modified during this
audit.** Real values pulled from each repo's actual CSS, not
approximated.

## Sources

- Portfolio: `tailwind.config.js` + `app/globals.css` in
  `professionnel-portfolio-stage-2026` (see
  `PORTFOLIO_REPOSITORY_INVENTORY.md`).
- Product site: `Website/assets/style.css` (hand-authored CSS, consumed by
  `Website/generate.py`'s templated HTML).

## Side-by-side

| Dimension | Portfolio | Product site | Convergence read |
|---|---|---|---|
| **Typography** | Archivo (display+body, via `next/font`), IBM Plex Mono | System font stack (`-apple-system, BlinkMacSystemFont, "SF Pro Text"...`) | **Diverge today.** Portfolio picked an editorial webfont; product site deliberately uses the OS system font (matches a native-macOS-app product's own UI font, arguably correct for *that* site, but the two currently read as different typographic voices) |
| **Color system shape** | CSS custom properties, single accent (`--cobalt`/`--cobalt-deep`) + neutral scale (`--paper`/`--card`/`--ink`/`--sub`/`--dim`/`--line`/`--line-strong`) + `--ok`/`--err` | CSS custom properties, **four-way functional palette** (`--core-mint`, `--ion-violet`, `--solar-amber`, `--pulse-coral`) + `--success` + neutral scale (`--bg`/`--bg-elevated`/`--text`/`--text-secondary`/`--separator`) | **Structurally compatible** (both are CSS-var-driven, both split neutral-scale from accent) but **palette itself is unrelated** — portfolio is monochrome-accent (cobalt blue), product site is multi-hue functional (mint/violet/amber/coral map to Cleanup/Smart Care/Protection/etc. categories). This is a real design decision, not an oversight — see "what stays separate" below |
| **Dark mode** | CSS custom properties (mechanism not fully audited this pass — `globals.css` defines the light values; dark-mode override strategy not confirmed) | `@media (prefers-color-scheme: dark)` block redefining every token | Product site's approach (media-query token override) is the simpler, more portable pattern — worth confirming the portfolio uses the same mechanism, not a class-toggle approach, before calling this "shared" |
| **Spacing scale** | Tailwind's default spacing scale (no custom override found in `tailwind.config.js`'s `theme.extend`) | Explicit named scale: `--space-xs` (8px) → `--space-xxl` (48px), doubling-ish progression | **Diverge.** Product site has a deliberate, named 6-step scale; portfolio relies on Tailwind's built-in scale. A shared scale would mean picking one convention — worth doing since it's genuinely low-cost to align |
| **Radius** | Not yet inventoried (out of scope for this pass — would need reading `globals.css` in full) | `--radius-card` (12px), `--radius-hero` (20px) | Not yet comparable — flagged for the next pass |
| **Motion** | GSAP 3 + `@gsap/react` — JS-driven animation, `cubic-bezier(0.16, 1, 0.3, 1)` ("out-expo") easing defined in Tailwind config | Static site — no animation framework, no JS-driven motion found in `Website/generate.py`/`style.css` this pass | **Diverge by design, not by neglect.** The product site is a static, no-JS-framework marketing/docs site; the portfolio is animation-forward. This is likely fine to keep divergent — see "what stays separate" |
| **Max content width** | Not yet inventoried | `--max-width: 960px` | Not yet comparable |
| **Framework** | Next.js 15 (React, TypeScript, build step) | Python static-site generator (`Website/generate.py`, stdlib only, no framework, no build step beyond running the script) | Structurally very different pipelines — any "shared design language" must live as **portable primitives** (a token spec, a written component pattern), never as actually-shared code, since the two sites don't share a runtime |

## Read

The two sites are not currently aligned, and weren't designed to be —
they were built independently, for different purposes, on different
stacks. Real convergence opportunities exist (spacing-scale naming
convention, dark-mode token-override mechanism, a shared editorial
voice/quality bar) without forcing either site to abandon what's actually
right for it (product site stays a fast, static, framework-free page;
portfolio stays an animated, editorial Next.js site). See
`CROSS_SITE_DESIGN_LANGUAGE.md` for what's proposed to actually share and
`PORTFOLIO_PRODUCT_SITE_ALIGNMENT.md` for the concrete alignment items.

No file on either site was changed to produce this audit.
