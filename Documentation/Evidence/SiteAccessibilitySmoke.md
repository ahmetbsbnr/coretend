# Site browser accessibility smoke

**Date:** 2026-09-27  
**Scope:** generated French home route only, served from the local `Website/` directory. This is browser evidence for one route, not a human accessibility sign-off or release qualification.

## Observed

- Chrome DevTools Lighthouse navigation audit in mobile mode: Accessibility 100, Best Practices 100, SEO 50. SEO findings were missing meta description and `noindex,nofollow`; noindex is intentional while the preview is unreleased.
- Emulated viewport was 640 × 900 CSS pixels at device scale factor 1. This approximates the reduced layout width expected at 200% zoom on a 1280-pixel viewport; it does not emulate the browser zoom control itself.
- At that viewport, `window.innerWidth`, `document.documentElement.scrollWidth`, and `document.body.scrollWidth` were all 640; no horizontal overflow was observed.
- Initial Tab focused the “Aller au contenu” skip link. It matched `:focus-visible` and had a 3-pixel solid outline. Accessibility snapshot exposed banner, named navigation, main, heading structure, and contentinfo.
- `Website/site.css` contains a `prefers-reduced-motion: reduce` rule that disables smooth scrolling and reduces animation/transition duration.

## Limits

- Only `/fr/index.html` was audited; other routes, actual browser zoom, operating-system text scaling, color contrast at all states, and screen-reader use were not verified.
- Browser tool did not emulate reduced-motion preference, so CSS behavior under that preference remains unverified at runtime.
- This local browser audit does not qualify deployed headers, multiple browsers, or public release behavior. NFR-11 remains `PARTIEL`.
