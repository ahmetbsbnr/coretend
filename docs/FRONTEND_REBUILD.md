# Frontend rebuild — architecture and per-module specification

## Technical architecture (decided)

```
Sources/CoreTendApp/
  App/            CoreTendApp.swift (scene only) · MainWindow.swift (routing)
                  ModuleCatalogue.swift (ModuleID, SidebarGroup) · AppAppearance.swift
                  Notifications.swift · CaptureHarness.swift · TestModuleOverride.swift
  Shell/          Sidebar*.swift · MenuCommands.swift · CommandPalette · KeyboardShortcuts
  Modules/<Name>/ <Name>Screen.swift (+ tabs, rows, inspector, view model)
  Shared/         ScanControls · FileRowActions · ModuleSubNav · FolderPicker · states
  Services/       AppEnvironment · SystemAuthorization · FolderAccess · UpdateChecker
```
Views never call `Store` directly; they go through a view model that owns
loading state (`Phase`) and exposes pure, testable derivations.
`CoreTendApp.swift` may not exceed 120 lines (test: `AppShellSizeTests`, C-01).

## Per-module specification

### Overview
- Goal: in five seconds — state, changes, attention, next.
- Structure: title row; *Disk* (one row per volume: name, bar used/free with
  teal for "what CoreTend last measured", figures); *Needs attention*
  (rows: glyph, sentence, action button); *Recent* (five Record rows, "See
  all"); *Scan* (rows per scan with last-run and a Start button).
- States: never-scanned (Disk shows free/used only), no FDA (attention row),
  everything fine (Attention omitted).
- Data: `FileManager` volume stats; `Store` last scan dates; `SystemAuthorization`.
- No card; sections divided by hairlines.

### Record — see INFORMATION_ARCHITECTURE. Rows 28pt, `Table`-like list.
### Cleanup — idle (one sentence + Start), scanning (`MCScanControls`),
review (`Table`: item, location, size, category; grouped by category with
disclosure; select all per category), done (sentence + Open Record).
### Explore — Map (bubbles → keep, add breadcrumb + inspector), lenses as
`Table`s with size/date sort and Quick Look.
### Duplicates — left `Table` of groups (count, size, location summary),
right: copies list with "keep" radio, reason line, Quick Look; batch rules
menu (keep newest · keep oldest · keep in Photos library); Move selected to Trash.
### Applications — `Table` (name, size, last used, source, signed);
inspector: associated files with sizes and a per-item checkbox; Uninstall…
sheet listing exactly what moves.
### Integrity — Provenance `Table` (app, source, signature tier, action);
Starts at login `List`.
### Performance — CPU/memory charts with a time axis (last 5 min), current
values as text, thermal/pressure as words; nothing else.
### Settings, Onboarding — INFORMATION_ARCHITECTURE.
