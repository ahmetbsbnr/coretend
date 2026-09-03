<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Reference Site Analysis: TalkInk

Reviewed from the public response at `https://talkink.app/` on 2026-07-27.
This document records principles only. No source, copy, palette, typeface,
illustration, logo, screenshot, or animation is reused by CoreTend.

## Observed principles

- The page explains one job in the first viewport, pairs it with one primary
  download action, and states compatibility close to that action.
- The narrative moves from promise to real demonstration, three-step workflow,
  privacy, feature detail, installation, product screenshots, FAQ, and footer.
- Real media appears early and again near installation. Ordered steps are used
  only where sequence matters.
- Motion reinforces the product metaphor and scroll progression. Content stays
  visible without JavaScript; the observer script adds classes only after the
  document marks JavaScript as available.
- Reduced motion collapses animations to near-zero durations and replaces the
  animated waveform with a static shape.
- The responsive implementation collapses three-column sections below 900px,
  hides secondary navigation, removes tilted screenshots, and reduces display
  sizes on narrow screens.

## Evidence and performance characteristics

- Initial HTML: 14,382 bytes transferred after decompression.
- CSS: 22,298 bytes.
- Locally referenced media inspected: demo GIF 193,556 bytes; screenshots
  327,039 and 119,546 bytes; social image 591,229 bytes; icon 8,579 bytes.
- The page also requests three Google font families and Vercel Insights.
- The public response uses gzip, HSTS, and a Vercel cache hit. It does not
  publish an explicit CSP in the inspected response.
- The hero contains several continuous animations, large blurred fixed
  gradients, backdrop filters, and a fixed grain layer. These are visually
  distinctive but add paint work and are inappropriate for CoreTend's quieter
  instrument-like identity.
- The main content is present in the HTML when JavaScript is disabled. Hero
  entrance elements still use CSS keyframes; the page supplies a reduced-motion
  override.

## Adapted for CoreTend

- State the real platform, beta, signing, and notarization status next to the
  download decision.
- Put privacy-reviewed product media in the first viewport and installation
  media beside the exact step it explains.
- Use a short ordered installation sequence followed by evidence-based
  capability groups, privacy/safety, open source, and FAQ.
- Keep progressive enhancement, native disclosure controls, explicit media
  dimensions, and reduced-motion behavior.
- Preserve a fast static build and avoid a JavaScript framework.

## Refused

- No dark glassmorphism, green glow, noise overlay, gradient text, remote
  typefaces, animated typing replica, waveform replica, or persistent aurora.
- No copied layout proportions, phrasing, icons, illustrations, media angles,
  card treatments, or animation timings.
- No analytics or third-party font requests.
- No claim that an unsigned CoreTend build is approved, signed, or notarized.

## Deliberate differences

CoreTend uses its existing Living System palette, Core Bloom mark, system
typography, bilingual multi-page information architecture, and a restrained
light/dark surface. Its narrative emphasizes reviewability, explicit confirmation, reversible
actions, read-only integrity signals, installation safety, and release
provenance. Motion is event-driven or short-lived rather than atmospheric.

## Imitation risks to avoid

The combination of a centered full-height dark hero, glowing green backdrop,
split sans/italic-serif headline, glass pill navigation, animated fake product
control, three glass step cards, and tilted screenshots would read as a clone
even if colors changed. CoreTend must keep a different composition and use its
real UI as the visual anchor.
