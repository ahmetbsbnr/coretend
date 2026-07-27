<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Website Performance

## Initial-load defect

Root cause confirmed on 2026-07-27:

1. Production `/` returned a 260-byte HTML document with a zero-delay
   `meta refresh` to `en/index.html`, so the browser painted an otherwise
   unstyled white document before navigation.
2. Localized pages declared the theme but relied on the external stylesheet
   for the first background color. On a cold request, the browser could paint
   its default canvas before that stylesheet arrived.

The defect was not an application splash screen or hydration issue. The site
is static and has no client-side framework.

## Correction

- Vercel now redirects `/` directly to `/en/index.html`; the intermediate HTML
  document is no longer rendered in production.
- Every localized page includes a tiny light/dark critical background rule.
- The generator computes the exact SHA-256 CSP allowance for that inline rule,
  preserving a strict policy without `unsafe-inline`.
- The external stylesheet repeats the `html` background as the maintained
  source of visual tokens.
- Content remains present without JavaScript and reveal effects never gate
  visibility.

## Baseline

Before this change, the public root response was 260 bytes and required a
second navigation before the real page could begin rendering. The production
localized page otherwise used static HTML/CSS with no executable JavaScript,
remote font, tracker, or application hydration.

The TalkInk reference measured during the same review used 14,382 bytes of
HTML, 22,298 bytes of CSS, roughly 1.24 MB across the inspected local media,
three remote font families, and Vercel Insights. These figures are comparative
evidence, not a CoreTend performance target.

## Validation gates

The site gate must verify the generated redirect, critical style, matching CSP
hash, visible no-JavaScript content, explicit media dimensions, no unexpected
autoplay, no missing asset, and consistent light/dark initial background.
Browser first-frame captures are retained under temporary audit output rather
than committed when they contain no durable project evidence.

## Commercial redesign runtime

The redesign adds one local progressive-enhancement file, `assets/site.js`
(about 1.3 kB uncompressed). It performs only mobile-navigation state and
one-shot `IntersectionObserver` reveals. It makes no network request, uses no
cookie or client storage, and is not required for content visibility.
`script-src` remains limited to `'self'`.

The initial real product image uses a roughly 105 kB WebP with PNG fallback
and explicit dimensions. No video, webfont, framework, CDN, analytics, or
third-party script is loaded at first paint.
