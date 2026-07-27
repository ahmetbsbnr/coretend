# Portfolio ↔ Product Site Alignment — Action Items

Concrete, not-yet-executed alignment items derived from
`CROSS_SITE_DESIGN_AUDIT.md`. Nothing here has been implemented on either
site.

## Genuinely worth aligning

1. **Spacing-scale naming**: expose the product site's `--space-xs`
   through `--space-xxl` semantic names on the portfolio too (even if the
   underlying numeric values differ per Tailwind's scale) — cheap,
   improves cross-team readability if the same person maintains both.
2. **Focus-visible audit**: confirm the portfolio has a visible,
   consistent focus ring (not just relying on `outline: 2px solid
   rgb(var(--cobalt))` seen once in `globals.css` — verify it applies to
   every interactive element, not just one). Product site's accessibility
   posture is already documented (`Documentation/KNOWN_LIMITATIONS.md`,
   Step 12's code-level audit) — hold the portfolio to the same bar.
3. **Max-width parity**: audit the portfolio's actual max content width
   and either match the product site's 960px or document why it's
   deliberately different (a personal portfolio often wants a different,
   more editorial-magazine width than a product marketing site).
4. **Dark-mode mechanism**: confirm the portfolio uses the same
   `prefers-color-scheme` media-query token-override pattern as the
   product site (simplest, most portable, no JS toggle needed) rather
   than a class-based toggle — if it already does, document it; if not,
   this is a real, low-cost consistency win.
5. **Editorial quality bar**: no action needed structurally — both sites
   already avoid dark patterns/fake urgency per this session's read of
   each (product site audited across prior sessions; portfolio's
   security-headers-forward `vercel.json` and clean redirect table read
   as the same care level). Worth stating explicitly as a shared
   principle in `shared/brand-guidelines/` once that folder exists.

## Deliberately NOT aligned (see `CROSS_SITE_DESIGN_LANGUAGE.md` for why)

- Color palette (product site's 4-hue functional system vs. portfolio's
  single cobalt accent) — stays separate, both are correct for their own
  purpose.
- Typography (system font vs. Archivo/Plex Mono) — stays separate.
- Motion (none vs. GSAP) — stays separate.
- Framework/build pipeline — stays separate, no shared runtime.

## Sequencing

This alignment work is **not scheduled** — it depends on the workspace
migration (`WORKSPACE_MIGRATION_PLAN.md`) landing first, so
`shared/design-language/` has a real home, and on the brand name being
resolved (`BRAND_NAME_CLEARANCE.md`) so the product site's own identity
is stable before investing in cross-site polish work. Listed here as
ready-to-execute action items for whenever that sequencing allows it, not
as this phase's deliverable.
