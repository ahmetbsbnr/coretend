<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Website QA

Generated pages are bilingual EN/FR and share one source. Automated checks
confirm internal links, language, titles, one H1, skip link, image alt text,
viewport, locale parity, placeholders and private-data rules. Canonical and
hreflang metadata, robots and sitemap are generated together.

Media slots are conditional: the generator emits no screenshot or video
reference until privacy-approved files exist. Once present, images use
intrinsic dimensions and lazy loading; the home demo source is limited to
`prefers-reduced-motion: no-preference`, while the demos page uses controls.

Manual source review covers 320, 390, 768, 1440 and 1920 CSS layouts: the hero,
feature rows and demo row collapse to one column below 760 px; navigation wraps;
tables scroll; media preserve aspect ratio. Browser screenshots and interactive
console/Lighthouse measurements remain pending because no browser automation
tool is installed. Do not claim a Lighthouse score until measured.

Current local build: 14 pages × 2 locales, no essential JavaScript, strict CSP,
no trackers, indexable robots and sitemap. Production still serves the previous
deployment until explicit redeployment authorization.
