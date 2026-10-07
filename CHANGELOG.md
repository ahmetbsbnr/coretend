# Changelog

## 2.2.0 — 2026-10-07

CoreTend reaches every Mac and the rest of macOS.

### New
- **Intel Macs**: one universal app for Apple silicon and Intel, macOS 14 or later.
- **Shortcuts and Siri**: « Get Free Space », « Get Space to Clear » and « Open CoreTend ». They
  read and open; none moves a file.
- **Widget**: your Mac's free space and what the last Clean found, on the desktop or in
  Notification Center. Click it to open Clean.
- **Finder**: right-click a folder › « Analyze with CoreTend » opens its map. Drop a folder on the
  Dock icon for the same.
- **System features (optional)**: turn them on in Settings › System to tidy the caches in
  /Library/Caches and turn third-party system services on or off. A small signed helper does it,
  only for CoreTend, only from a fixed list of requests; everything goes to your Trash, with Undo.
  Turning it off removes the helper.

## 2.1.2 — 2026-10-06

More fixes from testing on a real Mac.

- **History records Undo**: each item put back from the Trash appears as "Put back from the Trash".
- **Plain words everywhere**: the last greenhouse terms ("herbarium", "nursery", "plant label",
  "plot") are gone from History, Space and Startup and signatures.


## 2.1.1 — 2026-10-06

Fixes found while testing 2.1 on a real Mac.

- **Full Disk Access is detected again on recent macOS.** The per-user privacy database CoreTend
  read no longer exists, so the first launch stayed on "Open System Settings" and the Home never
  said access was missing. CoreTend now tries several protected places.
- **Space on a large home folder**: results now reach the window once, at the end, instead of
  ten times a second. On a 356,000-file home the window took 237 s where the scan engine alone
  takes about 40 s; this removes that overhead.
- **Uninstall** offers only the app when another copy with the same identifier is installed, so
  it never takes the files that copy still uses.
- **Undo** says why some items stayed in the Trash (their app had already recreated them), and
  the Trash counter starts again at zero.
- **VoiceOver**: the Undo and Open System Settings buttons are their own elements again.


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
