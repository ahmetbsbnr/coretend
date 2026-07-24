# Cross-Site Design Language

What's proposed to be genuinely shared between the portfolio and the
future product site, versus what stays independent. Nothing here has been
implemented — this is a specification for `shared/design-language/` in
the future `WEBSITE/` workspace (`WORKSPACE_TARGET_STRUCTURE.md`).

## Shared (portable primitives, not shared code)

Since the two sites don't share a runtime (Next.js/React vs. a stdlib
Python generator), "shared" means a **written specification** each site's
own build implements independently — not a common CSS/JS file imported by
both.

- **Grid / max content width**: pick one canonical max-width and use it
  on both (product site already has `--max-width: 960px`; portfolio's
  needs auditing before comparison).
- **Spacing scale naming**: adopt the product site's named-token
  convention (`--space-xs` … `--space-xxl`) as the canonical naming
  pattern; map it onto whichever numeric scale each site actually uses
  under the hood (portfolio can keep Tailwind's spacing numbers, just
  expose the same semantic names via its own token layer if it wants
  parity).
- **Buttons / links — interaction states**: consistent focus-visible
  treatment (both sites should show a visible focus ring — this session
  did not confirm the portfolio does; see `PORTFOLIO_PRODUCT_SITE_ALIGNMENT.md`).
- **Navigation pattern**: both are simple top-nav sites (no mega-menu, no
  hamburger-hidden-by-default on desktop) — keep that shared simplicity as
  a written rule, not a specific shared component.
- **Header / footer information hierarchy**: same expectations (clear
  identity, minimal links, no dark patterns, no fake urgency) — a content
  rule, not a visual one.
- **Focus / keyboard order**: both sites should have a logical tab order
  and visible focus — a written accessibility rule both implementations
  must independently satisfy.
- **Responsive behavior**: both should degrade gracefully to narrow
  viewports — a written rule (no forced horizontal scroll, no fixed pixel
  widths that break under ~375px), each site's own responsive CSS handles
  it in its own idiom (Tailwind breakpoints vs. the product site's own
  media queries).
- **Editorial quality bar**: no marketing hyperbole, no fake urgency, no
  dark patterns, honest claims only — this is already a hard requirement
  for the product site (see `Website/generate.py`'s existing honesty
  posture, audited across multiple prior sessions) and should be the same
  bar the portfolio holds itself to.

## Stays independent (product-specific, not shared)

- **Core Bloom** (the app-icon/hero mark) and **Orbital Ecology** (the
  four-hue functional palette mapping mint/violet/amber/coral to
  Cleanup/Smart Care/Protection/Performance-style categories) — these are
  the product's own visual identity, not a general "brand palette" to
  extend to the portfolio. The portfolio's cobalt-accent, editorial
  aesthetic is *its own* identity and should not be diluted into a
  product-palette clone.
- **Typography choice**: product site's system-font stack is a deliberate
  echo of the native macOS app it markets; portfolio's Archivo/Plex Mono
  pairing is its own editorial voice. Different, on purpose.
- **Motion**: GSAP-driven animation stays a portfolio-only choice; the
  product site stays static/no-JS-framework by design (fast, simple,
  auditable — matches its zero-tracking, zero-JS-framework privacy
  posture already documented in `Website/generate.py`'s own honesty
  commitments).
- **Screenshots / module visualizations / onboarding imagery**: entirely
  product-specific, no equivalent need on a portfolio site.
- **Framework/build pipeline**: Next.js+Vercel for the portfolio,
  stdlib-Python-generator+static-hosting for the product site — kept
  separate deliberately (see `WORKSPACE_TARGET_STRUCTURE.md`'s "no
  cross-repo filesystem dependency" rule).

## What "same quality, not same look" means here

The product site should read as **crafted with the same care** as the
portfolio — clean typography, real content hierarchy, no template-feel —
without becoming a re-skinned copy of the portfolio's cobalt/Archivo
identity. Both are real, considered designs; they just serve different
products with different, deliberately distinct visual identities.
