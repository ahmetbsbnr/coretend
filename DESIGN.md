# CoreTend Design System

## Overview

CoreTend's public site extends the application's Living System: a precise
instrument with a calm, tactile surface. It uses real application media,
system-native typography, and functional color rather than decorative effects.

The identity is **Porcelain / Slate / Teal** — a warm porcelain-and-slate
neutral base with a single oceanic-teal accent. It is a one-accent system, not
a multi-hue one: color carries meaning on a single axis.

## Theme

- Default to the operating system's light or dark preference.
- Apply the page background in critical first-paint CSS so the initial frame is
  never white by accident (`--paper` porcelain in light, `--paper` slate in
  dark).
- Keep content visible before enhancement scripts run.

## Color Palette

The canonical hex values live in `Sources/DesignSystem/Colors.swift`
(`MCColor.Canonical`) and are exported to the web by
`Scripts/export-design-tokens.py`. Do not hand-copy them elsewhere.

| Role | Light (Porcelain) | Dark (Slate) |
|------|-------------------|--------------|
| Canvas / primary ink | Porcelain `#F6F4EF` / Slate ink `#1B1E22` | Slate `#16191E`–`#1B1E22` / Porcelain ink `#ECEBE4` |
| **Teal** — the one brand accent: storage, protection, performance, every primary action | `#0B6E6C` (~5.5:1 on porcelain) | `#5FD3C6` (~9.3:1 on slate) |
| Amber — caution, functional not brand | `#8A5A12` (~5.4:1) | `#F4C76B` |
| Coral — error, or an action that cannot be undone | `#B83C33` (~5.1:1) | `#F08A7E` |
| Graphite — secondary text / secondary accent (not a second hue) | `#4A535F` | `#7E8894` |

Rules:

- Teal is light-tuned. On the dark canvas it needs the *brightened* sibling
  (`#5FD3C6`), never a darkened one.
- Storage / protection / performance do **not** each get a hue. They are told
  apart by icon and label (Differentiate Without Color).
- Body copy must meet 4.5:1 contrast; large text and essential controls must
  meet at least 3:1. The `PaletteContrastTests` suite enforces this against the
  Swift source values.
- Space Lens treemap uses tonal steps of teal plus graphite/amber neutrals —
  never a rainbow.

## Typography

- Display and UI: **Archivo** (self-hosted woff2, no remote fetch); fall back
  to `"Helvetica Neue", Inter, system-ui, -apple-system, sans-serif`.
- Hashes, commands, terminal, metrics: **IBM Plex Mono**, falling back to the
  system monospaced stack.
- Fluid 1.25 modular scale.
- Keep display letter spacing at or above `-0.04em` and display sizes at or
  below `6rem`.
- Limit prose to roughly 68 characters and balance headings.

The application UI itself is San Francisco only (`MCFont`), per
`Documentation/DESIGN_SYSTEM.md`; Archivo is a site-only choice.

## Layout

- Content width: `--wrap` 1200px (`--wrap-narrow` 760px for prose) with fluid
  page gutters (`clamp(20px, 5vw, 48px)`).
- Spacing rhythm: 8, 12, 16, 24, 32, 48px plus fluid section spacing.
- Prefer editorial sequences and real product stages over repeated identical
  card grids.
- Radius: `--r-sm` 9px controls, `--r` 14px cards, pills only for compact
  statuses and actions.

## Components

- Sticky site navigation with a visible skip link and robust mobile wrapping.
- Hero with concise value, download and GitHub actions, and real CoreTend UI.
- Version-labelled media frame with fixed dimensions and an honest caption.
- Ordered installation steps where sequence conveys required information.
- Functional status badges for unsigned, not notarized, architecture, and OS.
- Native disclosure elements for FAQ, with visible keyboard focus.
- Footer with support, security, privacy, licenses, source, and language links.
- Terminal (`.term`) and inline log surfaces stay dark in both themes, aligned
  to the slate scale; macOS window-control dots keep their standard colors.

## Motion

- Mirror the app tokens: 150ms quick, 300ms standard, 550ms gentle.
- Reveal already-visible content through progressive enhancement; never make
  page access depend on an observer firing.
- Use the Core Bloom arcs as the single ambient brand animation. Animate
  transforms and opacity for direct feedback; avoid unrelated decoration,
  layout animation, and scroll hijacking.
- Under `prefers-reduced-motion: reduce`, reveal content immediately, stop
  autoplay, and keep manual video controls.

The commercial hero is intentionally asymmetrical: direct value proposition
and CTA on the left, the real product window on the right, and Core Bloom
geometry behind it. A small local script handles mobile navigation and
one-shot intersection reveals; essential content remains visible without it.

## Imagery

- Use only privacy-reviewed captures of the real app or genuine macOS dialogs.
- Do not use generative imagery for product UI.
- Export explicit dimensions, responsive WebP where beneficial, PNG fallbacks
  where lossless text rendering matters, and posters for video.
- Every public media item needs provenance, version scope, alternative text,
  and stripped nonessential metadata.

## Relationship to the shared design system

`Website/design-system/` (**Ahmet Design System**, version in
`Website/design-system/VERSION`) is the packaged, licensed extraction of this
language that StagePilot vendors. Token *names* there
(`--paper`, `--ink`, `--cobalt`, `--cobalt-deep`, `--cobalt-lift`) are held
stable across identity changes so downstream consumers adopt new values
without renaming. Changing values here ripples outward only after
`node Website/design-system/build.mjs` and a re-vendor in StagePilot.
