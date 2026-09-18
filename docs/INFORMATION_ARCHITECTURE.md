# Information architecture — decided

Final structure of CoreTend. Every line here is a decision, not an option.
Change one on purpose and update this file in the same commit.

## Destinations (sidebar)

| Group | Destination | `ModuleID` | ⌘ | What the person is doing |
|---|---|---|---|---|
| — | **Overview** | `.smartCare` (raw "Smart Care", kept for stored identity) | ⌘1 | "How is my Mac, what changed, what next" |
| — | **Record** | `.record` | ⌘2 | "What did CoreTend do, and can I undo it" |
| Space | **Cleanup** | `.cleanup` | ⌘3 | Move caches, logs, browser caches to the Trash |
| Space | **Explore** | `.spaceLens` | ⌘4 | See where the disk goes: map, largest/oldest, similar images, cloud footprint |
| Space | **Duplicates** | `.duplicates` | ⌘5 | Decide which copy to keep |
| This Mac | **Applications** | `.applications` | ⌘6 | Installed apps, leftovers, updates |
| This Mac | **Integrity** | `.protection` | ⌘7 | Provenance, signing, what starts at login |
| This Mac | **Performance** | `.performance` | ⌘8 | Live CPU/memory/thermal over time |

Removed as destinations: My Clutter, Cloud Cleanup (→ Explore tabs), Activity
(→ Record). Privacy Cleaner moved Integrity → Cleanup. Launch agents moved
Performance → Integrity. Reasons in `SidebarGroup.all`'s comment.

Rules:
- A destination is a *job*, not a data source. Nothing gets a sidebar row for
  having its own table.
- Overview and Record cannot be hidden (`SidebarCustomisation.pinned` extends
  to both — see REMAINING_WORK B-02).
- Eight destinations, nine digits: every module has a ⌘-digit. Adding a ninth
  needs a decision, `MenuCommandTests.everyModuleHasADigit` will say so.

## Secondary navigation

`ModuleSubNav` (segmented on macOS 27 `.tabs`, `.segmented` below) is the only
sub-navigation idiom. Tabs are *views of the same job*, never different jobs:

- Cleanup: Caches & logs · Browser caches
- Explore: Map · Largest & oldest · Similar images · Cloud footprint
- Applications: Installed · Leftovers · Updates
- Integrity: Provenance · Starts at login

Tabs remember their selection per module for the session only.

## The three screens with a distinct model

- **Overview** synthesises. Sections in order: *Disk* (per volume, used/free,
  and what CoreTend measured last time — never a projection), *Needs
  attention* (real findings with an action each: missing Full Disk Access,
  broken login items, unsigned downloaded apps, stale scans > 7 days), *Recent*
  (last five Record items), *Scan* (the scans available, with "last run X
  ago" or "never"). No score, no gauge, no invented total. A section with
  nothing to say is omitted, not shown empty.
- **Record** is list + inspector (Mail/Console model). Row = one operation or
  event; day sections; filter (All · Moved · Refused · Failed · Scans) and a
  search field in the list header; the summary is one sentence, not tiles.
  Inspector: title, state, when, then plain sections separated by hairlines.
  "Put back" appears only when restoration is *real* (see REMAINING_WORK R-04);
  until then there is no restore control anywhere.
- **Explore › Map** is an exploration surface: zoom into a folder, breadcrumb
  back, hover to read, click to select, inspector for the selected node,
  Quick Look on space. Keyboard: arrows move selection among siblings, Return
  zooms in, ⌘↑ zooms out.

## Vocabulary of history

- **Operation**: CoreTend touched files (moved, refused, failed) — has
  per-file evidence. Source: `safety_log` grouped by `operation_id`.
- **Event**: CoreTend noted something without touching a file (scan,
  restore, error). Source: `activity`, kind ≠ cleanup.
- **The Record** is the union. There is no separate "activity" concept in the
  UI any more.

## Settings (final set)

General: Language · Show menu bar item. Updates (Developer ID only): Check
automatically · Check now. Exclusions: list + add/remove. Data: privacy
statement (build-aware) · Erase Record… · Erase all data…. About.

Removed or automatic: anything that toggled a safety behaviour (there is one
behaviour: Trash, always), dry-run mode (retired), per-module scan options
(they live on the module).

## Onboarding (final)

Three steps, skippable at any point, reopenable from Help › Welcome to CoreTend:
1. What it does and does not do (local, no telemetry, Trash only).
2. Access: why Full Disk Access matters, one button to open the pane, a
   visible "Continue without it" that leads to a limited-but-working state.
3. Start: offer the first scan (Cleanup) or Explore.
Refused permission is a normal state with its own copy on every screen that
needs it (`MCPermissionState`), never a dead end.

## Windows, sheets, popovers

- One main window. Settings is the standard Settings scene (⌘,).
- Sheets: confirmations that need reading (erase, uninstall implications).
- Popovers: pickers and filters attached to the control that opened them.
- Inspectors: right pane inside the module (Record, Explore, Duplicates,
  Applications). In compact width the inspector becomes a pushed detail.

## Menus (final)

App: About · Settings… ⌘, · Check for Updates… (Developer ID) · Quit.
File: Export Record as CSV… · Close. Edit: standard. View: Toggle Sidebar
⌃⌘S · Show Shortcuts ⌘/. Go: the eight modules ⌘1–⌘8. Scan: Start ⌘R ·
Pause/Resume ⌘P · Cancel ⌘. Window: standard. Help: CoreTend Help ·
Welcome to CoreTend… · Keyboard Shortcuts.
Every menu item is bound to the same command the toolbar uses
(`CoreTendNavigationCommands`, `.scanCommands`), never a second copy.

## Global search

⌘K command palette (exists) is the global search over destinations and
commands. Module content is searched in-module with a filter field; there is
no cross-module content search — nothing indexes across modules and
pretending otherwise would be a promise the data cannot keep.
