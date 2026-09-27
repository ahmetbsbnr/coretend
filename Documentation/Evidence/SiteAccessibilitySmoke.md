# Site browser accessibility smoke

**Date:** 2026-09-27
**Host:** local Chrome DevTools, macOS 27.0
**Scope:** generated local `Website/` routes, EN/FR, loopback HTTP only. This is automated browser evidence, not human accessibility sign-off or release qualification.

## Observed

- Lighthouse mobile navigation audit ran on all 11 pages: language chooser, five English pages, and five French pages. Every page scored Accessibility 100, Best Practices 100, and Agentic Browsing 100. SEO scored 50 throughout; findings include intentional `noindex,nofollow` for the unreleased preview and missing meta descriptions.
- The ten EN/FR content pages were checked at 640 × 900 CSS pixels, device scale factor 1. This approximates the reduced layout width expected at 200% zoom on a 1280-pixel viewport; it does not emulate the browser zoom control itself. Each page had `innerWidth` 640 and `scrollWidth` 640, with no horizontal overflow.
- On each of those ten pages, first Tab focused the localized skip link; its target existed and focus outline was solid 3 px.
- `Website/site.css` contains a `prefers-reduced-motion: reduce` rule that disables smooth scrolling and reduces animation/transition duration.
- `make site-check` now tests that contract: the media query must disable smooth scrolling and set minimal animation/transition durations with `!important`; fixtures reject a missing query or protection.

## Limits

- Browser viewport width is only a proxy for 200% zoom. Actual browser zoom, operating-system text scaling, contrast in all states, and screen-reader use were not verified.
- Reduced-motion CSS was not runtime-emulated; the available Chrome DevTools interface does not expose media-preference emulation. Deployed headers, another browser, and public release behavior remain untested.
- FR-15 is `VÉRIFIÉ` for scoped static bilingual content and generated-site checks. Browser/OS accessibility and deployment checks remain open under NFR-11/NFR-14.
