# CoreTend Design System

## Overview

CoreTend's public site extends the application's Living System: a precise
instrument with a calm, organic signal. It uses real application media,
system-native typography, and functional color rather than decorative effects.

## Theme

- Default to the operating system's light or dark preference.
- Apply the page background in critical first-paint CSS so the initial frame is
  never white by accident.
- Keep content visible before enhancement scripts run.

## Color Palette

- Core Ink `#0b0f14`: dark canvas and primary ink.
- Soft Porcelain `#f4f6f3`: light canvas.
- Care `#135f4a` light / Fresh Mint `#a8e6c1` dark: storage, care, primary CTA.
- Privacy `#5c54cc` light / Orbit Iris `#9b8afb` dark: privacy and protection.
- Activity `#94600a` light / Warm Amber `#f4c76b` dark: activity and performance.
- Critical `#b83833` light / Signal Coral `#f47f78` dark: errors or destructive action.
- Body copy must meet 4.5:1 contrast; large text and essential controls must
  meet at least 3:1.

## Typography

- Use the macOS/system UI stack; do not fetch remote fonts.
- Use a fluid 1.25 modular scale.
- Keep display letter spacing at or above `-0.04em` and display sizes at or
  below `6rem`.
- Limit prose to roughly 68 characters and balance headings.
- Use the system monospaced stack for hashes and commands.

## Layout

- Content width: 1080px with fluid page gutters.
- Spacing rhythm: 8, 12, 16, 24, 32, 48px plus fluid section spacing.
- Prefer editorial sequences and real product stages over repeated identical
  card grids.
- Radius: 8px controls, 12–14px cards, up to 22px for a singular hero frame,
  pills only for compact statuses and actions.

## Components

- Sticky site navigation with a visible skip link and robust mobile wrapping.
- Hero with concise value, download and GitHub actions, and real CoreTend UI.
- Version-labelled media frame with fixed dimensions and an honest caption.
- Ordered installation steps where sequence conveys required information.
- Functional status badges for unsigned, not notarized, architecture, and OS.
- Native disclosure elements for FAQ, with visible keyboard focus.
- Footer with support, security, privacy, licenses, source, and language links.

## Motion

- Tokens: 140ms fast, 260ms standard, 550ms gentle; use the existing
  `cubic-bezier(0.16, 1, 0.3, 1)` easing.
- Reveal already-visible content through progressive enhancement; never make
  page access depend on an observer firing.
- Animate transforms and opacity for direct feedback. Avoid perpetual
  decoration, layout animation, and scroll hijacking.
- Under `prefers-reduced-motion: reduce`, reveal content immediately, stop
  autoplay, and keep manual video controls.

## Imagery

- Use only privacy-reviewed captures of the real app or genuine macOS dialogs.
- Do not use generative imagery for product UI.
- Export explicit dimensions, responsive WebP where beneficial, PNG fallbacks
  where lossless text rendering matters, and posters for video.
- Every public media item needs provenance, version scope, alternative text,
  and stripped nonessential metadata.
