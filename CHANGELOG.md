# Changelog

## 2.1.0 — 2026-10-06

CoreTend leaves the Mac App Store and becomes a complete, free app without a sandbox.

### New
- **Four spaces** instead of eight tools: Home, Space, Clean, Apps; History at the sidebar's foot.
- **Full Disk Access**, offered once at first launch and explained in one sentence; CoreTend reads
  the whole home folder in one click, and says when macOS keeps something closed.
- **Clean** reads 14 rules at once — app caches and logs, crash reports, Xcode build files,
  archives and device files, simulator caches, npm, pnpm, Gradle and Cargo caches, Mail
  attachments, iPhone backups — grouped by risk (Safe, Check first, Important). Safe items are
  ticked; one review; **Undo** puts everything back from the Trash.
- **Complete uninstall**: the app and the files it left in ~/Library, listed with their size.
- **Signed automatic updates** (Sparkle), only if you allow them; Check for Updates in the menu.
- **Command line**: `coretend clean` (dry run, `--confirm` to move safe items to the Trash) and
  `coretend mcp`, a read-only MCP server for AI assistants. On npm as `coretend`.
- Plain words everywhere; the interface follows macOS: French when it prefers French, English
  otherwise.

### Changed
- Settings no longer offer a language choice.
- No Mac App Store version (decision 0005).


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
