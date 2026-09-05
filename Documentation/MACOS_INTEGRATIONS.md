<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# macOS integrations — App Intents, notifications, scheduled scans, WidgetKit

The production CoreTend integration layer. Every component reuses existing
domain services — there is no second scan, cleanup, or restore engine — and
every one of them is **read-only** with respect to the user's files.
Sections 1–3 (App Intents, notifications, scheduled scans) landed first;
sections 4–5 (the read-only WidgetKit status widget and the Xcode shipping
host that can embed it) landed next.

## 1. App Intents / Shortcuts

Seven `AppIntent` types (`Sources/CoreTendApp/CoreTendIntents.swift`), all
read-only, each a thin wrapper over an existing service; the string
formatting is factored into pure functions
(`CoreTendIntentText.swift`) so it is exhaustively testable.

| Intent | Service reused | Returns |
|---|---|---|
| Get Free Disk Space | `SystemMetrics.MetricsCollector` | `Int` bytes + dialog |
| Get CoreTend Summary | `MetricsCollector` + `TimelineService` + `Store.activity` | `String` |
| Get Storage Change | `TimelineService.overallSinceLastScan()` | `String` |
| Get Reclaimable Developer Storage | `DeveloperCenterService.scan()` | `Int` bytes + dialog |
| Get Integrity Summary | `IntegrityCore` `ProvenanceScanner` / `LoginItemScanner` / `CodeSignInspector` | `String` |
| Inspect Image Metadata | `SystemMetrics.ImageMetadataInspector` (Privacy Lab domain) | `String` |
| Open CoreTend Screen | `AppRouter` (shared deep-link router) | opens the app |

**App Shortcuts** (`CoreTendAppShortcuts.swift`): six entries — CoreTend
Summary, What Changed, Free Disk Space, Developer Storage, Inspect Image
Metadata, Open CoreTend Screen. Every phrase includes `\(.applicationName)`.

### Destructive intents — deliberately absent

There is **no** intent to clean, empty the Trash, delete duplicates, delete
caches, restore, or disable a launch item. This is enforced by dependency
structure, not a runtime flag: `CoreTendIntents.swift` /
`CoreTendIntentText.swift` do not import `FileRules` and never reference
`SafetyCenter` / `CleanupExecution` / `RecoveryPlanService` /
`RestoreService` (`MacIntegrationsSafetyTests` greps the comment-stripped
source and fails if they ever do).

### File parameter

`InspectImageMetadataIntent` takes an `IntentFile` (the macOS-14 form — any
file; `perform()` verifies it is an inspectable image and reports cleanly if
not). The resolved URL is used **for that one call only** — never stored,
never logged. The intent type contains no `Store` / `UserDefaults` /
persistence call. Unavailable / moved / non-image files return a clear
message, never a crash.

### Localization

All runtime strings — every dialog, result, and error message the user
actually reads back — go through `L()` and have full EN + FR parity,
verified by `MacIntegrationsLocalizationTests`.

The Shortcuts-app-facing **metadata** (intent titles, `IntentDescription`s,
`AppShortcut` phrases, `AppEnum` case labels) is a different matter. Apple's
App Intents metadata extractor (`appintentsmetadataprocessor`) requires
every such string to be a plain string literal resolved against the **main
bundle**; it rejects a `LocalizedStringResource` pointed at a framework's
own `Localizable.strings`. So in the shipping build that metadata is
**English literals** (`Sources/CoreTendApp/CoreTendIntents.swift`,
`Sources/CoreTend/CoreTendAppShortcuts.swift`). The user-visible results
stay EN + FR.

The metadata **packaging path is now proven**:
`Scripts/build-xcode.sh` builds through Xcode, the
`ExtractAppIntentsMetadata` phase emits
`Contents/Resources/Metadata.appintents/extract.actionsdata`, and the
script parses it and asserts ≥ 7 App Intents and ≥ 6 auto-discovered App
Shortcuts (`XcodeHostHygieneTests` re-checks the committed project wiring).
What is **still HUMAN VERIFICATION REQUIRED**: that the Shortcuts app
itself lists and runs these actions on a real machine (the extractor
output is necessary, not sufficient, proof of end-user discovery).

## 2. Local notifications

`NotificationService` (`Sources/CoreTendApp/NotificationService.swift`),
`UNUserNotificationCenter` only — no remote notifications, no push backend,
no cloud.

### Categories (each toggleable in Settings)

| Category | Fires when | Taps open |
|---|---|---|
| Low disk space | free space `< 5 GB` (checked on launch and after a scheduled scan — **never on a background poll**) | Storage |
| Scan results | a scheduled scan finished and found `≥ 1 GB` potentially recoverable | Storage |
| Storage growth | tracked storage grew `≥ 5 GB` since the previous comparable scan (only known right after a scan; delivered coalesced with "scan results") | Storage Timeline |

There is **no "a scan ran" notification** — a scan completing is not, by
itself, worth interrupting the user.

### Permission

Requested **only** from an explicit action — the "Enable Notifications…"
button in Settings, or the onboarding opt-in. Never automatically at first
launch. Settings shows the real system status and, when denied, a button to
System Settings.

### Rate limiting & coalescing

`NotificationPolicy` (pure, fully tested). Minimum spacing per category:
low-disk **24 h**, scan-results **12 h**, storage-growth **24 h**. When a
scheduled scan qualifies for both "scan results" and "storage growth", a
**single** coalesced notification is sent (two lines), and only the parts
that were actually included stamp their rate-limit clock. The only persisted
rate-limit state is one `settings` row per category
(`notif.lastFired.<category>` = timestamp).

### Privacy

Notification titles and bodies contain **totals only** — never a file path,
file name, location, GPS value, browser profile name, or restore-manifest
path. `userInfo` carries a single `ModuleID` rawValue for the tap route and
nothing else. `NotificationServiceTests` asserts no post's title/body
contains `/`, the home path, the user name, or `.trash`.

### Navigation

A tap routes through `AppRouter` — the **same** shared deep-link front door
App Intents use. It reuses the existing `.mcNavigate` `NotificationCenter`
routing (sidebar / command palette / Help menu), and buffers a route that
arrives before `MainWindow` has subscribed (cold launch), draining it in
`onAppear`. It also brings the app + main window forward, so a tap works
whether CoreTend was frontmost, backgrounded, menu-bar-only, or launched
fresh. Cold-launch buffering and warm delivery are both tested;
**live cold-launch deep links are HUMAN VERIFICATION REQUIRED**.

## 3. Scheduled read-only scans

### Scheduling mechanism: `NSBackgroundActivityScheduler`

Chosen over `BGTaskScheduler` and a hand-rolled timer because it is:

- **native and right-sized** for low-priority repeating maintenance in a
  running macOS app;
- **pure Foundation** — no entitlement, no `Info.plist`
  `BGTaskSchedulerPermittedIdentifiers`, no sandbox requirement;
- **system-condition aware** — macOS automatically defers it under low
  power / thermal pressure and coalesces it with other maintenance;
- **the smallest reliable option** — `interval` + `tolerance` + `repeats` is
  the entire surface CoreTend needs.

**Limitation (documented):** it fires only while CoreTend is running (or the
system wakes it from suspension) — it does **not** relaunch a quit app.
Acceptable for a utility typically left running / in the menu bar; a
launch-on-demand agent would need the still-unbuilt privileged helper.

The API is wrapped behind a `BackgroundScheduling` protocol so tests fire the
activity synchronously; under the isolated test marker the app uses an inert
no-op scheduler so a smoke launch registers nothing.

### Cadence

**Off / Daily / Weekly** — no arbitrary schedule syntax. Daily = 24 h
interval (2 h tolerance); Weekly = 7 d (12 h tolerance). Persisted as
`schedule.cadence` in `UserDefaults`; changing it in Settings reschedules
immediately and cancels any run in flight.

### The scheduled-scan contract

A scheduled run (`ScheduledScanService`, an `actor`):

- runs the **same** `ScanEngine` + `UserCleanupRules` catalog the
  interactive Cleanup screen uses, and the **shared** `CleanupTimeline
  .samples` mapping, so its `cleanup`-scope Timeline snapshot is byte-for-byte
  comparable with an interactive one (`trigger = "scheduled"`);
- writes a Timeline snapshot **only** for a scan that reached
  `ScanEvent.finished` — a cancelled or incomplete scan writes nothing;
- records one coarse `.scan` `ActivityRecord`;
- computes growth vs the previous `cleanup` snapshot and hands the totals to
  `NotificationService` for a possible coalesced notification.

It **cannot** execute Recovery Plan, perform Cleanup, delete files, move
anything to the Trash, restore files, or disable a launch item —
`ScheduledScanService.swift` imports only `ScanCore` + `Persistence`, never
`FileRules`, and references no `SafetyCenter` / `CleanupExecution` /
`RestoreService` / `RecoveryPlanService` symbol. The rule catalog is passed
in as inert `[ScanRule]` data. This is a dependency fact, enforced by
`MacIntegrationsSafetyTests`, and proven behaviourally
(`aScheduledScanNeverDeletesOrMovesAnything`).

### Permissions / Full Disk Access

A scheduled Cleanup scan targets the user's own `~/Library/…` subtrees,
which are readable without Full Disk Access; it is never blocked on FDA and
never prompts for it (the existing Settings guidance is the only place FDA is
requested). With reduced access it simply sees fewer files and records a
smaller — but truthful — snapshot. It never silently broadens filesystem
access.

### Concurrency / Store

The scheduled scan runs entirely off the main actor and reuses the single
`AppEnvironment.shared.store` actor — no second `Store` instance. An
`inProgress` flag on the service prevents an overlapping second run (the
scheduler firing while one is still going): the second call returns
`.skippedAlreadyRunning` and writes nothing. The run is cancellable
(`isCancelled` is checked between scan events); an app quit / cadence change
cancels the task.

## 4. WidgetKit status widget (read-only)

A first WidgetKit extension (`WidgetExtension/CoreTendWidget.swift`, target
`CoreTendWidget`) shipping one **read-only** widget, `CoreTendStatusWidget`
(kind `CoreTendStatusWidget`), in `.systemSmall` and `.systemMedium`. It is
a compact, glanceable summary — free disk space of total, storage trend
since the last comparable scan (**stated in words**, never colour/arrow
only), and, when available, potentially recoverable space, last scan date,
and last activity kind.

### It cannot scan or delete — by dependency structure

The widget target links **only** the `WidgetShared` package product. It
does not — cannot — import `ScanCore`, `SafetyCore`, `FileRules`,
`Persistence`, `AppDiscovery`, `IntegrityCore`, or `CoreTendApp`, and
references no `ScanEngine` / `SafetyCenter` / `RestoreService` /
`RecoveryPlanService` / `DeveloperCenterService` / `trashItem` symbol.
`XcodeHostHygieneTests.theWidgetSourceLinksNothingThatCouldScanOrDelete`
greps the comment-stripped source and fails if that ever changes. The
`TimelineProvider` reads exactly one small JSON file and builds entries;
its refresh policy is `.after(+1 h)`, never continuous.

### Host → widget data flow (App Group snapshot, no shared DB)

The host and the extension share one App Group,
`group.com.ahmetbsbnr.coretend` (a macOS group id, used verbatim — no team
prefix). The host **never** opens its SQLite/WAL store cross-process.
Instead:

1. On a meaningful event only — launch once metrics are available, a
   completed interactive scan, a completed scheduled scan, a restore that
   changed the summary — `WidgetPublisher` (`Sources/CoreTendApp/`)
   computes a tiny derived `WidgetSnapshot`.
2. It writes that snapshot atomically (`Data.write(options: [.atomic])`)
   to `widget-snapshot.v1.json` in the App Group container, then calls
   `WidgetCenter.shared.reloadTimelines(ofKind:)` (wrapped behind the
   `WidgetReloading` protocol for testing).
3. The widget's provider reads it via `WidgetSnapshotStore`.

There is **no polling** and no timer-driven publish.

### Snapshot schema (`Sources/WidgetShared/WidgetSnapshot.swift`)

Versioned from day one (`schemaVersion`, currently `1`). Fields:
`generatedAt`, `freeBytes`, `totalBytes`, optional `reclaimableBytes`,
optional `sinceLastScanDeltaBytes`, optional `lastScanDate`, optional
`lastActivityKind` (`scan` / `cleanup` / `restore` / `error`). **No path,
filename, GPS value, restore-manifest entry, browser-profile name, image
metadata value, or security finding** is ever written — aggregates only,
and the widget is visible on the desktop.
`WidgetPublisherTests.theSnapshotFileNeverContainsAPathLikeString` proves
even a path-bearing activity summary reduces to a bare kind string.

### Empty and error states

`WidgetSnapshotStore.read()` returns a typed `unavailable(reason:)` for:
App Group container missing, file absent, unreadable/partial write, invalid
JSON, or an unsupported **future** schema version. Every one maps to a
useful placeholder ("Open CoreTend once to see your storage summary here.")
— never a fake `0`. A snapshot older than 7 days is still shown but
labelled "as of <date>". `WidgetDisplayModel` carries an
`accessibilityLabel` that is a full sentence, not a glyph.

### Localization

Widget user-facing text is EN + FR with exact key parity
(`Sources/WidgetShared/Resources/{Base,fr}.lproj/Localizable.strings`, UTF-16
per the repo `.gitattributes`), resolved through `Bundle.module`. No catalog
is duplicated into the extension — it consumes the shared `WidgetShared`
resource bundle. Parity is enforced by
`WidgetLocalizationParityTests` and the CI localization key-parity gate.

**HUMAN VERIFICATION REQUIRED**: adding the widget from the macOS widget
gallery, its small/medium rendering, and VoiceOver reading of the widget on
a real machine.

## 5. Xcode shipping host

The widget, the App Intents metadata bundle, and per-target entitlements
are Apple bundle structures SwiftPM cannot emit. `CoreTend.xcodeproj`
(generated from `project.yml` by xcodegen, tracked, drift-checked by
`repository-doctor.sh`) is a thin `application` + `app-extension` container
around the **same** SwiftPM code — the app target compiles
`Sources/CoreTend/` and links the `CoreTendApp` package product; there is
no second `@main` and no copied source. `swift build` / `Scripts/test.sh`
still run with no Xcode. Full detail:
[XCODE_INTEGRATION.md](XCODE_INTEGRATION.md); signing of the nested
extension: [SIGNING_NOTARIZATION.md](SIGNING_NOTARIZATION.md).

## Settings surface

The **Settings → Scheduled Scans** section is an Off / Daily / Weekly picker
plus a read-only reminder. **Settings → Notifications** has an "Enable
Notifications…" button (when permission is undetermined) or a System Settings
link (when denied), plus one toggle per category. Shortcuts are not
duplicated in Settings — macOS surfaces them itself.

## What this does not include

A **Finder Sync extension** is not built — see `Documentation/FEATURE_MATRIX.md`
and the "Finder Extension readiness" analysis. Notifications are local only;
nothing is transmitted; scheduled scans never clean up automatically; the
widget is strictly read-only and cannot reach any scan, cleanup, or restore
code path.
