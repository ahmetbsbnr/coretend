# Coretend Project Audit

**Audit date:** 31 July 2026  
**Repository revision:** `38b8dda` on `main`  
**Purpose:** evidence base for `Coretend_Apple_Support_Proposal.md`  
**Method:** source, package configuration, resources, tests, scripts, documentation and available Git history were inspected. Build and capture work used the existing macOS environment without distribution signing, publication or a personal account.

## 1. Evidence policy

The proposal uses the following order of confidence:

1. current executable source and package configuration;
2. current automated-test execution and direct application capture;
3. current tests and scripts as evidence of intended behaviour;
4. current configuration and structured project-state files;
5. documentation, checked against source because several documents are stale;
6. Git history for chronology;
7. developer-provided biographical, AI-experience and hardware-workflow information, clearly separated from repository evidence.

“Present in source” does not automatically mean “validated on every supported Mac”. “Partially developed” means that a useful implementation exists but the described journey has an explicit limit. “Planned” is reserved for a recorded work item. “Idea” means a possible future experiment and is not a product commitment.

### Snapshot and pre-existing worktree state

The repository had 349 commits at the audited revision. The following unrelated changes already existed and were preserved:

| State | Path | Audit interpretation |
|---|---|---|
| Modified | `Sources/ScanCore/ScanCore.swift` | Adds engine-level hooks for a pause controller. |
| Untracked | `Sources/ScanCore/ScanPauseController.swift` | Source-level pause/resume prototype. |
| Untracked | `Tests/ScanCoreTests/ScanPauseControllerTests.swift` | Three prototype tests. |

No user code was reverted or rewritten for the proposal. The pause/resume work is classified as **in progress**, because no application UI wiring was found.

## 2. Real purpose, problem and audience

| Finding | Status | Evidence |
|---|---|---|
| Coretend is a native macOS maintenance and observation project centred on local storage analysis, cautious cleanup and system visibility. | Present | `PRODUCT.md:7-21`; `README.md:16-19`; executable views under `Sources/CoreTendApp/`. |
| The problem addressed is opaque, risky maintenance: the code exposes findings for review, defaults to dry-run and uses the macOS Trash for approved actions. | Present | `Sources/CoreTendApp/CleanupView.swift:84-155`; `Sources/SafetyCore/SafetyCore.swift:164-233`. |
| The directly supported audience is an individual Mac user; selected cleanup rules also address Xcode artefacts used by developers. | Present | `Sources/FileRules/UserCleanupRules.swift:43-53,70-80,130-142`; no account, organisation or multi-user subsystem was found in `Sources/`. |
| Coretend is a local application, with no account system or hosted application backend in the current source. | Present | `Package.swift`; `Sources/`; local store in `Sources/Persistence/Store.swift:106-135`. |

The project is **not** described in the proposal as finished, commercially ready, published on the App Store or used by customers. The repository contains earlier release-candidate artefacts, but the current tree continues to change beyond those checkpoints.

## 3. Package and platform architecture

`Package.swift:1-44` is the authoritative package definition.

| Area | Verified implementation | Evidence |
|---|---|---|
| Language and toolchain | Swift, `swift-tools-version: 6.0` | `Package.swift:1` |
| Platform | macOS 14 or later | `Package.swift:7`; `Resources/Info.plist:21-24` |
| Build system | Swift Package Manager; no `.xcodeproj` or `.xcworkspace` is present | `Package.swift`; repository file inventory |
| Product | One executable, `CoreTend` | `Package.swift:8-9` |
| Internal libraries | `ScanCore`, `SafetyCore`, `FileRules`, `DesignSystem`, `Persistence`, `SystemMetrics`, `AppDiscovery`, `IntegrityCore` | `Package.swift:10-18` |
| Primary dependency graph | `CoreTendApp` depends on all internal modules; `ScanCore → SafetyCore`; `FileRules → ScanCore + SafetyCore`; `Persistence → SafetyCore` | `Package.swift:23-40` |
| Interface architecture | SwiftUI `NavigationSplitView`, main-actor observable view models and AppKit bridges | `Sources/CoreTendApp/CoreTendApp.swift:315-391`; `Sources/CoreTendApp/ApplicationsView.swift`; `Sources/CoreTendApp/MyActivityView.swift` |
| Persistence | Direct SQLite3 persistence owned by the `Store` actor, WAL mode and three transactional schema migrations | `Sources/Persistence/Database.swift:14-29`; `Sources/Persistence/Store.swift:46-104,137-163` |
| Core Data / SwiftData | Not used | no import or model use in `Sources/`; direct SQLite implementation above |

### Internal components

| Component | Responsibility | Concrete source |
|---|---|---|
| `CoreTendApp` | App lifecycle, navigation, onboarding, menu-bar surface, command palette, view models and user journeys | `Sources/CoreTendApp/` |
| `ScanCore` | File enumeration, scan results, duplicate hashing, similar-image grouping, Space Lens tree and cloud-file metadata | `Sources/ScanCore/` |
| `FileRules` | User-cleanup rule definitions | `Sources/FileRules/UserCleanupRules.swift` |
| `SafetyCore` | Path validation, approval, last-moment revalidation, dry-run, move to Trash and audit emission | `Sources/SafetyCore/SafetyCore.swift:31-90,138-233` |
| `Persistence` | Activities, settings, exclusions, safety records, favourites/recents and legacy migration | `Sources/Persistence/Store.swift`; `Sources/Persistence/LegacyDataMigration.swift` |
| `AppDiscovery` | Application inventory, metadata, associated data, leftovers and update-mechanism detection | `Sources/AppDiscovery/AppDiscovery.swift` |
| `SystemMetrics` | CPU, memory, pressure, disk, thermal, network and uptime signals | `Sources/SystemMetrics/SystemMetrics.swift` |
| `IntegrityCore` | Download provenance, code-signature inspection and launch-agent inventory | `Sources/IntegrityCore/IntegrityCore.swift` |
| `DesignSystem` | Semantic colour, typography, motion, accessibility state and reusable SwiftUI components | `Sources/DesignSystem/`; current palette in `Sources/DesignSystem/Colors.swift:1-142` |

### Reviewed destructive-action flow

```text
SwiftUI screen / view model
  → ScanRule and ScanEngine, or a specialised analysis engine
  → AsyncStream results and progress
  → explicit user review or confirmation
  → SafetyCenter approval and immediate revalidation
  → dry-run event, or FileManager.trashItem
  → the view model records activity through AppEnvironment
  → SafetyCenter separately emits a redacted safety event to Store
```

Evidence: `Sources/ScanCore/ScanCore.swift:115-177`; `Sources/CoreTendApp/CleanupView.swift:84-155`; `Sources/CoreTendApp/AppEnvironment.swift`; `Sources/SafetyCore/SafetyCore.swift:178-233`; `Sources/Persistence/Store.swift:334-357`. Read-only analyses such as Cloud Cleanup, Similar Images, Performance and Integrity stop before `SafetyCore`.

## 4. Apple frameworks and external dependencies

| Technology | Verified use | Evidence |
|---|---|---|
| SwiftUI | Main interface and app lifecycle | `Sources/CoreTendApp/CoreTendApp.swift`; view files in `Sources/CoreTendApp/` |
| AppKit | Workspace actions, file/save panels, app integration and macOS-specific bridges | imports/usages in `Sources/CoreTendApp/` |
| Foundation | Filesystem, concurrency, process/system information, dates and core models | all internal modules |
| CryptoKit | Partial and full SHA-256 duplicate hashing | `Sources/ScanCore/DuplicateEngine.swift:1-2,53-170` |
| Vision + ImageIO | Local image feature prints and resolution inspection | `Sources/ScanCore/SimilarImagesEngine.swift:1-4,32-114` |
| Quick Look / QuickLookThumbnailing | Previews and thumbnails | My Clutter, Duplicates, Similar Images and Space Lens views under `Sources/CoreTendApp/` |
| Security | Native code-signature inspection | `Sources/IntegrityCore/IntegrityCore.swift:11-12,117-159` |
| CoreServices / Spotlight | Application metadata and discovery signals | `Sources/AppDiscovery/AppDiscovery.swift:1-2,93-180` |
| Darwin / Mach | CPU, memory and system signals | `Sources/SystemMetrics/SystemMetrics.swift:1-2,47-140` |
| UserNotifications | Permission request in onboarding | `Sources/CoreTendApp/OnboardingView.swift:71-84` |

The only declared external SwiftPM package is Apple’s `swift-testing`, limited to test targets (`Package.swift:19-21,32-44`). `Package.resolved` pins `swift-testing` 0.99.0 and its `swift-syntax` 600.0.1 transitive dependency. No third-party runtime package is declared.

## 5. Screens and journeys available in source

The sidebar has eleven destinations (`Sources/CoreTendApp/CoreTendApp.swift:247-312,344-369`): Smart Care, Cleanup, Protection/Integrity, Performance, Applications, My Clutter, Space Lens, Cloud Cleanup, My Activity, Favorites & Recents, and Settings. The application also contains a menu-bar extra, a `Command-K` command palette and a seven-step first-run flow (`CoreTendApp.swift:25-44,145-212,404-498`; `OnboardingView.swift:177-220`).

| Journey | Current behaviour | Status | Evidence |
|---|---|---|---|
| Cleanup | Runs ten local cleanup rules; groups results for review; supports dry-run or reviewed move to Trash; records activity | Present | `Sources/FileRules/UserCleanupRules.swift:7-148`; `Sources/CoreTendApp/CleanupView.swift:84-155,209-305` |
| Smart Care | Orchestrates Cleanup and selects low-risk results | Partial | `Sources/CoreTendApp/SmartCareView.swift:63-150`; Performance and Applications are explicitly unavailable there at `:8-10,51-58` |
| Exact duplicates | Size staging, partial hash, full SHA-256, hard-link collapse, keeper suggestion and revalidation before Trash | Present | `Sources/ScanCore/DuplicateEngine.swift:53-170`; `Sources/CoreTendApp/DuplicatesView.swift:63-137` |
| Similar images | Apple Vision feature prints, grouping, best-resolution suggestion, thumbnails and Quick Look | Analysis only | `Sources/ScanCore/SimilarImagesEngine.swift:32-114`; `Sources/CoreTendApp/SimilarImagesView.swift:43-109,145-207`; no removal flow is wired |
| Large and old files | Read-only scanning, thresholds, search, sort, Quick Look and Finder access | Present | `Sources/CoreTendApp/MyClutterView.swift:9-11,64-105,137-275` |
| Space Lens | Size tree and treemap, navigation, search, filters, Quick Look and confirmed move to Trash | Present, with integration gaps | `Sources/ScanCore/SpaceLensEngine.swift:38-150`; `Sources/CoreTendApp/SpaceLensView.swift:37-136,223-478` |
| Applications | Inventories standard application folders, shows metadata and associated data, and supports reviewed move-to-Trash uninstall | Present | `Sources/AppDiscovery/AppDiscovery.swift:93-180`; `Sources/CoreTendApp/ApplicationsView.swift:146-196,214-383` |
| Leftovers | Conservative bundle-identifier heuristic, no default selection and user review | Present | `Sources/AppDiscovery/AppDiscovery.swift:182-208`; `Sources/CoreTendApp/LeftoversView.swift:22-78` |
| App Updates | Classifies App Store, Homebrew Cask and Sparkle mechanisms; manual and unknown cases collapse into “In-app / manual”. App Store and Sparkle destinations are opened, while Homebrew and unknown apps are revealed in Finder. | Partial | `Sources/AppDiscovery/AppDiscovery.swift:211-260`; `Sources/CoreTendApp/ApplicationsView.swift:25-32`; `Sources/CoreTendApp/AppUpdatesView.swift:37-48`; it does not compare available versions |
| Integrity | Read-only download provenance, Security-framework signature signal and launch-agent/daemon inventory | Present | `Sources/IntegrityCore/IntegrityCore.swift:43-85,117-159,185-215`; `Sources/CoreTendApp/ProtectionView.swift:39-181` |
| Privacy Cleaner | Detects Safari, Firefox and Chromium-family browsers; measures several data categories; only caches can move to Trash and only when the browser is closed | Partial | `Sources/CoreTendApp/BrowserDetection.swift:3-16,38-110`; `Sources/CoreTendApp/PrivacyCleanerView.swift:7-10,65-92` |
| Performance | Displays CPU, memory, pressure, storage, thermal state, uptime and user LaunchAgent information. `SystemMetrics` also collects network throughput, which the current screen does not render. | Present | `Sources/SystemMetrics/SystemMetrics.swift:33-69`; `Sources/CoreTendApp/PerformanceView.swift:32-62,69-127` |
| Cloud Cleanup | Inspects local/partial/placeholder state for iCloud Drive, Dropbox, Google Drive and OneDrive; does not download or delete | Analysis only | `Sources/CoreTendApp/CloudCleanupView.swift:5-8,67-148,196-233` |
| Activity and diagnostics | Local real/simulated activity distinction, CSV/JSON export, redacted safety log, favourites/recents and diagnostics export | Present | `Sources/CoreTendApp/MyActivityView.swift:44-61,87-137,267-282`; `SafetyLogView.swift:6-39`; `FavoritesRecentsView.swift:72-106`; `DiagnosticReport.swift:7-18,67-145` |
| English and French | Runtime system/English/French selection with matching resource-key sets | Present | `Sources/CoreTendApp/L10n.swift:3-55`; `Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings`; `fr.lproj/Localizable.strings` |

“Protection” in older documentation is not presented as antivirus. Commit `eac408c` retired the former ClamAV direction and introduced native, read-only Integrity signals.

## 6. Data management, privacy and safety

| Claim | Evidence |
|---|---|
| The normal database path is the application’s local Application Support directory. | `Sources/Persistence/Store.swift:106-135` |
| SQLite uses WAL mode. | `Sources/Persistence/Database.swift:21-27` |
| Activities, settings, exclusions, safety log and favourites/recents have local tables/migrations. | `Sources/Persistence/Store.swift:50-104,137-163` |
| Persisted safety paths are redacted before insertion. | `Sources/Persistence/Store.swift:334-357` |
| The safety layer defaults to dry-run and only exposes `moveToTrash` as its destructive operation. | `Sources/SafetyCore/SafetyCore.swift:138-176` |
| Paths are validated at approval and revalidated immediately before execution. | `Sources/SafetyCore/SafetyCore.swift:178-233` |
| A legacy-data migration copies without moving or overwriting old data and records the outcome. | `Sources/Persistence/LegacyDataMigration.swift:25-50,142-229,275-315` |
| The package has no account or analytics SDK dependency. | `Package.swift`; import audit under `Sources/` |
| An optional manual update check may read an HTTPS manifest, but the checker does not download or install an app update. | `Sources/CoreTendApp/UpdateChecker.swift:3-19`; `Sources/CoreTendApp/UpdatesView.swift` |

The application is not currently sandboxed: `Configuration/CoreTend.entitlements` contains no active entitlement keys. Local packaging uses an ad-hoc signature (`Scripts/package-local.sh:19-42`). This is an honest development-state boundary, not evidence of Developer ID signing or notarisation.

## 7. Partial implementation and engineering risks

These points are material because several interface controls exist ahead of complete cross-module wiring:

| Limitation | Evidence and classification |
|---|---|
| Smart Care’s progress fraction always returns `nil`. | `Sources/CoreTendApp/SmartCareView.swift:184-188`; partial implementation |
| Global exclusions are loaded by Cleanup and Smart Care, but specialised clutter and Space Lens engines do not all consume them despite offering exclusion controls. | `CleanupView.swift:92-95`; `SmartCareView.swift:88-90`; contrast `MyClutterView.swift:64-85`, `DuplicatesView.swift:63-70`, `SimilarImagesView.swift:43-52`, `SpaceLensView.swift:37-44,451-456`; integration work remaining |
| The global dry-run setting is loaded by Cleanup, Smart Care and Space Lens; several other destructive screens initialise safely to `true` without propagating a Settings opt-out. | `CleanupView.swift`; `SmartCareView.swift`; `SpaceLensView.swift`; contrast initial state in `ApplicationsView.swift:125-146`, `LeftoversView.swift:12-16`, `DuplicatesView.swift:20-34`, `PrivacyCleanerView.swift:16-20` |
| No internal restore operation is implemented; recovery relies on the macOS Trash. | `Sources/SafetyCore/SafetyCore.swift:138-141`; the `restore` activity enum/UI is preparatory in `Sources/Persistence/Store.swift:20-24` and `MyActivityView.swift:298-305` |
| `followSymlinks` exists in configuration, but the current engine always skips symbolic links. | `Sources/ScanCore/ScanCore.swift:77-99,214-217` |
| Onboarding folder choices are held in view-model state but are not persisted or applied to scans. | `Sources/CoreTendApp/OnboardingView.swift:43-45,86-93,130-141` |
| Recommended and Cautious onboarding profiles currently resolve to the same configuration. | `Sources/CoreTendApp/OnboardingLogic.swift:28-39` |
| Notification permission may be requested, but no notification scheduling implementation was found. | `Sources/CoreTendApp/OnboardingView.swift:71-84`; repository-wide source search |
| Automatic update checking is stored as a setting, but only a manual button call was found. | `Sources/CoreTendApp/UpdatesView.swift:19-36,79-82`; no launch trigger in `CoreTendApp.swift:25-44` |
| Several scan and display paths have explicit caps, and Vision grouping has nested comparison work. | `CleanupView.swift:101-106`; `SmartCareView.swift:92-99`; `MyClutterView.swift:88-93`; `DuplicatesView.swift:76-84`; `SimilarImagesEngine.swift:37-42,80-99` |
| Environment setup uses `try?` and can fall back to an in-memory store, so some persistence failures may be silent. | `Sources/CoreTendApp/AppEnvironment.swift:16-21,50-60` |

Clean-machine launch on another physical Mac, broad macOS-version testing, complete crash/stress coverage, a full VoiceOver pass, Developer ID signing and notarisation remain outside what this audit can claim as complete. Relevant records include `Documentation/KNOWN_LIMITATIONS.md:135-141`, `Documentation/COMPATIBILITY.md:12-17`, `TODO.md` and `Documentation/SIGNING_NOTARIZATION.md`.

## 8. Tests and automation

| Evidence | Verified fact |
|---|---|
| `Package.swift:32-44` | Nine test targets cover all eight internal libraries and the app module. |
| Current inspected worktree | 311 `@Test` and 62 `@Suite` declarations were counted. Three tests and one suite belong to the untracked pause/resume prototype. Tracked HEAD contains 308 test declarations and 61 suites. These are declaration counts, not pass results. |
| `Scripts/test*.sh` | Sixteen test scripts cover Swift tests and broader packaging, release, provenance, robustness, DMG, customer-journey, isolation and visual gates. |
| `.github/workflows/ci.yml:16-141` | CI is configured for build, tests, packaging, rapid robustness, headless DMG, visual regression and private-data checks. |
| `.github/workflows/compat-matrix.yml:1-10` | The macOS 14/15 matrix explicitly labels itself `IMPLEMENTED_UNVERIFIED`; it is not counted as physical validation. |

### Direct execution during proposal preparation

<!-- BUILD_RESULTS_START -->
- **Debug build:** `swift build --scratch-path /tmp/coretend-apple-support-build-20260731` completed successfully in 173.34 seconds, exit 0.
- **Local Release bundle:** `CORETEND_SCRATCH_PATH=/tmp/coretend-apple-support-release-build-20260731 bash Scripts/package-local.sh` completed successfully; its Release build reported 34.89 seconds, then created `build/CoreTend.app` with an ad-hoc signature, exit 0. This is not Developer ID signing, notarisation or distribution signing.
- **Full test command:** `bash Scripts/test.sh --scratch-path /tmp/coretend-apple-support-build-20260731` compiled and entered the serial Swift Testing run. The last visible transition was the start of `unwritableDestinationIsReportedNotSwallowed()` in `Tests/PersistenceTests/LegacyDataMigrationTests.swift:297`. The runner and helper then remained sleeping at zero CPU with no output for more than 30 minutes. It was interrupted, exit 130. The result is **inconclusive**: no full-suite pass or failure count is claimed.
- **Toolchain used:** active Command Line Tools, arm64, macOS 26.5.1. Final environment inspection reported Apple Swift 6.3.3. The package itself requires Swift tools 6.0 and macOS 14 or later.
- **Application execution:** the bare SwiftPM Debug executable rendered Smart Care, Cleanup and Space Lens, but opening Settings raised a `UNUserNotificationCenter` `bundleProxyForCurrentProcess is nil` exception because that binary was not running inside an application bundle. The packaged Release `.app` opened Settings successfully. This capture-specific issue did not require a source change.
<!-- BUILD_RESULTS_END -->

Previously documented figures such as 296 tests / 58 suites or structured-state counts are older or inconsistent and are not used as current execution results.

## 9. Version and Git-history evidence

| Revision | Date | Verifiable significance |
|---|---|---|
| `7bf18bb` | 19 Jul 2026 | Foundation commit with SafetyCore, ScanCore, FileRules, app shell and Cleanup module |
| `a6aa3bf` / tag `v0.9.0` | 27 Jul 2026 | `v0.9.0` tagged checkpoint |
| `119d940` / tag `v0.9.1-rc.3` | 29 Jul 2026 | Release-candidate notes checkpoint |
| `eac408c` | 29 Jul 2026 | Replaced ClamAV direction with native Integrity signals |
| `523ef1e` | 30 Jul 2026 | Runtime system/English/French selector |
| `f1a5337` | 30 Jul 2026 | Command palette |
| `f9803d2` and `9ca3a89` | 30 Jul 2026 | Space Lens Trash action, search, filters and exclusion controls |
| `fc46f49` | 30 Jul 2026 | Paper/Ink/Cobalt interface direction |
| `273655d` | 31 Jul 2026 | Favorites & Recents module |
| `38b8dda` | 31 Jul 2026 | Audited HEAD; 26 commits after `v0.9.1-rc.3` |

The bundle reports `0.9.1-rc.3` (`Resources/Info.plist:17-20`). This is treated as a development version only. The approved proposal wording is:

> Coretend is an actively developed macOS project. The current source tree continues to evolve beyond earlier tagged release-candidate checkpoints and is not presented here as a finished commercial or App Store product.

## 10. Documentation drift

Current source takes precedence over these conflicts:

| Drift | Evidence |
|---|---|
| README still labels the project 0.9.0 while bundle/current state is 0.9.1-rc.3. | `README.md:10,29,68`; `Resources/Info.plist:17-20`; `Documentation/PROJECT_STATE.json:2-5` |
| Files named `CURRENT_*` still describe 0.8.1. | `Documentation/CURRENT_PROJECT_STATE.json:1-8`; `CURRENT_AUDIT_STATE.json:1-8` |
| Test totals differ across README, test inventory and structured state. | `README.md:114-117`; `Documentation/TEST_INVENTORY.md:3-9`; `Documentation/PROJECT_STATE.json:52-55`; current declaration audit |
| Feature inventory summary fields are internally stale and list fewer Cleanup rules than current source. | `Documentation/FEATURE_INVENTORY.md:5`; `Documentation/feature-inventory.json:6-10,384`; `Sources/FileRules/UserCleanupRules.swift:7-148` |
| Several architectural documents still refer to ClamAV/MalwareEngine or modules as planned. | `Documentation/FEATURE_MATRIX.md`; `ROADMAP.md`; `ARCHITECTURE_OVERVIEW.md`; `ARCHITECTURE.md:20-22`; contrast current `Package.swift` and `IntegrityCore` |
| Space Lens documentation predates its reviewed Trash action. | `Documentation/SPACE_LENS.md:19-23`; commits `f9803d2`, `9ca3a89`; current `SpaceLensView.swift` |
| Older design documents describe the prior Living System direction. | `PRODUCT.md`; `DESIGN.md`; contrast commit `fc46f49` and `Sources/DesignSystem/Colors.swift` |

Documentation synchronisation is therefore presented as a current work item, not concealed by selecting only favourable files.

## 11. AI-experience boundary

No MLX, Ollama, LM Studio, Qwen, Claude, Codex, OpenCode, AirLLM, vLLM, Core ML or LLM feature is implemented in `Sources/` or declared in `Package.swift`. Apple Vision is used only for image-similarity feature prints (`Sources/ScanCore/SimilarImagesEngine.swift:2,63-110`).

The proposal’s AI section is based on the developer’s supplied experience and is intentionally separate from Coretend’s current feature set:

- MLX, Ollama, LM Studio and Qwen-family local-model experimentation;
- Claude, Codex and OpenCode as development and analysis assistants, with human responsibility and verification;
- AirLLM as memory-conscious inference/runtime study in compatible environments;
- vLLM studied or tested in compatible Linux/GPU environments, with no claim of native operation on the M1 Mac;
- learning goals covering inference, quantisation, memory needs, context windows, application integration, runtime differences and Apple silicon optimisation.

Future local-AI functions are labelled **ideas to evaluate**, not implemented or promised Coretend features.

## 12. Hardware boundary

The MacBook Air, Apple M1 and 8 GB unified-memory facts were supplied by the developer and locally confirmed using macOS system information. The four-year use history and workflow effects are developer-provided observations, not repository claims.

The proposal deliberately makes no per-process memory allocation, token-per-second result, model-size threshold or benchmark claim. The memory diagram is qualitative. It only explains that macOS, development tools, a browser, local services, model weights and context share the 8 GB pool, reducing simultaneous-workload headroom and increasing the likelihood of compression and swap.

## 13. Screenshot provenance

<!-- SCREENSHOT_RESULTS_START -->
Four current-branch application captures were accepted. All are 2024 × 1488 PNG files and were visually inspected at original resolution:

| File | Screen | Why it is safe and representative |
|---|---|---|
| `screenshots/01-smart-care.png` | Smart Care idle state | Current combined-care entry point; it visibly distinguishes available Cleanup from unavailable categories. No scan or user data is shown. |
| `screenshots/02-cleanup.png` | Cleanup idle state | Shows the central scan entry point and its “nothing is deleted during a scan” boundary. No scan was started. |
| `screenshots/04-space-lens.png` | Space Lens idle state | Shows the analysis entry point and explicitly states that nothing is modified. No folder was selected. |
| `screenshots/05-settings.png` | Settings | Shows language, menu-bar, dry-run, Trash, local-signature and helper development state. The isolated store contained no exclusions or personal paths. |

For accepted bundle captures, Coretend was launched with both `CORETEND_TEST_MODE=1` and a fresh temporary `CORETEND_TEST_STORE_DIR`. This uses the repository’s guarded test-store override (`Sources/Persistence/TestStoreOverride.swift`) and suppresses legacy migration; no personal Coretend database was read or written. No cleanup, deletion, application uninstall, file selection or account action was performed. Generated temporary stores and scratch-build directories were removed after capture.

Integrity was deliberately not captured because its view task automatically reads real Downloads provenance and login items (`Sources/CoreTendApp/ProtectionView.swift`). Performance was deliberately not captured because it displays live system values and real user LaunchAgent information without a fixture hook. These omissions prevent real machine data from appearing in the presentation. `SCREENSHOTS_NEEDED.md` is therefore unnecessary: the application executed successfully and four safe, current captures satisfy the requested range.
<!-- SCREENSHOT_RESULTS_END -->

Older media under `Documentation/VisualAudit/After/` and `Website/assets/app/` was excluded because it predates current naming, Integrity and the Paper/Ink/Cobalt direction; one older menu-bar image also contains real machine metrics. Brand assets in `Resources/Brand/Generated/` are repository-generated and documented by `Documentation/ASSET_PIPELINE.md:3-24` and `Documentation/ASSET_PROVENANCE.md:6-18`.

## 14. Sensitive material excluded

- Local signing material under the ignored `Configuration/DeveloperID/` directory was not opened, copied or cited.
- `Configuration/PublicIdentity.local.json`, when present, remains ignored and excluded.
- A tracked graph export manifest contains local absolute paths; those values are not reproduced. The existing private-data check currently flags that file.
- Git history records that an older personal absolute path was fixed in commit `57332d0`; the value is not repeated.
- No secret, token, signing identifier, private address, account credential or personal filesystem path is included in the proposal or its assets.

## 15. Claims intentionally excluded

The evidence does not support, so the proposal does not claim:

- a finished or commercially ready product;
- App Store publication, Developer ID signing or notarisation;
- any user, customer, download, revenue or conversion count;
- measured performance, cleanup savings, scan speed, AI throughput or memory allocation;
- antivirus or malware-removal capability;
- automatic application-version comparison or update installation;
- full cloud cleanup, cloud deletion or cloud download;
- current deletion of similar images;
- browser-history, cookie or session removal;
- internal restoration beyond recovery from the macOS Trash;
- an MLX, Qwen or other LLM feature inside Coretend;
- autonomous authorship by development assistants;
- validation on every supported Mac or macOS version;
- endorsement, affiliation, partnership or material commitment from Apple.

## 16. Proposal assets and reproducibility

| Asset | Purpose |
|---|---|
| `Coretend_Apple_Support_Proposal.md` | Authoritative content source |
| `assets/proposal.css` | Local A4 print styling using system fonts |
| `generate_proposal.py` | Deterministic local Markdown-to-HTML renderer |
| `render_proposal.mjs` | Local Chromium A4 PDF export with page-count, overflow and broken-image checks |
| `assets/architecture.svg` | Architecture diagram based on current package/source boundaries |
| `assets/memory-pressure.svg` | Qualitative, non-benchmark memory-pressure illustration |
| `assets/coretend-mark.svg` | Current Coretend mark adapted from the repository-generated brand asset |
| `screenshots/` | Inspected current-branch application captures |

Regeneration commands, from the repository root:

```sh
python3 docs/apple-support/generate_proposal.py
node docs/apple-support/render_proposal.mjs
pdfinfo docs/apple-support/Ahmet_Basbunar_Coretend_Apple_Support_Proposal.pdf
pdftotext docs/apple-support/Ahmet_Basbunar_Coretend_Apple_Support_Proposal.pdf -
```

The HTML contains no remote stylesheet, script, font or image dependency. Public URLs appear only as clickable links.

## 17. Final document quality control

The final PDF was regenerated from the Markdown source and inspected on 31 July 2026.

- Chromium's pre-export checks reported **11 pages**, no page-container overflow and no broken local image.
- `pdfinfo` confirmed A4 pages (594.96 × 841.92 points), no encryption, no embedded JavaScript and an 11-page document.
- `pdffonts` confirmed that every listed font subset is embedded; the document uses the macOS system typeface plus embedded Courier for short code labels.
- `pdfinfo -url` confirmed clickable annotations for the portfolio, Coretend website, GitHub profile, LinkedIn profile and direct Coretend repository.
- All 11 pages were rasterised at 120 dpi and visually inspected. No clipped text, overlap or unintended blank page was found. Page numbers appear on pages 2–11 and are deliberately omitted from the cover.
- The Executive Summary page contains 249 extracted words including its heading, fact labels, footer and page number, keeping the summary itself below the requested 250-word limit.
- The four application screenshots remain sharp at print size and expose no selected personal folder, file result, account, private path or live system metric.
- Text extraction was reviewed for unresolved placeholders. No “Screenshot to be added” marker remains.
- QR codes were deliberately omitted because they were optional; the verified clickable URLs provide the primary navigation path without adding an untested visual dependency.

Supporting documentation regarding the developer's student status, including the completed CVEC administrative step, can be provided upon request. A broader test run remains to be completed because the audit run stopped producing output during `LegacyDataMigrationTests`; this report treats that run as inconclusive rather than as a pass or failure.
