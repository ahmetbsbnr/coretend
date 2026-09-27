# Site browser accessibility smoke

**Date:** 2026-09-27
**Host:** local Chrome DevTools, macOS 27.0
**Scope:** generated local `Website/` routes, EN/FR, loopback HTTP only. This is automated browser evidence, not human accessibility sign-off or release qualification.

## Observed

- Lighthouse mobile navigation audit reran after the site restyle and meta-description change on all 11 pages: language chooser, five English pages, and five French pages. Every page scored Accessibility 100, Best Practices 100, and Agentic Browsing 100; SEO scored 60. Each content route passed 42 audits; language chooser passed 35. Generated pages carry a non-empty meta description, enforced by `Scripts/check_site.py`.
- Current local Chrome emulation checked all ten EN/FR content pages at both 640 × 900 and 320 × 800 CSS pixels, device scale factor 1. Each page loaded the expected document language, had a non-empty meta description and document/body scroll width equal to the viewport at both widths. No horizontal overflow observed. These are emulated viewport checks, not browser zoom or Dynamic Type evidence.
- On each of those ten pages, first Tab focused the localized skip link; its `#main` target existed and focus outline was solid 3 px.
- `Website/site.css` contains a `prefers-reduced-motion: reduce` rule that disables smooth scrolling and reduces animation/transition duration.
- `make site-check` now tests that contract: the media query must disable smooth scrolling and set minimal animation/transition durations with `!important`; fixtures reject a missing query or protection.

## Limits

- Browser viewport width is only a proxy for 200% zoom. Actual browser zoom, operating-system text scaling, contrast in all states, and screen-reader use were not verified. The current DevTools viewport emulation held the CSS width fixed despite browser-zoom shortcuts.
- Reduced-motion CSS was not runtime-emulated; the available Chrome DevTools interface does not expose media-preference emulation. Deployed headers, another browser, and public release behavior remain untested.
- FR-15 is `VÉRIFIÉ` for scoped static bilingual content and generated-site checks. Browser/OS accessibility and deployment checks remain open under NFR-11/NFR-14. SEO 60 does not change publication status: preview intentionally remains `noindex,nofollow`.
