# Changelog

## 2.0.0 — 2026-09-28

A complete rebuild of CoreTend, in a new identity: the living greenhouse.

### New
- **Serre design**: palette, typography, leaf shapes and a whole greenhouse that lives — roots
  that follow real scans, leaves that fall into the Trash, pollen and swaying shoots while the
  window is in front (drawn by Core Animation, near-zero CPU, off with Reduce Motion, Low Power
  Mode or one setting). Liquid Glass app icon made with Icon Composer.
- **Eight tools**: Overview, Explore, Cleanup, Duplicates, Applications, Integrity, Performance,
  Record — each in every state (initial, running, results, empty, partial, denied, error).
- **Explore** walks into subfolders with a breadcrumb; plots in proportion.
- **Duplicates**: choose the kept copy (never movable); recoverable space per group and in total.
- **Applications**: real size of each app, sort by name, size or version, open rows with actions,
  clear explanation when macOS refuses a move, files around an app matched by name too.
- **Integrity**: label a whole folder of apps in one pass.
- **Performance**: memory in use from macOS, the load drawn over time.
- **Welcome** in three pages; **Settings** in four tabs; ⌘K search; optional menu bar extra.

### Safety
- Every destructive confirmation has Cancel as its Return default (checked by the build).
- Moves go only to the macOS Trash, after selection, review, confirmation and revalidation.
- No network, no telemetry, no Full Disk Access request.

### From 1.x
- 2.0 replaces 1.x (same bundle identifier). 1.x data are not touched; its preferences and
  exclusions can be imported from Settings.

### Known limits
- Built for macOS 14 or later; tested on macOS 27 (MacBook Air M1 and M5).
- VoiceOver not yet reviewed by a person.
