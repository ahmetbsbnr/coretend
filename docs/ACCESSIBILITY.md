# Accessibility — rules and checks

Built during implementation, verified at the end. Contract tests live in
`Tests/CoreTendAppTests/*Accessibility*` and `AppearancePaletteTests`.

## Rules
1. Every row is one AX element with a label that reads as a sentence
   (`accessibilityElement(children: .combine)` + explicit label on custom rows).
2. Every action reachable by hover is also in the context menu and the
   inspector. Nothing depends on hover or swipe.
3. Every module is reachable by ⌘-digit; every tab by ⌘⇧[ ] and by the tab
   control's own keyboard handling.
4. Focus order = reading order. Custom containers set `accessibilitySortPriority`
   only to fix a real mismatch.
5. Contrast: text ≥ 4.5:1 on its real surface in all four modes; non-text
   meaning-carrying marks ≥ 3:1.
6. Increase Contrast: palette variants are required, not optional
   (`MCPaletteColor` has no default for them).
7. Reduce Transparency: only system materials are used, so it is honoured by
   construction; `mcNavigationGlass` checks it explicitly.
8. Reduce Motion: every animation goes through `mcAnimation` / `MCMotion.animation`.
9. VoiceOver values: metrics expose label + value ("Moved to Trash, 3.55 GB").
10. Destructive controls carry `role: .destructive` so VoiceOver announces it.

## Verification (per module, recorded in UI_QA_MATRIX.md)
- VoiceOver walk of the default state (⌘F5, VO-→ through the screen).
- Keyboard-only: reach every action without a pointer.
- Switch Control: item scanning reaches the primary action in ≤ 6 moves.
- Captures in Increase Contrast, both appearances.
