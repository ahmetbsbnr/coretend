# Design system — decided

## Principle

Hierarchy comes from structure, placement, type, density and spacing.
Enclosure is the last resort. A rectangle has to buy its place: it must
group things that alignment and whitespace could not.

## Surfaces (`MCPalette`, four values each: light / dark / +contrast)

| Role | Used for | Not for |
|---|---|---|
| `ground` | window content | — |
| `sunken` | sidebar, list headers, inset wells | text panels |
| `raised` | popovers, menus, the *one* elevated tile a screen may have | rows, sections, inspectors |
| `raisedHigh` | hover / pressed on custom rows only | — |
| `border` | hairline between sections; table rules | outlines around content |

Module bodies use **no cards**. `MCCard` and `mcSurface` are retired
(REMAINING_WORK C-03). Sections are separated by a hairline and 20pt.

System materials: sidebar uses the system sidebar material (vibrancy honours
Reduce Transparency automatically). Toolbar is the system toolbar. Nothing
else is glass unless it floats (menus, popovers — system).

## Colour roles

- Accent for **controls and selection** = the user's system accent. Not teal.
- Teal = **data and identity**: metrics, the sparkline/series, the app icon,
  the Overview's disk ring. It never paints a button.
- Semantic: `success` (green), `attention` (amber), `destructive` (coral),
  `inert` (slate). Each only ever means that.
- Text: `textPrimary` / `textSecondary` / `textTertiary` — all ≥ 4.5:1 on
  every surface they may sit on, in all four modes (`AppearancePaletteTests`).
- No ad-hoc `.opacity()` on colours in views. The only tints are
  `accent.opacity(0.18)` for selection wash and the `MCStatusTag` fills,
  both measured.

Buttons: system styles. Primary = `.borderedProminent` (system accent),
secondary = `.bordered`, destructive = `.bordered` with `role: .destructive`.
The custom `MCPrimaryButtonStyle` family is retired: it existed to fix white
on brand teal, and controls no longer wear the brand.

## Typography (`MCFont`, Dynamic Type only)

| Role | Font |
|---|---|
| contentTitle (`pageTitle`) | title2 bold |
| sectionTitle | subheadline semibold |
| groupHeader (small caps labels) | caption semibold + `.textCase(.uppercase)` |
| rowTitle | callout medium |
| body / secondaryBody | body / callout |
| metric / displayMetric | title3 rounded semibold / largeTitle rounded semibold |
| tabular | callout monospacedDigit |
| code (`monoCaption`) | callout monospaced |
| caption / micro | caption / caption2 |
| badge (status) | caption2 semibold |

No `Font.system(size:)` anywhere but the sidebar (mirrors the system row size).

## Spacing

4pt grid. `MCSpacing`: 4 · 8 · 12 · 16 · 24 · 32 · 48; page inset 20 (`page`
becomes 20 — C-02). Row heights: dense table 28, standard list 36.
Section gap 24. Inspector inset 20.

## Radius

`small` 6 (controls) · `card` 8 (popovers) · `hero` 12 (the single elevated
tile) · capsule for tags.

## States

- Selected: system list selection.
- Focus: system focus ring; custom rows use `.focusable()` + `.focusEffect`.
- Hover: `raisedHigh` fill on custom rows; never the only way to reveal an
  action — the context menu and the inspector always carry it too.
- Pressed/disabled: system.
- Progress: `MCScanControls` (one cluster: state, progress, pause, cancel).
- Empty: `MCEmptyState` (icon + one line + optional single action).
- Permission missing: `MCPermissionState` — what is missing, why it matters,
  one button to the pane, one to continue without (REMAINING_WORK C-05).
- Error: inline, red-free sentence with the exact failure, never a modal.

## Motion (`MCMotion`)

`reveal` 0.28 easeOut (content appears) · `transition` 0.22 (tab/pane
change) · `response` 0.15 (control feedback) · `settle` spring (drag/drop).
Every animation goes through `mcAnimation` so Reduce Motion drops it.
Nothing animates to look premium; if it explains no change, it is removed.

## Iconography

SF Symbols only. One meaning per symbol (`Scripts/audit-ui.py §4`).
Navigation (sidebar): 17pt regular, `.hierarchical`, accent when selected.
Row glyphs: 14pt. Empty-state illustration: 40pt `.thin`, never the module's
own icon. Status: `checkmark.circle.fill` success, `exclamationmark.triangle.fill`
attention, `xmark.octagon.fill` failure, `lock.fill` protected — nowhere else.
Actions: `folder` reveals in Finder (the magnifier means search, everywhere on
a Mac), `eye.slash` excludes, `trash` moves to the Trash, `arrow.uturn.backward`
puts back. `Scripts/audit-ui.py §4` lists any symbol carrying two meanings.

## Tables and lists

Data with ≥ 3 attributes → `Table` (sortable, multi-select, context menu).
Otherwise `List`. Both get: selection, ⌘-click, shift-click, arrows, Return
to open/inspect, Space for Quick Look where files are involved, ⌘A.

## Responsive

Three named widths (`CaptureHarness.WindowSize`): compact 1000×700, standard
1180×800, large 1600×860 — 860 because a 16-inch display leaves 869 points of
usable height, and a size that cannot exist cannot be verified. Per module:
- compact: inspector becomes a pushed detail; secondary columns hidden.
- standard: main design.
- large: inspector widens to 400; tables reveal secondary columns. Reading
  material (Overview, the Record's inspector) caps at `MCSize.readableWidth`
  (820) and keeps the rest as margin — a large window is not a reason to
  stretch a sentence until the eye loses the line. Maps and tables take the
  whole width, because there extra width genuinely shows more.
Window minimum stays 1000×580 until the sidebar can collapse (B-04).
