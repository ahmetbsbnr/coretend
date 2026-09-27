# Architecture — current worktree

Reviewed against Package.swift and Sources on 2026-09-27. This is a maintained
source map, not a generated diagram or a claim about published binaries.

## System and module boundaries

Swift 6 / SwiftPM, macOS 14+. Two executable targets: CoreTend (small entry point
calling CoreTendApp) and coretend-cli. CoreTendApp is a library target, not the
executable itself. Swift Testing and Swift Syntax are build/test dependencies;
there is no third-party runtime service. Existing untracked Xcode files are
local user work; SwiftPM and Scripts remain the tracked build workflow.

| Module | Entry/interface and responsibility | Dependencies / data ownership | Tests and current limits |
|---|---|---|---|
| CoreTendApp | CoreTendApp.swift lifecycle, ModuleID routing, MainActor observable models and SwiftUI views | All eight libraries; selection/scan/UI state; AppEnvironment owns Store | App, integration, accessibility contracts; native UI target is XCTest and excluded by test.sh |
| DesignSystem | MCTheme, components, typography, motion/accessibility primitives | Native UI; no persistence | DesignSystemTests; visual acceptance requires captures |
| ScanCore | ScanEngine, DuplicateEngine, SimilarImagesEngine, SpaceLensEngine; AsyncStream results and ScanPauseController | SafetyCore types; read-only filesystem scan state | ScanCoreTests and performance fixtures; cancellation, cloud placeholders, duplicates |
| FileRules | UserCleanupRules rules and allowedRoots | ScanCore + SafetyCore; declarative cleanup scope | FileRulesTests; no broad home-directory cleanup |
| SafetyCore | PathValidator, ApprovedFileOperation, SafetyCenter.execute, SafetyAuditSink | No package dependencies; sole cleanup mutation boundary | SafetyCoreTests; filesystem races remain possible between validation and OS operation |
| Persistence | Store actor, Database wrapper, LegacyDataMigration, TestStoreOverride | SafetyCore audit contract; SQLite WAL and four ordered migrations | PersistenceTests; app still permits unavailable/volatile store |
| AppDiscovery | discoverApps, associatedItems, leftovers, updateMechanism | Native bundle/filesystem metadata, no database | AppDiscoveryTests; external app updates are handoffs, not an updater |
| IntegrityCore | ProvenanceScanner, CodeSignInspector, LoginItemScanner | Native metadata/signatures; read-only | IntegrityCoreTests; not malware detection |
| SystemMetrics | MetricsCollector.snapshot | OS CPU/memory counters | SystemMetricsTests; sampling, not an optimization engine |
| CoreTendCLI | --help, --list-rules, --paths | FileRules | Read-only; destructive CLI deliberately out of scope |
| Website | build.py renders static EN/FR site | published-release.json + reviewed identity; no backend/database | Python/shell contracts, Playwright/Axe/visual scripts; runtime browser checks separate |

## Data and action flow

CleanupView configures rules/exclusions → ScanEngine streams findings → user
selects and explicitly confirms → SafetyCenter.approve returns opaque operation
→ execute revalidates the path → macOS Trash → ExecutionOutcome and activity.
Applications, Leftovers, PrivacyCleaner, Duplicates and SpaceLens use the same
SafetyCenter boundary. A failed Trash move must preserve the source and emit an
error, never fall back to permanent deletion. Tests inject a fixture mover through
an internal initializer; the public initializer uses macOS Trash directly.

SafetyCenter emits approved/executed/skipped/error events to Store. SQLite owns
activity, exclusions, settings, safety_log and locations; schema_migrations tracks
four transactionally applied migrations. UserDefaults also stores UI preferences.
Legacy migration is a distinct copy/migration path, suppressed by test mode.
Its internal cleanup of owned migration artifacts is not a cleanup engine.

The audit sink is non-throwing and counts failed writes. AppEnvironment currently
opens Store optionally, can fall back to :memory:, and several UI reads use try?.
Database rejects step and binding errors rather than returning partial reads or
executing after failed binding. No schema or public API change was required.
Therefore persistent audit availability is not guaranteed by the current API.
This is remaining debt, not an append-only durability guarantee.

## External boundaries

No account, server auth, job queue, Docker service or remote database. File access
uses the current macOS user's permissions and TCC; no privileged helper. The
explicit UpdateChecker uses an ephemeral URLSession for release metadata.
App-store/vendor links hand off to external applications. TestStoreOverride needs
both test marker and validated temporary store path; it suppresses legacy import.
CI performs source/build/test/site/package gates; separate release workflows use
signing/notarization credentials. Local source validation does not verify releases.

## Target and incremental path

Keep the existing dependency graph, native stack, eight product destinations and
read-only engines. Do not import the absent v2 directory layout or create a second
application. First enforce fail-safe mutation and explicit database errors; then
surface unavailable storage in UI and exercise complete native workflows.
Extract shared orchestration only where multiple callers need the same behavior.
No schema change or new dependency is required for the current fixes.

The 2026-09-25 reconstruction and 2026-09-26 greenfield documents are competing
historical proposals, not evidence of two active implementations. Current work is
tracked in [the recovery plan](Reconstruction/RECOVERY_PLAN.md) and
[the handoff](../docs/PASSATION.md).
