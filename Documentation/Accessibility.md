# Accessibility qualification checklist

Automated structure currently uses SwiftUI navigation, semantic labels, headings and system controls. Manual pass remains required before qualification.

- Navigate all eight destinations and Settings using keyboard only; verify visible focus and predictable selection restoration.
- Inspect VoiceOver names, roles, headings, result counts, progress, errors, and duplicate keeper suggestions.
- Test at 200% zoom and narrow window width; confirm no clipped controls or horizontal-only reading.
- Verify contrast in light and dark appearances; do not encode risk/state by color alone.
- Verify Reduce Motion and Reduce Transparency behavior; no continuous idle animation.
- Test EN and FR copy for truncation and terminology consistency.
- Record OS/build, route, assistive technology, result, and unresolved issue in `Documentation/Evidence/Accessibility.md`.
