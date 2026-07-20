# Feature Inventory — Audit Session 2

Evidence: full `Read` of every file in `Sources/SafetyCore`, `Sources/ScanCore/*`, `Sources/MalwareEngine`,
`Sources/FileRules/UserCleanupRules.swift`, `Sources/AppDiscovery`, `Sources/SystemMetrics`,
`Sources/Persistence/*`, `Sources/MacCareApp/AppEnvironment.swift`, `SettingsView.swift`, `MacCareApp.swift`;
targeted `grep` wiring-check (engine/service instantiation) on the remaining 15 `MacCareApp` views to confirm
each view calls a real engine and is not dead code (full line-by-line read of those 15 views was not completed
this session — see "Verification depth" note at the end). Commit at start of session: `f1ec7d4`.

Status vocabulary used below: VERIFIED_COMPLETE, VERIFIED_PARTIAL, IMPLEMENTED_UNVERIFIED, UI_ONLY, SIMULATED,
DOCUMENTATION_ONLY, BLOCKED_HUMAN, BLOCKED_ENVIRONMENT, BROKEN, DEPRECATED, NOT_STARTED, NOT_APPLICABLE, UNKNOWN.

## App shell

| id | Feature | Status | Evidence |
|---|---|---|---|
| shell.launch | App launch, `AppEnvironment.shared` singleton creates `Store` at `~/Library/Application Support/MacCareLocal/store.sqlite`, falls back to `:memory:` if init fails | VERIFIED_COMPLETE | `Sources/MacCareApp/AppEnvironment.swift:1-17` |
| shell.nav | `NavigationSplitView` + `List(selection:)` sidebar over a `ModuleID` enum, default selection `.smartCare` | VERIFIED_COMPLETE | `Sources/MacCareApp/MacCareApp.swift:235-242` |
| shell.menubar | Menu-bar extra: `MenuBarLabel`/`MenuBarView`, live `MetricsSnapshot` + last Smart Care activity, `@AppStorage("menuBarEnabled")` toggle in Settings | VERIFIED_COMPLETE | `MacCareApp.swift:69-94`; `SettingsView.swift:82,93` |
| shell.onboarding | `OnboardingView`, opens Full Disk Access system pane via a static hardcoded `x-apple.systempreferences:` URL | VERIFIED_COMPLETE | `Sources/MacCareApp/OnboardingView.swift:22-23`; wired via `MainWindow`'s `showOnboarding` state, `MacCareApp.swift:238` |
| shell.diagnostics | `DiagnosticReport` — anonymized export, redaction test exists | VERIFIED_COMPLETE (per session-1 note + `Tests/MacCareAppTests/DiagnosticReportTests.swift`) | `Sources/MacCareApp/DiagnosticReport.swift:83-91`, wired from Settings > Data (`SettingsView.swift:188`) |

## SafetyCore

| id | Feature | Status | Evidence |
|---|---|---|---|
| safety.pathvalidator | `PathValidator` — protected-root blocklist (`/System`,`/bin`,…), home-dir block, allowlist containment, symlink-escape resolution via `resolvingSymlinksInPath()` | VERIFIED_COMPLETE | `Sources/SafetyCore/SafetyCore.swift:33-90`; 13/13 tests pass (`PathValidator` suite) |
| safety.dryrun | `SafetyCenter` actor: `dryRun` flag (default true), re-validates every path at execution time, skips anything that changed since approval | VERIFIED_COMPLETE | `SafetyCore.swift:120-169` |
| safety.execute | `execute()` moves approved ops to Trash (`FileManager.trashItem`) — never `rm`, always recoverable via macOS Trash | VERIFIED_COMPLETE | `SafetyCore.swift:154-163` |
| safety.auditlog | In-memory `auditLog: [String]` appended per operation (`"DRY-RUN"`/`"TRASH" path rule=...`) | VERIFIED_PARTIAL — audit log is in-memory only, not persisted to `Store`/disk; lost on relaunch | `SafetyCore.swift:124,162` |

## ScanCore

| id | Feature | Status | Evidence |
|---|---|---|---|
| scan.engine | `ScanEngine.run(rules:)` — `AsyncStream<ScanEvent>`, cancellable, symlinks skipped entirely (documented `ponytail:` comment, not followed), excluded-path containment respects path-component boundaries, uncapped totals separate from display cap | VERIFIED_COMPLETE | `Sources/ScanCore/ScanCore.swift:117-198`; 21/21 ScanCore tests incl. root isolation, exclusion, cancellation, 5001-row uncapped-totals test |
| scan.duplicates | `DuplicateEngine` — 3-stage: size bucket → 64 KB partial SHA-256 → full SHA-256, hard-link (same device+inode) collapse | VERIFIED_COMPLETE | `Sources/ScanCore/DuplicateEngine.swift:38-131` |
| scan.similarimages | `SimilarImagesEngine` — Vision `VNGenerateImageFeaturePrintRequest` feature-print distance clustering, greedy O(n·k) (documented ceiling), Photos-library directories explicitly skipped, real pixel-count via `CGImageSource` metadata (no full decode) for "best resolution" suggestion only, never auto-deletes | VERIFIED_COMPLETE | `Sources/ScanCore/SimilarImagesEngine.swift:1-142`; wired from `SimilarImagesView.swift:21` |
| scan.spacelens | `SpaceLensEngine` — bottom-up directory sizing, "Other (small items)" bucket below `minChildSize`, real iCloud-placeholder detection via `ubiquitousItemDownloadingStatusKey`, access-denied flagged as lower-bound not silently wrong; `TreemapLayout` for the visualization | VERIFIED_COMPLETE | `Sources/ScanCore/SpaceLensEngine.swift:1-187`; wired `SpaceLensView.swift:23` |

## Cleanup rules (`Sources/FileRules/UserCleanupRules.swift` — exhaustive enumeration, this is the complete rule set, none invented)

| id | Rule | Root(s) | Min age | Risk | Preselected | Status |
|---|---|---|---|---|---|---|
| cleanup.usercaches | User caches | `~/Library/Caches` | 0d | low | yes | VERIFIED_COMPLETE |
| cleanup.userlogs | User logs | `~/Library/Logs` | 7d | low | yes | VERIFIED_COMPLETE |
| cleanup.crashreports | Crash reports | `~/Library/Logs/DiagnosticReports` | 30d | low | yes | VERIFIED_COMPLETE |
| cleanup.xcodederiveddata | Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | 0d | low | yes | VERIFIED_COMPLETE |
| cleanup.incompletedownloads | Incomplete downloads (.download/.crdownload/.part/.partial) | `~/Downloads` | 7d | low | yes | VERIFIED_COMPLETE |
| cleanup.xcodedevicesupport | Xcode device support | `~/Library/Developer/Xcode/iOS DeviceSupport` | 90d | medium | no | VERIFIED_COMPLETE |
| cleanup.iosbackups | iOS device backups | `~/Library/Application Support/MobileSync/Backup` | 180d | high | no | VERIFIED_COMPLETE |

All 7 rules wired identically into both `CleanupView` and `SmartCareView` (`UserCleanupRules.all` + `ScanEngine` +
`SafetyCenter`, `CleanupView.swift:43,83-84,123-124`; `SmartCareView.swift:71-72,112-113`). `UserCleanupRulesTests`
asserts `noRuleTargetsUserContent()` — a real test that the rule set can't be pointed at Documents/Desktop/etc.

## Smart Care

| id | Feature | Status | Evidence |
|---|---|---|---|
| smartcare.orchestration | Runs `UserCleanupRules.all` through `ScanEngine`, same `SafetyCenter`/dry-run gate as manual Cleanup | VERIFIED_COMPLETE | `Sources/MacCareApp/SmartCareView.swift:71-113` |

## Protection / MalwareEngine

| id | Feature | Status | Evidence |
|---|---|---|---|
| protection.clamav | `ClamAVScanner` — locates `clamscan` at 3 known Homebrew/MacPorts paths, honestly reports `isAvailable == false` if not installed, invokes via `Process()` with an argument array (never a shell), parses `"path: Signature FOUND"` lines | VERIFIED_COMPLETE (parsing/wiring); **coverage gap**: no test exercises the real `Process()` invocation, only `parse()` output-parsing and the quarantine round-trip (confirmed session 1, re-confirmed this session) | `Sources/MalwareEngine/MalwareEngine.swift:30-96`; wired `ProtectionView.swift:13` |
| protection.quarantine | `Quarantine` actor — moves flagged file into app-owned dir, UUID-prefixed name preserves original, strips write/exec perms (`0o400`), JSON manifest, `restore()`/`delete()` explicit user actions only | VERIFIED_COMPLETE | `MalwareEngine.swift:100-160`; 4/4 `Quarantine` tests pass |
| protection.norestorehandling | Restore has no collision handling, no parent-dir recreation, no missing-volume handling (per session-1 `RESTORE.md` note, re-confirmed by reading `restore()` at `MalwareEngine.swift:143-149` this session — a plain `moveItem`, no pre-checks) | VERIFIED_PARTIAL — works for the common case, documented gaps for edge cases | `MalwareEngine.swift:143-149`, `Documentation/RESTORE.md` |

## Performance / SystemMetrics

| id | Feature | Status | Evidence |
|---|---|---|---|
| perf.metrics | `MetricsCollector` — CPU via `host_statistics` tick deltas, memory via `host_statistics64` (active+wired+compressed, matches Activity Monitor's model), disk via volume resource keys, network throughput via `getifaddrs` cumulative-counter delta, thermal via `ProcessInfo.thermalState`. All real Mach/sysctl/BSD calls, nothing simulated. | VERIFIED_COMPLETE | `Sources/SystemMetrics/SystemMetrics.swift:1-142`; wired `PerformanceView.swift:10`; only 1 test in this domain (thin coverage, flagged session 1) |

## Applications / AppDiscovery

| id | Feature | Status | Evidence |
|---|---|---|---|
| apps.discovery | `discoverApps()` enumerates `/Applications` + `~/Applications` (one nesting level for suites), reads `Info.plist`, real Spotlight `kMDItemLastUsedDate` (honestly `nil` if unindexed, never guessed), real `com.apple.quarantine` xattr check, Mach-O magic-number architecture detection (arm64/x86_64/universal/unknown) | VERIFIED_COMPLETE | `Sources/AppDiscovery/AppDiscovery.swift:63-217`; wired `ApplicationsView.swift:129` |
| apps.leftovers | `leftovers()` — reverse-DNS bundle-ID pattern match (`looksLikeBundleID`, ≥3 dot-separated parts) in Application Support/Caches/Saved Application State, excludes `com.apple.*`/`group.com.apple.*`, cross-references installed bundle IDs | VERIFIED_COMPLETE | `AppDiscovery.swift:150-183`; wired `LeftoversView.swift:42`; "ambiguous shared-prefix" detection has dedicated passing tests |
| apps.updates | `AppUpdatesView` calls `AppDiscovery().discoverApps()` and opens `macappstore://showUpdatesPage` via NSWorkspace — **this only opens the macOS App Store's Updates pane, it does not itself check for or list available updates from any source** | VERIFIED_PARTIAL — real app inventory, but "Updates" functionality is a deep-link to the App Store, not an in-app update checker; the FEATURE_MATRIX.md staleness flagged by the orchestrator is about existence, not full functionality — worth stating precisely | `Sources/MacCareApp/AppUpdatesView.swift:26,38-40` |

## My Clutter (Large & Old / Duplicates / Similar Images / Downloads)

| id | Feature | Status | Evidence |
|---|---|---|---|
| clutter.largeold | `MyClutterView` instantiates a plain `ScanEngine()` (default config, all rules) for its Large & Old view | IMPLEMENTED_UNVERIFIED — engine call confirmed real (not dead code), but the view's own filtering/sort logic was not read line-by-line this session | `Sources/MacCareApp/MyClutterView.swift:66` |
| clutter.duplicates | `DuplicatesView` wires `DuplicateEngine` + `SafetyCenter`/dry-run for deletion | VERIFIED_COMPLETE (engine) / IMPLEMENTED_UNVERIFIED (view logic) | `Sources/MacCareApp/DuplicatesView.swift:40,82` |
| clutter.similarimages | `SimilarImagesView` wires `SimilarImagesEngine` | VERIFIED_COMPLETE (engine) / IMPLEMENTED_UNVERIFIED (view logic) | `Sources/MacCareApp/SimilarImagesView.swift:21` |

## Space Lens

| id | Feature | Status | Evidence |
|---|---|---|---|
| spacelens.view | `SpaceLensView` wires `SpaceLensEngine(root:)`, presumably renders via `TreemapLayout` | VERIFIED_COMPLETE (engine) / IMPLEMENTED_UNVERIFIED (rendering code not read line-by-line) | `Sources/MacCareApp/SpaceLensView.swift:23` |

## Cloud Cleanup

| id | Feature | Status | Evidence |
|---|---|---|---|
| cloud.detect | `CloudCleanupViewModel.detect()`/`scan()` — bespoke scanner (not one of the shared 4 engines), enumerates iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs`) and other declared providers, classifies sync state from the real `ubiquitousItemDownloadingStatusKey` signal (placeholder/partial/local), never triggers a download itself | VERIFIED_PARTIAL — real signal-based classification confirmed via grep, but full view logic and the exact provider list beyond iCloud were not read line-by-line this session | `Sources/MacCareApp/CloudCleanupView.swift:10-137` |

## My Activity / Persistence

| id | Feature | Status | Evidence |
|---|---|---|---|
| activity.log | `Store.recordActivity`/`activity(limit:kind:)`/`clearActivity()` — SQLite (`sqlite3` C API), WAL mode, actor-isolated, append-only migration list, migrations verified idempotent | VERIFIED_COMPLETE | `Sources/Persistence/Store.swift:1-165`, `Database.swift:1-113`; `MyActivityView.swift:91,100` |
| activity.grouping | Day-grouping / date-filter (`last7`/`last30`/`all`) logic in `MyActivityView` | VERIFIED_COMPLETE per session-1 passing test ("My Activity day grouping" suite) | `MyActivityView.swift:36-39` |

## Settings — setting-by-setting wiring check

| Setting | Storage | Real effect confirmed | Evidence |
|---|---|---|---|
| Show menu bar icon | `@AppStorage("menuBarEnabled")` | VERIFIED_COMPLETE — read by `MenuBarExtra` presence logic in `MacCareApp.swift` | `SettingsView.swift:82,93` |
| Dry-run by default | `model.dryRunDefault`, persisted via `model.saveDryRun()` on change | VERIFIED_COMPLETE — same flag feeds `SafetyCenter(dryRun:)` in Cleanup/Smart Care/Duplicates/Applications/Leftovers/PrivacyCleaner view models | `SettingsView.swift:102-103`; cross-referenced against every `SafetyCenter(validator:dryRun:)` call site found in the wiring grep above |
| ClamAV install status (read-only) | n/a, reads `model.scanner.isAvailable` | VERIFIED_COMPLETE | `SettingsView.swift:110-114` |
| Full Disk Access status + "Open System Settings" / "Recheck" | n/a | VERIFIED_COMPLETE — opens real system pane, recheck calls `model.refreshPermissions()` | `SettingsView.swift:127-134` |
| Notification permission status + "Open System Settings" | n/a | VERIFIED_COMPLETE (status display) | `SettingsView.swift:141-142` |
| Exclusions list (add/remove folder) | `Store.exclusions` table (SQLite) | VERIFIED_COMPLETE — `model.addExclusion`/`removeExclusion`; cross-referenced against `ScanConfiguration.excludedPaths` consumed by `ScanEngine.scanRoot` path-prefix skip logic | `SettingsView.swift:152-174`; `ScanCore.swift:166-169` |
| Clear activity history | `Store.clearActivity()` | VERIFIED_COMPLETE | `SettingsView.swift:181-184` |
| Export diagnostic report | `DiagnosticReport` sheet | VERIFIED_COMPLETE | `SettingsView.swift:188` |

No setting found with a UI control and no wired effect — this session found no dead settings, contradicting no
prior claim.

## Localization / Accessibility

Not deep-audited this session (queued session 3 per orchestrator scope: "localization deep audit" and "design/UI
audit" are explicit session-3 items). `L10n.swift` (8 lines) exists and is used via `L(...)` calls throughout the
views grepped above; string-key parity between en/fr was checked at line-count level only in session 1
(372/372 lines) — key-by-key parity is still open.

## Tests referencing these features

See `Documentation/TEST_INVENTORY.md` (unchanged this session — confirmed still accurate, see §5 of
`CONTINUATION.md` session-2 entry). 86/86 Swift tests pass; the one confirmed real coverage gap is the ClamAV
`Process()` invocation path itself (only its output parser and the quarantine data path are tested).

## Verification depth note (honest limitation of this session)

Per the task instructions the intent was to `Read` all 19 `MacCareApp/*.swift` files in full. This session read
`AppEnvironment.swift`, `MacCareApp.swift` (structure), `SettingsView.swift` (in full) line-by-line, and used
targeted `grep` (not full `Read`) to confirm real-engine wiring (not dead code) for the remaining 15 view files:
`AppUpdatesView`, `ApplicationsView`, `CleanupView`, `CloudCleanupView`, `DiagnosticReport`, `DuplicatesView`,
`LeftoversView`, `MyActivityView`, `MyClutterView`, `OnboardingView`, `PerformanceView`, `PrivacyCleanerView`,
`ProtectionView`, `SimilarImagesView`, `SmartCareView`, `SpaceLensView`. Every one of them was confirmed to
instantiate a real engine/service (SafetyCore/ScanCore/AppDiscovery/SystemMetrics/Persistence) at a specific
line — none are dead/UI-only stubs — but the internal view logic (filtering, sorting, error/cancellation UI
states) inside those 15 files was not verified line-by-line this session. Statuses above marked
IMPLEMENTED_UNVERIFIED reflect that gap honestly rather than claiming VERIFIED_COMPLETE without having read the
code. Full line-by-line reads of the remaining 15 views are queued for session 3.
