# CoreTend Agent Handoff

## Git
- Current branch: `feat/macos-integrations-core` (from `feat/restore-center` HEAD `cf00f20`)
- Commits on this branch: `<carry-forward handoff>`, then feat / test / docs (see `git log`)
- Working tree: clean for tracked files at handoff.
- Not pushed. Not merged. `main` untouched. No history rewrite.
- Checkpoints preserved: `feat/restore-center`, `feat/privacy-lab`, `feat/developer-center`, …

## Completed — macOS Integrations Core (App Intents / notifications / scheduled scans)
All read-only, all reusing existing domain services. New files in
`Sources/CoreTendApp/`:
- `AppRouter.swift` — `AppRoute`, `AppRouter` (shared deep-link front door,
  cold-launch buffering, `.mcNavigate` reuse). `MainWindow.onAppear` drains
  `markReceiverReady()` and calls `MacIntegrations.shared.start()`.
- `NotificationService.swift` — `NotificationCategory` (lowDiskSpace /
  scanResults / storageGrowth), `NotificationPolicy` (pure thresholds + rate
  limits), `NotificationPreferences` (`UserDefaults`), `NotificationDelivering`
  protocol + `SystemNotificationDelivery`, `NotificationService`
  (`@MainActor`), `NotificationTapRouter` (delegate + pure `module(from:)`).
- `ScheduledScanService.swift` — `ScanCadence` (off/daily/weekly),
  `ScheduledScanResult`, `BackgroundScheduling` protocol +
  `SystemBackgroundScheduler` (`NSBackgroundActivityScheduler`),
  `ScheduledScanService` (actor, read-only by imports).
- `MacIntegrations.swift` — `@MainActor @Observable` glue; owns scheduler +
  notifications; `start()` (idempotent), `setCadence`, `runScheduledScan`.
  `InertBackgroundScheduler` for the test marker.
- `CoreTendIntents.swift` — 7 `AppIntent`s + `CoreTendModuleAppEnum`.
- `CoreTendIntentText.swift` — pure result-string builders.
- `CoreTendAppShortcuts.swift` — `AppShortcutsProvider`, 6 shortcuts.
- `CleanupTimeline.swift` — shared `[ScanFinding] -> [TimelineCategorySample]`
  (also now used by `CleanupView`).
- `SettingsView.swift` — Scheduled Scans + Notifications sections; 3 new
  `@AppStorage("notif.enabled.*")` keys (added to `settings-matrix.json`).
- Localization: 73 keys added to both `Base.lproj` / `fr.lproj` (parity
  1006 == 1006).
- Tests: 46 new — `NotificationServiceTests` (incl. `NotificationPolicyTests`,
  `NotificationTapRouterTests`), `ScheduledScanServiceTests` (+`ScanCadence`),
  `MacIntegrationsTests` (+`MacIntegrationsSafetyTests` source-grep),
  `AppRouterTests`, `CoreTendIntentsTests` (text/enum/open/image/smoke).
- Docs: new `Documentation/MACOS_INTEGRATIONS.md`; updated `FEATURE_MATRIX.md`,
  `SAFETY_MODEL.md`, `PRIVACY.md`, `Documentation/PRIVACY.md`, `TODO.md`,
  `PROJECT_STATE.json` (tests 649), `SETTINGS_MATRIX.md` (regenerated).

## Architecture decisions
- Scheduler = `NSBackgroundActivityScheduler` (not `BGTaskScheduler`) —
  native, entitlement-free, system-condition-aware, smallest reliable.
  Limitation: fires only while the app runs; documented.
- Read-only by dependency structure: `ScheduledScanService` imports only
  `ScanCore` + `Persistence`; App Intents don't import `FileRules`. Enforced
  by `MacIntegrationsSafetyTests` (comment-stripped source grep) + a
  behavioural test. Not a runtime bool.
- One `AppRouter`, reusing `.mcNavigate`. Notifications + App Intents share it.
- Scheduled scan reuses the interactive Cleanup engine/rules and the shared
  `CleanupTimeline.samples` mapping; snapshot only on `ScanEvent.finished`
  (`trigger = "scheduled"`), never on cancel/incomplete.
- Notifications: aggregates-only bodies; permission in-context only;
  rate-limited + coalesced; one `settings` timestamp row per category.

## Verification (at branch HEAD)
- Build: `Scripts/build.sh` (debug + release) — `Build complete!`, 0 warnings.
- Tests: `Scripts/test.sh` — 649 passed, 0 failing (was 603; +46).
- Repository doctor: `Scripts/repository-doctor.sh` — all checks passed
  (settings matrix updated: 9 settings, no orphans).
- Localization parity: 1006 == 1006 keys.

## HUMAN VERIFICATION REQUIRED
- Shortcuts app: does it discover the App Shortcuts, and show FR phrases?
  (Needs `Metadata.appintents` in the packaged `.app`; `swift build` alone
  does not emit it — a packaging step in `Scripts/package-*.sh` is likely
  needed and is not done here.)
- Real notification permission grant + system delivery + tap.
- Cold-launch deep link (notification tap / `OpenCoreTendModuleIntent` while
  the app is quit).
- Scheduled execution over real wall-clock time (24 h / 7 d).
- VoiceOver / keyboard on the new Settings picker + toggles.
- Second Mac / different supported macOS.

## Not built in this vertical
- WidgetKit and Finder Extension — analysis only (final report / FEATURE_MATRIX).

## Next concrete action
- None for this vertical. If continuing: packaging step to emit and copy the
  App Intents metadata bundle into the `.app`, then HUMAN VERIFICATION in
  Shortcuts.app.
