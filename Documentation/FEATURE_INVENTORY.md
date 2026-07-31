# Feature Inventory — generated, do not hand-edit

Generated from `Documentation/feature-inventory.json` by `Scripts/generate-feature-inventory.py` — the JSON is the single canonical source; this file, `feature-inventory.csv`, and the totals below are all derived from it, never typed by hand. Run `python3 Scripts/generate-feature-inventory.py --check` to verify they still agree.

**Total: 53 features.** Status counts: VERIFIED_COMPLETE=51, VERIFIED_PARTIAL=2.

Status vocabulary: VERIFIED_COMPLETE, VERIFIED_PARTIAL, IMPLEMENTED_UNVERIFIED, UI_ONLY, SIMULATED, DOCUMENTATION_ONLY, BLOCKED_HUMAN, BLOCKED_ENVIRONMENT, BROKEN, DEPRECATED, NOT_STARTED, NOT_APPLICABLE, UNKNOWN.

## App shell (6: VERIFIED_COMPLETE=6)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| shell.launch | App launch, `AppEnvironment.shared` singleton creates `Store` at `~/Library/Application Support/CoreTend/store.sqlite`, falls back to `:memory:` if init fails | VERIFIED_COMPLETE | Main window, onboarding, menu bar | Launch, navigate, reopen help | smart-care | yes | isolated temporary store | Sources/CoreTendApp/AppEnvironment.swift:1-17 |
| shell.nav | `NavigationSplitView` + `List(selection:)` sidebar over a `ModuleID` enum, default selection `.smartCare` | VERIFIED_COMPLETE | Main window, onboarding, menu bar | Launch, navigate, reopen help | smart-care | yes | isolated temporary store | Sources/CoreTendApp/CoreTendApp.swift:235-242 |
| shell.menubar | Menu-bar extra: `MenuBarLabel`/`MenuBarView`, live `MetricsSnapshot` + last Smart Care activity, `@AppStorage("menuBarEnabled")` toggle in Settings | VERIFIED_COMPLETE | Main window, onboarding, menu bar | Launch, navigate, reopen help | smart-care | yes | isolated temporary store | Sources/CoreTendApp/CoreTendApp.swift:69-94 |
| shell.onboarding | `OnboardingView`, opens Full Disk Access system pane via a static hardcoded `x-apple.systempreferences:` URL | VERIFIED_COMPLETE | Main window, onboarding, menu bar | Launch, navigate, reopen help | smart-care | yes | isolated temporary store | Sources/CoreTendApp/OnboardingView.swift:22-23 |
| shell.diagnostics | `DiagnosticReport` — anonymized export, redaction test exists | VERIFIED_COMPLETE | Main window, onboarding, menu bar | Launch, navigate, reopen help | smart-care | yes | isolated temporary store | Sources/CoreTendApp/DiagnosticReport.swift:83-91 |
| ui.commandpalette | Cmd+K command palette: fuzzy-filtered jump list over all 11 sidebar destinations plus 2 actions (check for updates, scan Home with Space Lens), dispatched through the existing NotificationCenter (.mcNavigate) routing rather than a second navigation system. | VERIFIED_COMPLETE | Main window, onboarding, menu bar | Launch, navigate, reopen help | smart-care | yes | isolated temporary store | Sources/CoreTendApp/CoreTendApp.swift (CommandPaletteView, paletteMatches); Tests/CoreTendAppTests/CommandPaletteTests.swift |

## SafetyCore (4: VERIFIED_COMPLETE=4)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| safety.pathvalidator | `PathValidator` — protected-root blocklist (`/System`,`/bin`,…), home-dir block, allowlist containment, symlink-escape resolution via `resolvingSymlinksInPath()` | VERIFIED_COMPLETE | SafetyCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/SafetyCore/SafetyCore.swift:33-90 |
| safety.dryrun | `SafetyCenter` actor: `dryRun` flag (default true), re-validates every path at execution time, skips anything that changed since approval | VERIFIED_COMPLETE | SafetyCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/SafetyCore/SafetyCore.swift:120-169 |
| safety.execute | `execute()` moves approved ops to Trash (`FileManager.trashItem`) — never `rm`, always recoverable via macOS Trash | VERIFIED_COMPLETE | SafetyCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/SafetyCore/SafetyCore.swift:154-163 |
| safety.auditlog | Every approve/execute call emits a structured SafetyAuditEvent through SafetyAuditSink; Store persists it to SQLite, which is what backs My Activity. | VERIFIED_COMPLETE | SafetyCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/SafetyCore/SafetyCore.swift:192-198 (emit -> SafetyAuditSink); Sources/Persistence/Store.swift:248-264 (Store: SafetyAuditSink, persists to SQLite). Removed the redundant in-memory auditLog: [String] shadow log (zero consumers app-wide) that this status previously described. |

## ScanCore (4: VERIFIED_COMPLETE=4)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| scan.engine | `ScanEngine.run(rules:)` — `AsyncStream<ScanEvent>`, cancellable, symlinks skipped entirely (documented `ponytail:` comment, not followed), excluded-path containment respects path-component boundaries, uncapped totals separate from display cap | VERIFIED_COMPLETE | ScanCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/ScanCore/ScanCore.swift:117-198 |
| scan.duplicates | `DuplicateEngine` — 3-stage: size bucket → 64 KB partial SHA-256 → full SHA-256, hard-link (same device+inode) collapse | VERIFIED_COMPLETE | ScanCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/ScanCore/DuplicateEngine.swift:38-131 |
| scan.similarimages | `SimilarImagesEngine` — Vision `VNGenerateImageFeaturePrintRequest` feature-print distance clustering, greedy O(n·k) (documented ceiling), Photos-library directories explicitly skipped, real pixel-count via `CGImageSource` metadata (no full decode) for "best resolution" suggestion only, never auto-deletes | VERIFIED_COMPLETE | ScanCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/ScanCore/SimilarImagesEngine.swift:1-142 |
| scan.spacelens | `SpaceLensEngine` — bottom-up directory sizing, "Other (small items)" bucket below `minChildSize`, real iCloud-placeholder detection via `ubiquitousItemDownloadingStatusKey`, access-denied flagged as lower-bound not silently wrong; `TreemapLayout` for the visualization | VERIFIED_COMPLETE | ScanCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/ScanCore/SpaceLensEngine.swift:1-187 |

## FileRules (7: VERIFIED_COMPLETE=7)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| cleanup.usercaches | Cleanup rule: user caches — application cache files in ~/Library/Caches, apps rebuild these automatically (low risk, preselected) | VERIFIED_COMPLETE | Cleanup | Scan and review rule groups | cleanup | yes | neutral temporary folders | Sources/FileRules/UserCleanupRules.swift:7-17 |
| cleanup.userlogs | Cleanup rule: user logs — log files in ~/Library/Logs older than 7 days (low risk, preselected) | VERIFIED_COMPLETE | Cleanup | Scan and review rule groups | cleanup | yes | neutral temporary folders | Sources/FileRules/UserCleanupRules.swift:19-29 |
| cleanup.crashreports | Cleanup rule: crash reports — diagnostic reports older than 30 days in ~/Library/Logs/DiagnosticReports (low risk, preselected) | VERIFIED_COMPLETE | Cleanup | Scan and review rule groups | cleanup | yes | neutral temporary folders | Sources/FileRules/UserCleanupRules.swift:31-41 |
| cleanup.xcodederiveddata | Cleanup rule: Xcode DerivedData — build intermediates, rebuilt on next build (low risk, preselected) | VERIFIED_COMPLETE | Cleanup | Scan and review rule groups | cleanup | yes | neutral temporary folders | Sources/FileRules/UserCleanupRules.swift:43-53 |
| cleanup.incompletedownloads | Cleanup rule: incomplete downloads — .download/.crdownload/.part/.partial files in ~/Downloads older than 7 days (low risk, preselected) | VERIFIED_COMPLETE | Cleanup | Scan and review rule groups | cleanup | yes | neutral temporary folders | Sources/FileRules/UserCleanupRules.swift:55-68 |
| cleanup.xcodedevicesupport | Cleanup rule: Xcode device support — debug symbols for old iOS devices, regenerated on reconnect (medium risk, not preselected) | VERIFIED_COMPLETE | Cleanup | Scan and review rule groups | cleanup | yes | neutral temporary folders | Sources/FileRules/UserCleanupRules.swift:70-80 |
| cleanup.iosbackups | Cleanup rule: iOS device backups — local iPhone/iPad backups older than 180 days (high risk, not preselected — user must verify no longer needed) | VERIFIED_COMPLETE | Cleanup | Scan and review rule groups | cleanup | yes | neutral temporary folders | Sources/FileRules/UserCleanupRules.swift:82-92 |

## SmartCare (1: VERIFIED_COMPLETE=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| smartcare.orchestration | Runs `UserCleanupRules.all` through `ScanEngine`, same `SafetyCenter`/dry-run gate as manual Cleanup | VERIFIED_COMPLETE | Smart Care | Start scan, review, cancel or approve | smart-care | yes | empty isolated store; no staged result | Sources/CoreTendApp/SmartCareView.swift:71-113 |

## IntegrityCore (3: VERIFIED_COMPLETE=3)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| integrity.provenance | `ProvenanceScanner` — reads NSURLQuarantinePropertiesKey (the same metadata Finder/Safari use), never throws, handles malformed/raw quarantine xattr data as not-quarantined rather than crashing | VERIFIED_COMPLETE | IntegrityCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/IntegrityCore/IntegrityCore.swift:43-86; Tests/IntegrityCoreTests/IntegrityCoreTests.swift (ProvenanceScannerTests) |
| integrity.codesign | `CodeSignInspector` — Apple-signed/team-signed/ad-hoc-or-unsigned via SecStaticCode APIs directly, no codesign/spctl subprocess. Ad-hoc detection bug (wrong flag bit, would have misclassified ad-hoc as team-signed) found and fixed while adding this phase's test matrix. | VERIFIED_COMPLETE | IntegrityCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/IntegrityCore/IntegrityCore.swift:117-157; Tests/IntegrityCoreTests/IntegrityCoreTests.swift (CodeSignInspectorTests) |
| integrity.loginitems | `LoginItemScanner` — LaunchAgents/LaunchDaemons from the standard locations, injectable `locations:` parameter added this phase so tests use isolated temp directories instead of the real ~/Library/LaunchAgents | VERIFIED_COMPLETE | IntegrityCore | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/IntegrityCore/IntegrityCore.swift:182-207; Tests/IntegrityCoreTests/IntegrityCoreTests.swift (LoginItemScannerTests) |

## SystemMetrics (1: VERIFIED_COMPLETE=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| perf.metrics | `MetricsCollector` — CPU via `host_statistics` tick deltas, memory via `host_statistics64` (active+wired+compressed, matches Activity Monitor's model), disk via volume resource keys, network throughput via `getifaddrs` cumulative-counter delta, thermal via `ProcessInfo.thermalState`. All real Mach/sysctl/BSD calls, nothing simulated. | VERIFIED_COMPLETE | Performance | Observe live metrics and login-agent inspection | performance | yes | live machine metrics without identity data | Sources/SystemMetrics/SystemMetrics.swift:1-142 |

## AppDiscovery (3: VERIFIED_COMPLETE=2, VERIFIED_PARTIAL=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| apps.discovery | `discoverApps()` enumerates `/Applications` + `~/Applications` (one nesting level for suites), reads `Info.plist`, real Spotlight `kMDItemLastUsedDate` (honestly `nil` if unindexed, never guessed), real `com.apple.quarantine` xattr check, Mach-O magic-number architecture detection (arm64/x86_64/universal/unknown) | VERIFIED_COMPLETE | Applications | Inventory, inspect associated data, review removal | applications | yes | installed apps; paths excluded from public media | Sources/AppDiscovery/AppDiscovery.swift:63-217 |
| apps.leftovers | `leftovers()` — reverse-DNS bundle-ID pattern match (`looksLikeBundleID`, ≥3 dot-separated parts) in Application Support/Caches/Saved Application State, excludes `com.apple.*`/`group.com.apple.*`, cross-references installed bundle IDs | VERIFIED_COMPLETE | Applications | Inventory, inspect associated data, review removal | applications | yes | installed apps; paths excluded from public media | Sources/AppDiscovery/AppDiscovery.swift:150-183 |
| apps.updates | `AppUpdatesView` calls `AppDiscovery().discoverApps()` and opens `macappstore://showUpdatesPage` via NSWorkspace — **this only opens the macOS App Store's Updates pane, it does not itself check for or list available updates from any source** | VERIFIED_PARTIAL | Applications | Inventory, inspect associated data, review removal | applications | yes | installed apps; paths excluded from public media | Sources/CoreTendApp/AppUpdatesView.swift:26,38-40 (deep-links to App Store, does not itself check updates) |

## MyClutter (3: VERIFIED_COMPLETE=3)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| clutter.largeold | `MyClutterView` instantiates a plain `ScanEngine()` (default config, all rules) for its Large & Old view | VERIFIED_COMPLETE | My Clutter | Choose Large & Old, Duplicates or Similar Images | my-clutter | yes | neutral temporary files | Sources/CoreTendApp/MyClutterView.swift; Tests/CoreTendAppTests/MyClutterSortTests.swift; visually verified 2026-07-31: launched real .app build, navigated to My Clutter > Large & Old, correct empty state with live Larger-than/Older-than pickers and Analyze button. |
| clutter.duplicates | `DuplicatesView` wires `DuplicateEngine` + `SafetyCenter`/dry-run for deletion | VERIFIED_COMPLETE | My Clutter | Choose Large & Old, Duplicates or Similar Images | my-clutter | yes | neutral temporary files | Sources/CoreTendApp/DuplicatesView.swift; Tests/CoreTendAppTests/DuplicatesFilterTests.swift; visually verified 2026-07-31: launched real .app build, navigated to My Clutter > Duplicates, correct empty state with accurate hard-link/staged-hashing explainer copy. |
| clutter.similarimages | `SimilarImagesView` wires `SimilarImagesEngine` | VERIFIED_COMPLETE | My Clutter | Choose Large & Old, Duplicates or Similar Images | my-clutter | yes | neutral temporary files | Sources/CoreTendApp/SimilarImagesView.swift; visually verified 2026-07-31: launched real .app build, navigated to My Clutter > Similar Images, correct empty state, honest Photos-library-never-touched copy matches SimilarImagesEngine behavior. |

## SpaceLens (1: VERIFIED_COMPLETE=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| spacelens.view | `SpaceLensView` wires `SpaceLensEngine(root:)`, presumably renders via `TreemapLayout` | VERIFIED_COMPLETE | Space Lens | Choose a folder and navigate the measured tree | space-lens | yes | neutral temporary folder tree | Sources/CoreTendApp/SpaceLensView.swift; Tests/CoreTendAppTests/SpaceLensNavigationTests.swift; visually verified 2026-07-31 in both light and dark: treemap/list dual view, zoom (matchedGeometryEffect), breadcrumb, search+category filter+per-item exclusions (added this session), Quick Look, keyboard nav (return/escape), accessibility labels, Reduce Motion gating all present and rendering correctly. |

## CloudCleanup (1: VERIFIED_PARTIAL=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| cloud.detect | `CloudCleanupViewModel.detect()`/`scan()` — bespoke scanner (not one of the shared 4 engines), enumerates iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs`) and other declared providers, classifies sync state from the real `ubiquitousItemDownloadingStatusKey` signal (placeholder/partial/local), never triggers a download itself | VERIFIED_PARTIAL | Cloud Cleanup | Detect providers and measure local footprint | cloud-cleanup | no | empty or neutral provider fixture | Sources/CoreTendApp/CloudCleanupView.swift:10-137 |

## Persistence (2: VERIFIED_COMPLETE=2)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| activity.log | `Store.recordActivity`/`activity(limit:kind:)`/`clearActivity()` — SQLite (`sqlite3` C API), WAL mode, actor-isolated, append-only migration list, migrations verified idempotent | VERIFIED_COMPLETE | My Activity | Filter, expand, export, clear with confirmation | my-activity | no | isolated temporary activity store | Sources/Persistence/Store.swift:1-165 |
| activity.grouping | Day-grouping / date-filter (`last7`/`last30`/`all`) logic in `MyActivityView` | VERIFIED_COMPLETE | My Activity | Filter, expand, export, clear with confirmation | my-activity | no | isolated temporary activity store | Sources/CoreTendApp/MyActivityView.swift:36-39 |

## Settings (8: VERIFIED_COMPLETE=8)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| settings.menubar | Settings: "Show CoreTend in the menu bar" toggle, backed by @AppStorage("menuBarEnabled") | VERIFIED_COMPLETE | Settings | Review permissions, exclusions, dry run and diagnostics | settings | no | isolated temporary store | Sources/CoreTendApp/SettingsView.swift:82,93 |
| settings.dryrundefault | Settings: "Dry run by default" toggle, persisted to Store via setSetting("dryRunDefault") | VERIFIED_COMPLETE | Settings | Review permissions, exclusions, dry run and diagnostics | settings | no | isolated temporary store | Sources/CoreTendApp/SettingsView.swift:102-103 |
| settings.appsignature | Settings: this copy's own code-signature status via CodeSignInspector (read-only) — shows whether the running binary itself is signed | VERIFIED_COMPLETE | Settings | Review permissions, exclusions, dry run and diagnostics | settings | no | isolated temporary store | Sources/CoreTendApp/SettingsView.swift:16, 114-118 |
| settings.fulldiskaccess | Settings: Full Disk Access status with "Open System Settings" / "Recheck" actions | VERIFIED_COMPLETE | Settings | Review permissions, exclusions, dry run and diagnostics | settings | no | isolated temporary store | Sources/CoreTendApp/SettingsView.swift:127-134 |
| settings.exclusions | Settings: exclusions list — add folder (NSOpenPanel) / remove, persisted to Store | VERIFIED_COMPLETE | Settings | Review permissions, exclusions, dry run and diagnostics | settings | no | isolated temporary store | Sources/CoreTendApp/SettingsView.swift:152-174 |
| settings.clearactivity | Settings: "Clear Activity History" destructive action with confirmation dialog | VERIFIED_COMPLETE | Settings | Review permissions, exclusions, dry run and diagnostics | settings | no | isolated temporary store | Sources/CoreTendApp/SettingsView.swift:181-184 |
| settings.exportdiagnostic | Settings: "Export Diagnostic Report" — opens DiagnosticReportView sheet (preview before save) | VERIFIED_COMPLETE | Settings | Review permissions, exclusions, dry run and diagnostics | settings | no | isolated temporary store | Sources/CoreTendApp/SettingsView.swift:188 |
| settings.migrationnotice | Settings: `MigrationNoticeRow` — shown only when the rename migration did something; states what moved, distinguishes failure from success, and explicitly says the old data is still on disk | VERIFIED_COMPLETE | Settings | Review permissions, exclusions, dry run and diagnostics | settings | no | isolated temporary store | Sources/CoreTendApp/SettingsView.swift:185-186, 229-265 |

## Data migration (2: VERIFIED_COMPLETE=2)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| migration.legacydata | `LegacyDataMigration` — one-time copy of pre-rebrand (MacCare Local) user data to the CoreTend identity. Copy-never-move (legacy directory never modified, renamed, or deleted), per-item and idempotent (existing destination items are skipped, never overwritten), temp-then-rename so an interrupted run resumes instead of leaving a truncated file that looks complete, hardcoded legacy directory names (`MacCareLocal`, `MacCare Local`) rather than heuristic matching, allowlisted preference keys only (`menuBarEnabled`, `onboardingDone`, `onboardingStep`) read from the old domain via `CFPreferencesCopyAppValue`, per-run JSON journal at `migration-log.json`, and `rollback(_:)` that removes only what that one run created | VERIFIED_COMPLETE | Data migration | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/Persistence/LegacyDataMigration.swift:50-317; Tests/PersistenceTests/LegacyDataMigrationTests.swift (20 tests, suite "Legacy data migration") |
| migration.launchwiring | Migration runs unconditionally in `AppEnvironment.init` before the store is opened — no "have we done this yet" flag that could drift from the filesystem; the report is retained only when it did something or failed | VERIFIED_COMPLETE | Data migration | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/CoreTendApp/AppEnvironment.swift:14-31 |

## Uninstall (1: VERIFIED_COMPLETE=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| uninstall.legacydata | Uninstaller `--include-legacy` opt-in additionally targets pre-rename data (`MacCareLocal`, `MacCare Local`, `local.maccare.app.plist`). Off by default — because the migration copies rather than moves, legacy data is a real backup and is not removed unless asked. Legacy paths are ordered last so an interrupted run never leaves the current install half-removed while the backup is already gone | VERIFIED_COMPLETE | Uninstall | Follow the documented feature path | none | no | neutral fixture where applicable | Scripts/uninstall.sh:29-30, 68-71, 107-109, 151-158; Scripts/test-uninstall.sh |

## Testing infrastructure (1: VERIFIED_COMPLETE=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| testing.storeisolation | `TestStoreOverride` — lets a distribution smoke test launch the real Release binary against a throwaway store instead of the user's data. Requires TWO agreeing environment variables (`CORETEND_TEST_MODE=1` and an absolute `CORETEND_TEST_STORE_DIR`), so one stray variable cannot relocate a real database; the path must standardize to a location under a real temporary root and is refused if empty, relative, a protected root, the home directory, the filesystem root, or a bare temp root. The marker also suppresses the legacy-data migration, so a smoke test can never read real pre-rename data. `Scripts/test-distribution.sh` fingerprints the real store before and after and fails on any change; `Scripts/check-test-isolation.sh` statically enforces the whole shape | VERIFIED_COMPLETE | Testing infrastructure | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/Persistence/TestStoreOverride.swift; Sources/Persistence/Store.swift (defaultPath/userPath/userDirectory); Sources/CoreTendApp/AppEnvironment.swift (migration suppression); Tests/PersistenceTests/TestStoreOverrideTests.swift (22 tests); Scripts/check-test-isolation.sh + Scripts/test-check-test-isolation.sh (9 self-tests) |

## Space Lens (1: VERIFIED_COMPLETE=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| spacelens.delete | Trash action per row, routed through SafetyCenter/PathValidator scoped to the originally-scanned root so a delete can never reach outside the browsed tree. Dry-run defaults true and reads the same app-wide dryRunDefault setting every other destructive module respects. Re-scans (rather than hand-patching the tree) after a real delete, restoring navigation depth by path. | VERIFIED_COMPLETE | Space Lens | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/CoreTendApp/SpaceLensView.swift (SpaceLensViewModel.requestDelete/confirmDelete); Tests/CoreTendAppTests/SpaceLensNavigationTests.swift |

## My Clutter / Space Lens (1: VERIFIED_COMPLETE=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| quicklook.extended | Interactive Quick Look panel, previously only on the Large & Old Files tab, extended to Duplicates, Similar Images, and Space Lens (files only, not directories). | VERIFIED_COMPLETE | My Clutter / Space Lens | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/CoreTendApp/DuplicatesView.swift, SimilarImagesView.swift, SpaceLensView.swift (previewURL + .quickLookPreview) |

## My Activity (1: VERIFIED_COMPLETE=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| activity.jsonexport | JSON export alongside the existing CSV export, same date-range-filtered scope, pretty-printed with sorted keys. | VERIFIED_COMPLETE | My Activity | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/CoreTendApp/MyActivityView.swift (exportJSON); Tests/CoreTendAppTests/MyActivityGroupingTests.swift |

## Localization (1: VERIFIED_COMPLETE=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| l10n.languagepicker | Runtime language override (System/English/Français), independent of the OS locale, applied immediately (via .id() on the window and menu-bar content keyed to the same @AppStorage value) and persisted. English resolves to the Base.lproj bundle (there is no en.lproj folder — this was caught by a test, not assumed). | VERIFIED_COMPLETE | Localization | Follow the documented feature path | none | no | neutral fixture where applicable | Sources/CoreTendApp/L10n.swift (LocalizationManager); SettingsView.swift, OnboardingView.swift pickers; Tests/CoreTendAppTests/LocalizationManagerTests.swift |

## FavoritesRecents (1: VERIFIED_COMPLETE=1)

| id | Name / objective | State | Screen | Demonstration path | Capture | Animation | Demo data | Validation evidence |
|---|---|---|---|---|---|---|---|---|
| favrec.module | Favorites & Recents sidebar module: pin/unpin folders, auto-recorded recent scan locations (path + last measured size), Downloads/Desktop/Documents always shown as Quick Links independent of favorite status, missing/unreadable folders flagged inline, Analyze jumps into Space Lens via a new .mcOpenSpaceLensAt notification which also records the visit on scan completion. | VERIFIED_COMPLETE | Favorites & Recents | Pin a folder, revisit a recent scan, jump into Space Lens | favorites-recents | no | isolated temporary store | Sources/CoreTendApp/FavoritesRecentsView.swift; Sources/Persistence/Store.swift:194-247 (locations table, schema v3); Tests/PersistenceTests/StoreTests.swift (favorites/recents CRUD); Tests/CoreTendAppTests/FavoritesRecentsTests.swift; visually verified 2026-07-31 in both light and dark: launched real .app build (Scripts/package-local.sh) under an isolated CORETEND_TEST_STORE_DIR, navigated via Cmd+K, confirmed Quick Links (Downloads/Desktop/Documents) render with real paths and correct empty states for Favorites/Recents. |

