# Feature Inventory — generated, do not hand-edit

Generated from `Documentation/feature-inventory.json` by `Scripts/generate-feature-inventory.py` — the JSON is the single canonical source; this file, `feature-inventory.csv`, and the totals below are all derived from it, never typed by hand. Run `python3 Scripts/generate-feature-inventory.py --check` to verify they still agree.

**Total: 42 features.** Status counts: IMPLEMENTED_UNVERIFIED=4, VERIFIED_COMPLETE=34, VERIFIED_PARTIAL=4.

Status vocabulary: VERIFIED_COMPLETE, VERIFIED_PARTIAL, IMPLEMENTED_UNVERIFIED, UI_ONLY, SIMULATED, DOCUMENTATION_ONLY, BLOCKED_HUMAN, BLOCKED_ENVIRONMENT, BROKEN, DEPRECATED, NOT_STARTED, NOT_APPLICABLE, UNKNOWN.

## App shell (5: VERIFIED_COMPLETE=5)

| id | Feature | Status | Evidence |
|---|---|---|---|
| shell.launch | App launch, `AppEnvironment.shared` singleton creates `Store` at `~/Library/Application Support/MacCareLocal/store.sqlite`, falls back to `:memory:` if init fails | VERIFIED_COMPLETE | Sources/MacCareApp/AppEnvironment.swift:1-17 |
| shell.nav | `NavigationSplitView` + `List(selection:)` sidebar over a `ModuleID` enum, default selection `.smartCare` | VERIFIED_COMPLETE | Sources/MacCareApp/MacCareApp.swift:235-242 |
| shell.menubar | Menu-bar extra: `MenuBarLabel`/`MenuBarView`, live `MetricsSnapshot` + last Smart Care activity, `@AppStorage("menuBarEnabled")` toggle in Settings | VERIFIED_COMPLETE | Sources/MacCareApp/MacCareApp.swift:69-94 |
| shell.onboarding | `OnboardingView`, opens Full Disk Access system pane via a static hardcoded `x-apple.systempreferences:` URL | VERIFIED_COMPLETE | Sources/MacCareApp/OnboardingView.swift:22-23 |
| shell.diagnostics | `DiagnosticReport` — anonymized export, redaction test exists | VERIFIED_COMPLETE | Sources/MacCareApp/DiagnosticReport.swift:83-91 |

## SafetyCore (4: VERIFIED_COMPLETE=3, VERIFIED_PARTIAL=1)

| id | Feature | Status | Evidence |
|---|---|---|---|
| safety.pathvalidator | `PathValidator` — protected-root blocklist (`/System`,`/bin`,…), home-dir block, allowlist containment, symlink-escape resolution via `resolvingSymlinksInPath()` | VERIFIED_COMPLETE | Sources/SafetyCore/SafetyCore.swift:33-90 |
| safety.dryrun | `SafetyCenter` actor: `dryRun` flag (default true), re-validates every path at execution time, skips anything that changed since approval | VERIFIED_COMPLETE | Sources/SafetyCore/SafetyCore.swift:120-169 |
| safety.execute | `execute()` moves approved ops to Trash (`FileManager.trashItem`) — never `rm`, always recoverable via macOS Trash | VERIFIED_COMPLETE | Sources/SafetyCore/SafetyCore.swift:154-163 |
| safety.auditlog | In-memory `auditLog: [String]` appended per operation (`"DRY-RUN"`/`"TRASH" path rule=...`) | VERIFIED_PARTIAL | Sources/SafetyCore/SafetyCore.swift:124,162 (in-memory only, not persisted) |

## ScanCore (4: VERIFIED_COMPLETE=4)

| id | Feature | Status | Evidence |
|---|---|---|---|
| scan.engine | `ScanEngine.run(rules:)` — `AsyncStream<ScanEvent>`, cancellable, symlinks skipped entirely (documented `ponytail:` comment, not followed), excluded-path containment respects path-component boundaries, uncapped totals separate from display cap | VERIFIED_COMPLETE | Sources/ScanCore/ScanCore.swift:117-198 |
| scan.duplicates | `DuplicateEngine` — 3-stage: size bucket → 64 KB partial SHA-256 → full SHA-256, hard-link (same device+inode) collapse | VERIFIED_COMPLETE | Sources/ScanCore/DuplicateEngine.swift:38-131 |
| scan.similarimages | `SimilarImagesEngine` — Vision `VNGenerateImageFeaturePrintRequest` feature-print distance clustering, greedy O(n·k) (documented ceiling), Photos-library directories explicitly skipped, real pixel-count via `CGImageSource` metadata (no full decode) for "best resolution" suggestion only, never auto-deletes | VERIFIED_COMPLETE | Sources/ScanCore/SimilarImagesEngine.swift:1-142 |
| scan.spacelens | `SpaceLensEngine` — bottom-up directory sizing, "Other (small items)" bucket below `minChildSize`, real iCloud-placeholder detection via `ubiquitousItemDownloadingStatusKey`, access-denied flagged as lower-bound not silently wrong; `TreemapLayout` for the visualization | VERIFIED_COMPLETE | Sources/ScanCore/SpaceLensEngine.swift:1-187 |

## FileRules (7: VERIFIED_COMPLETE=7)

| id | Feature | Status | Evidence |
|---|---|---|---|
| cleanup.usercaches | Cleanup rule: user caches — application cache files in ~/Library/Caches, apps rebuild these automatically (low risk, preselected) | VERIFIED_COMPLETE | Sources/FileRules/UserCleanupRules.swift:7-17 |
| cleanup.userlogs | Cleanup rule: user logs — log files in ~/Library/Logs older than 7 days (low risk, preselected) | VERIFIED_COMPLETE | Sources/FileRules/UserCleanupRules.swift:19-29 |
| cleanup.crashreports | Cleanup rule: crash reports — diagnostic reports older than 30 days in ~/Library/Logs/DiagnosticReports (low risk, preselected) | VERIFIED_COMPLETE | Sources/FileRules/UserCleanupRules.swift:31-41 |
| cleanup.xcodederiveddata | Cleanup rule: Xcode DerivedData — build intermediates, rebuilt on next build (low risk, preselected) | VERIFIED_COMPLETE | Sources/FileRules/UserCleanupRules.swift:43-53 |
| cleanup.incompletedownloads | Cleanup rule: incomplete downloads — .download/.crdownload/.part/.partial files in ~/Downloads older than 7 days (low risk, preselected) | VERIFIED_COMPLETE | Sources/FileRules/UserCleanupRules.swift:55-68 |
| cleanup.xcodedevicesupport | Cleanup rule: Xcode device support — debug symbols for old iOS devices, regenerated on reconnect (medium risk, not preselected) | VERIFIED_COMPLETE | Sources/FileRules/UserCleanupRules.swift:70-80 |
| cleanup.iosbackups | Cleanup rule: iOS device backups — local iPhone/iPad backups older than 180 days (high risk, not preselected — user must verify no longer needed) | VERIFIED_COMPLETE | Sources/FileRules/UserCleanupRules.swift:82-92 |

## SmartCare (1: VERIFIED_COMPLETE=1)

| id | Feature | Status | Evidence |
|---|---|---|---|
| smartcare.orchestration | Runs `UserCleanupRules.all` through `ScanEngine`, same `SafetyCenter`/dry-run gate as manual Cleanup | VERIFIED_COMPLETE | Sources/MacCareApp/SmartCareView.swift:71-113 |

## MalwareEngine (3: VERIFIED_COMPLETE=2, VERIFIED_PARTIAL=1)

| id | Feature | Status | Evidence |
|---|---|---|---|
| protection.clamav | `ClamAVScanner` — locates `clamscan` at 3 known Homebrew/MacPorts paths, honestly reports `isAvailable == false` if not installed, invokes via `Process()` with an argument array (never a shell), parses `"path: Signature FOUND"` lines | VERIFIED_COMPLETE | Sources/MalwareEngine/MalwareEngine.swift:30-96 (test gap: Process() invocation itself untested) |
| protection.quarantine | `Quarantine` actor — moves flagged file into app-owned dir, UUID-prefixed name preserves original, strips write/exec perms (`0o400`), JSON manifest, `restore()`/`delete()` explicit user actions only | VERIFIED_COMPLETE | Sources/MalwareEngine/MalwareEngine.swift:100-160 |
| protection.norestorehandling | Restore has no collision handling, no parent-dir recreation, no missing-volume handling (per session-1 `RESTORE.md` note, re-confirmed by reading `restore()` at `MalwareEngine.swift:143-149` this session — a plain `moveItem`, no pre-checks) | VERIFIED_PARTIAL | Sources/MalwareEngine/MalwareEngine.swift:143-149 |

## SystemMetrics (1: VERIFIED_COMPLETE=1)

| id | Feature | Status | Evidence |
|---|---|---|---|
| perf.metrics | `MetricsCollector` — CPU via `host_statistics` tick deltas, memory via `host_statistics64` (active+wired+compressed, matches Activity Monitor's model), disk via volume resource keys, network throughput via `getifaddrs` cumulative-counter delta, thermal via `ProcessInfo.thermalState`. All real Mach/sysctl/BSD calls, nothing simulated. | VERIFIED_COMPLETE | Sources/SystemMetrics/SystemMetrics.swift:1-142 |

## AppDiscovery (3: VERIFIED_COMPLETE=2, VERIFIED_PARTIAL=1)

| id | Feature | Status | Evidence |
|---|---|---|---|
| apps.discovery | `discoverApps()` enumerates `/Applications` + `~/Applications` (one nesting level for suites), reads `Info.plist`, real Spotlight `kMDItemLastUsedDate` (honestly `nil` if unindexed, never guessed), real `com.apple.quarantine` xattr check, Mach-O magic-number architecture detection (arm64/x86_64/universal/unknown) | VERIFIED_COMPLETE | Sources/AppDiscovery/AppDiscovery.swift:63-217 |
| apps.leftovers | `leftovers()` — reverse-DNS bundle-ID pattern match (`looksLikeBundleID`, ≥3 dot-separated parts) in Application Support/Caches/Saved Application State, excludes `com.apple.*`/`group.com.apple.*`, cross-references installed bundle IDs | VERIFIED_COMPLETE | Sources/AppDiscovery/AppDiscovery.swift:150-183 |
| apps.updates | `AppUpdatesView` calls `AppDiscovery().discoverApps()` and opens `macappstore://showUpdatesPage` via NSWorkspace — **this only opens the macOS App Store's Updates pane, it does not itself check for or list available updates from any source** | VERIFIED_PARTIAL | Sources/MacCareApp/AppUpdatesView.swift:26,38-40 (deep-links to App Store, does not itself check updates) |

## MyClutter (3: IMPLEMENTED_UNVERIFIED=3)

| id | Feature | Status | Evidence |
|---|---|---|---|
| clutter.largeold | `MyClutterView` instantiates a plain `ScanEngine()` (default config, all rules) for its Large & Old view | IMPLEMENTED_UNVERIFIED | Sources/MacCareApp/MyClutterView.swift:66 |
| clutter.duplicates | `DuplicatesView` wires `DuplicateEngine` + `SafetyCenter`/dry-run for deletion | IMPLEMENTED_UNVERIFIED | Sources/MacCareApp/DuplicatesView.swift:40,82 |
| clutter.similarimages | `SimilarImagesView` wires `SimilarImagesEngine` | IMPLEMENTED_UNVERIFIED | Sources/MacCareApp/SimilarImagesView.swift:21 |

## SpaceLens (1: IMPLEMENTED_UNVERIFIED=1)

| id | Feature | Status | Evidence |
|---|---|---|---|
| spacelens.view | `SpaceLensView` wires `SpaceLensEngine(root:)`, presumably renders via `TreemapLayout` | IMPLEMENTED_UNVERIFIED | Sources/MacCareApp/SpaceLensView.swift:23 |

## CloudCleanup (1: VERIFIED_PARTIAL=1)

| id | Feature | Status | Evidence |
|---|---|---|---|
| cloud.detect | `CloudCleanupViewModel.detect()`/`scan()` — bespoke scanner (not one of the shared 4 engines), enumerates iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs`) and other declared providers, classifies sync state from the real `ubiquitousItemDownloadingStatusKey` signal (placeholder/partial/local), never triggers a download itself | VERIFIED_PARTIAL | Sources/MacCareApp/CloudCleanupView.swift:10-137 |

## Persistence (2: VERIFIED_COMPLETE=2)

| id | Feature | Status | Evidence |
|---|---|---|---|
| activity.log | `Store.recordActivity`/`activity(limit:kind:)`/`clearActivity()` — SQLite (`sqlite3` C API), WAL mode, actor-isolated, append-only migration list, migrations verified idempotent | VERIFIED_COMPLETE | Sources/Persistence/Store.swift:1-165 |
| activity.grouping | Day-grouping / date-filter (`last7`/`last30`/`all`) logic in `MyActivityView` | VERIFIED_COMPLETE | Sources/MacCareApp/MyActivityView.swift:36-39 |

## Settings (7: VERIFIED_COMPLETE=7)

| id | Feature | Status | Evidence |
|---|---|---|---|
| settings.menubar | Settings: "Show MacCare in the menu bar" toggle, backed by @AppStorage("menuBarEnabled") | VERIFIED_COMPLETE | Sources/MacCareApp/SettingsView.swift:82,93 |
| settings.dryrundefault | Settings: "Dry run by default" toggle, persisted to Store via setSetting("dryRunDefault") | VERIFIED_COMPLETE | Sources/MacCareApp/SettingsView.swift:102-103 |
| settings.clamavstatus | Settings: ClamAV engine install status (read-only), install hint shown when not installed | VERIFIED_COMPLETE | Sources/MacCareApp/SettingsView.swift:110-114 |
| settings.fulldiskaccess | Settings: Full Disk Access status with "Open System Settings" / "Recheck" actions | VERIFIED_COMPLETE | Sources/MacCareApp/SettingsView.swift:127-134 |
| settings.exclusions | Settings: exclusions list — add folder (NSOpenPanel) / remove, persisted to Store | VERIFIED_COMPLETE | Sources/MacCareApp/SettingsView.swift:152-174 |
| settings.clearactivity | Settings: "Clear Activity History" destructive action with confirmation dialog | VERIFIED_COMPLETE | Sources/MacCareApp/SettingsView.swift:181-184 |
| settings.exportdiagnostic | Settings: "Export Diagnostic Report" — opens DiagnosticReportView sheet (preview before save) | VERIFIED_COMPLETE | Sources/MacCareApp/SettingsView.swift:188 |

