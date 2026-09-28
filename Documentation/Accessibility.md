# Accessibility qualification checklist

Automated structure currently uses SwiftUI navigation, semantic labels, headings and system controls. Manual pass remains required before qualification.

- Navigate all eight destinations and Settings using keyboard only; verify visible focus and predictable selection restoration.
- Inspect VoiceOver names, roles, headings, result counts, progress, errors, and duplicate keeper suggestions.
- Test at 200% zoom and narrow window width; confirm no clipped controls or horizontal-only reading.
- Verify contrast in light and dark appearances; do not encode risk/state by color alone.
- Verify Reduce Motion and Reduce Transparency behavior; no continuous idle animation.
- Test EN and FR copy for truncation and terminology consistency.
- Record OS/build, route, assistive technology, result, and unresolved issue in `Documentation/Evidence/Accessibility.md`.

## Automated native probe — 2026-09-27

- On arm64/macOS 27, a temporary `.app` bundle with isolated HOME, preferences and SQLite store accepted `⌘K`, exposed the palette search field as focused, accepted “Performances”, and opened Performance on Return. Accessibility inspection found the route's measured system labels and history content.
- This confirms one keyboard route through the palette in the fixture bundle. Direct sidebar arrow navigation was not confirmed; VoiceOver speech, focus order across all destinations, Dynamic Type, zoom, contrast, Reduce Motion/Transparency, and production preference restoration remain unqualified. No real user store was used.

## P4 — recette transverse

Le protocole destination par destination, les ratios calculés et les limites de preuve
sont consignés dans `Documentation/Evidence/Accessibility.md`, section lot 4.1 du
28-09-2026. Les tests de tokens et de palette ne remplacent pas VoiceOver parlé,
l’agrandissement réel ni les préférences d’accessibilité système.
