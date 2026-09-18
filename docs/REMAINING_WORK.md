# Remaining work — atomic backlog

Each item is executable without re-deciding design. Cite the doc section.
Status: ☐ open · ☑ done · ⊘ blocked.

## A — Audit
- ☑ A-01 `Scripts/audit-ui.py` generates `Documentation/Audits/UI_INVENTORY.md`.

## B — Architecture
- ☑ B-01 Eight destinations, three groups (`SidebarGroup.all`).
- ☐ B-02 `SidebarCustomisation.pinned` → set `{.smartCare, .record}`; test.
- ☑ B-03 Activity merged into Record.
- ☐ B-04 Collapsible sidebar; drop `windowMinWidth` to 860 once the sidebar
  can collapse to icons (`MCSidebarMetrics`); update `WindowGeometryTests`.
- ☐ B-05 Tabs remember selection per module for the session (`@SceneStorage`).

## C — Design system
- ☑ C-01 Split `CoreTendApp.swift` into App/ files per FRONTEND_REBUILD; add
  `AppShellSizeTests` (≤120 lines).
- ☐ C-02 `MCSpacing.page` → 20; row-height tokens `rowDense` 28, `row` 36.
- ☑ C-03 Retire `MCCard`, `mcSurface`, `MCElevation`; replace each use with
  section + hairline (11 `MCCard`, 7 `mcSurface` uses per audit).
- ☑ C-04 Retire `MCPrimaryButtonStyle`/Secondary/Destructive; use system styles;
  delete `OnAccentContrastTests`; keep a test that no view uses `MCColor.teal`
  as a button background.
- ☐ C-05 `MCPermissionState` view (title, why, Open System Settings, Continue
  without) used by Cleanup, Explore, Applications, Integrity.
- ☐ C-06 `MCStatusTag` (success/attention/failure/protected/inert) replaces
  ad-hoc capsules in Record, Integrity, Applications.
- ☐ C-07 Remove every `.opacity(` on a colour outside DesignSystem (22 sites).
- ☐ C-08 Icon rules (DESIGN_SYSTEM §Iconography): fix the 11 double-meaning symbols.

## D — Modules
- ☑ D-01 Overview rebuilt per FRONTEND_REBUILD.
- ☑ D-02 Record: 28pt rows, filter + search, sentence summary, inspector
  without tiles, keyboard (↑↓ select, Return focus inspector).
- ☑ D-03 Cleanup review as `Table` grouped by category.
- ☑ D-04 Explore Map is a squarified treemap (breadcrumb + list existed); ☐ D-04b nested cells one level deep, ↑↓/Return on the map itself.
- ☑ D-05 Duplicates decision workflow.
- ☑ D-06 Applications `Table` + inspector + uninstall sheet.
- ☑ D-07 Integrity provenance `Table`.
- ☐ D-08 Performance time axis.
- ☑ D-09 Settings final set (General · Permissions · Exclusions · Data · Updates · About).
- ☐ D-10 Onboarding three steps.

## E — Copy
- ☐ E-01 Apply PRODUCT_VOCABULARY across all strings (both tables).
- ☐ E-02 Remove orphan keys to zero (`LocalizationUsageTests` allowance → 0).
- ☐ E-03 `LocalizationTypographyTests`: French apostrophes and NBSP.

## F — Interaction
- ☐ F-01 Every `Table`/`List`: ⌘A, ⌘-click, shift-click, Return, Space (Quick Look).
- ☐ F-02 Context menus mirror row actions via `FileRowAction` everywhere.

## G — Accessibility
- ☐ G-01 VoiceOver walk per module; record in UI_QA_MATRIX.
- ☐ G-02 Increase Contrast captures per module.

## H — Responsive
- ☐ H-01 Compact strategy per module (inspector → pushed detail).

## I/J — Coherence and polish
- ☐ I-01 Side-by-side contact sheet script (`Scripts/contact-sheet.py`).

## K — QA
- ☐ K-01 `Scripts/capture-matrix.sh` producing `Documentation/Captures/` + gallery HTML.
- ☐ K-02 Release build + notarisation dry run.

## R — Restoration (real inverse)
- ☐ R-04 SafetyCore: `trashItem(at:resultingItemURL:)` must record the
  resulting URL in `safety_log.result` (schema: add `trash_path` via settings
  table? No — new migration v6 adding column is fine on a fresh table; use
  `CREATE TABLE safety_log_v2` + copy to stay idempotent). Then "Put back"
  in the Record inspector, only for rows whose trash path still exists.

## ⊘ Blocked
- ⊘ 1.2 Layered `.icon` → `Assets.car`. Tried: `actool --app-icon CoreTend
  --include-all-app-icons --output-partial-info-plist … Resources/Brand/Sources/CoreTend.icon`
  with Xcode 27.0's `actool`; produces no `Assets.car`, no warning, exit 0.
  `ictool` renders the `.icns` fine (`Scripts/build-app-icon.sh`). Hypotheses:
  `.icon` package needs `icon.json` fields only Icon Composer writes;
  `actool` wants the `.icon` inside an `.xcassets` `.appiconset`. Untested.
