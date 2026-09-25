# CoreTend "Instrument" redesign (2026-09)

The app's presentation layer was rebuilt around one idea: CoreTend is a
precision instrument for a Mac, not a marketing surface. What the product
does (scan engines, SafetyCore gate, Trash-only execution, persistence,
permissions) is unchanged; how it is shown is new.

## Visual language

| Decision | Rule |
|---|---|
| Surfaces | Three flat steps: well (sidebar, meter tracks) < canvas (window) < panel (content). No drop shadows, no glass, no glow gradients. |
| Separation | 1pt hairlines (`MCHairline`, `MCColor.separator`) instead of boxes-in-boxes. |
| Radii | 4 (small) / 5 (control) / 7 (panel) / 10 (hero). Capsules only for toggles. |
| Colour | One teal signal (unchanged, shared with site and icon). Graphite neutrals. Amber = caution, coral = irreversible. `MCColor.onAccent` is the ink on filled teal (white on porcelain, near-black on slate). |
| Type | Three voices: large light tabular numerals (`displayMetric`, `readout`), SF Pro for prose, monospaced caps for labels, tags, paths and byte counts (`eyebrow`, `badge`, `mono`). |
| Gauges | Segmented linear `MCMeter` replaces rings everywhere. |
| Motion | Short, one-shot fades (`mcAppear`), press dips, hover washes; the scan dial's read head is the only continuous motion, and it stops under Reduce Motion. |

## Primitives (`Sources/DesignSystem`)

- Buttons: `.mcPrimary`, `.mcSecondary`, `.mcQuiet`, `.mcDestructive` (+ `Large`), `.mcIcon`, `.mcRow`. The window root sets `.mcSecondary` as the default, so an unstyled `Button` is never off-system.
- Page structure: `MCPageHeader` (eyebrow, title, context, trailing actions), `MCBriefing` (module landing), `MCPanel` (titled region), `MCCard` (untitled surface), `MCActionBar` (pinned commit strip for review lists).
- Data: `MCReadout`, `MCKeyValueRow`, `MCMeter`, `MCMetricCard`, `MCStatusBadge`, `MCTag`.
- Small parts: `MCEyebrow`, `MCIconTile`, `MCKeycap`, `MCHairline`, `MCSectionHeader`.
- States: `MCEmptyState`, `MCSuccessState`, `MCScanStage` (graduated dial), `MCScanButton` (command bar with ↩ keycap).

## Information architecture

- The sidebar is grouped by task: **Reclaim Space** (Cleanup, Space Lens, Duplicates, My Clutter, Cloud), **Apps & System** (Applications, Performance, Integrity), **Workspace** (Activity, Settings).
- Sidebar chrome: brand lockup, a search field that opens the ⌘K palette, and an always-visible startup-disk reading that opens Space Lens.
- **Overview** (formerly Dashboard) reads in order: free space and the primary actions, the safeguards that make acting safe, a dense tool list, recent activity, and the total reclaimed to date.
- Every module shares the same page header; sub-sections (Applications, Integrity, My Clutter) use a segmented control in the header rather than a `TabView`.
- Review screens pin their consequential action (Move to Trash) in an `MCActionBar` at the bottom so it never scrolls away.
- The command palette is keyboard-driven (↑↓ ↩ esc) and split into sections.

## Guardrails kept

- Accessibility identifiers used by UI tests (`*.root`, `storage.scan.start`, `sidebar.<rawValue>`, …) are unchanged.
- Canonical palette values (website-shared) and contrast tests are unchanged.
- Base and fr localization tables stay key-identical.
