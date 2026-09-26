# Analysis Capabilities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give CoreTend analysis engines typed partial/error/cancellation results, bounded work, and explicit measurement provenance while preserving existing behavior through staged UI adapters.

**Architecture:** Add shared analysis report, issue, measurement, and limit value types in `ScanCore`. Migrate ScanCore consumers by capability, then AppDiscovery, IntegrityCore, SystemMetrics, and UI. Keep separate traversal policies unless tests prove they are equivalent; retain old entry points as adapters until consumers migrate.

**Tech Stack:** Swift 6, Swift Package Manager, Foundation, existing macOS Security/Vision/Darwin APIs, Swift Testing. No runtime dependency.

**Spec:** `docs/superpowers/specs/2026-09-26-coretend-analysis-capabilities-design.md`; requirements `docs/superpowers/specs/2026-09-25-coretend-reconstruction-design.md` FR-02, FR-03, FR-08, FR-09, NFR-05, NFR-06, NFR-10.

## Global Constraints

- Initial target remains macOS 14+ arm64.
- Scans remain read-only; no engine may call file move/delete APIs.
- Never follow symlinks or hydrate remote-only cloud placeholders.
- Keep logical size, allocated local bytes, unavailable measurements, and remote-only placeholders distinct.
- Integrity remains read-only and native-signal-only; never infer a malware verdict or a clean result from missing evidence.
- Use injected fixture roots; tests must not scan real user Library or `/Applications` paths.
- No runtime dependency, schema migration, release, tag, push, or publication.
- Preserve old public entry points until all current consumers use new typed APIs.
- Every report must distinguish complete, partial, cancelled, and failed work; limits and skipped/unreadable items must be observable.
- Do not invent performance budgets. Derive default traversal/result limits from repeatable local fixture and stress measurements, and record test environment.

---

## File map

- Create `Sources/ScanCore/AnalysisReport.swift`: shared run status, typed issue, byte measurement, and policy values.
- Create `Sources/ScanCore/FileInventory.swift` only if Task 2 semantic audit proves at least two callers share root, hidden/package, symlink, cloud, exclusion, error, and cancellation rules. Otherwise retain individual walkers and record the proof-based no-consolidation decision in the plan notes.
- Create `Tests/ScanCoreTests/AnalysisReportTests.swift`; modify `Sources/ScanCore/ScanCore.swift`, `DuplicateEngine.swift`, `SimilarImagesEngine.swift`, and `SpaceLensEngine.swift`: typed reports, limits, cancellation, byte provenance, and compatibility adapters.
- Modify `Package.swift` so AppDiscovery and IntegrityCore depend on ScanCore analysis contracts; modify `Sources/AppDiscovery/AppDiscovery.swift` and `Sources/IntegrityCore/IntegrityCore.swift`: typed reports, injected roots/policies, cancellation, and compatibility adapters.
- Modify `Sources/SystemMetrics/SystemMetrics.swift`: source-stamped measured/unavailable values.
- Modify current consumers in `Sources/CoreTendApp/CleanupView.swift`, `MyClutterView.swift`, `DuplicatesView.swift`, `SpaceLensView.swift`, `ApplicationsView.swift`, `LeftoversView.swift`, `AppUpdatesView.swift`, `ProtectionView.swift`, `PerformanceView.swift`, `DashboardView.swift`, and `CoreTendApp.swift` as required by typed APIs.
- Extend existing tests in `Tests/ScanCoreTests/`, `Tests/AppDiscoveryTests/AppDiscoveryTests.swift`, `Tests/IntegrityCoreTests/IntegrityCoreTests.swift`, `Tests/SystemMetricsTests/MetricsTests.swift`, and `Tests/CoreTendAppTests/`.
- Update `Documentation/ARCHITECTURE_OVERVIEW.md` and `Documentation/REQUIREMENTS_TRACEABILITY.md` with capability ownership and evidence links.

## Shared API contract

Task 1 defines these public names and invariants before capability migration:

```swift
public enum AnalysisStatus: Sendable, Equatable {
    case complete, partial, cancelled, failed
}

public enum AnalysisIssueCode: Sendable, Equatable {
    case rootMissing, permissionDenied, metadataReadFailed, contentReadFailed
    case unsupportedItem, measurementUnavailable, resultLimitReached, traversalLimitReached
}

public struct AnalysisIssue: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let code: AnalysisIssueCode
    public let url: URL?
    public let detailCode: Int32?
}

public enum ByteMeasurement: Sendable, Equatable {
    case logical(Int64)
    case allocated(Int64)
    case unavailable
    case remotePlaceholder(logicalBytes: Int64?)
}

public struct AnalysisLimits: Sendable, Equatable {
    public let maxConcurrentOperations: Int
    public let maxVisitedItems: Int
    public let maxResults: Int
    public let maxDepth: Int
    public let hashChunkBytes: Int
}

public struct AnalysisReport<Output: Sendable>: Sendable {
    public let startedAt: Date
    public let finishedAt: Date
    public let roots: [URL]
    public let status: AnalysisStatus
    public let issues: [AnalysisIssue]
    public let output: Output
}
```

The implementation may add initializer validation or convenience accessors but must keep these semantics. Clamp invalid limits to documented minimums and measured upper bounds. Set default caps only after repeatable local fixture/stress runs; do not select arbitrary resource numbers. `AnalysisReport` always carries best-known output, including an empty or partial output; callers must inspect `status`. A cancelled report cannot be labeled complete. Error paths remain local-only values and must be redacted by any export boundary.

A metric is represented by `MetricMeasurement<Value: Sendable>` with `value: Value?`, a `MetricSource` enum (`mach`, `sysctl`, `volumeResourceValues`, `getifaddrs`, `processInfo`), a measurement timestamp, and a typed unavailable reason. Missing OS data uses `value == nil`; never manufacture zero CPU, zero memory, zero disk capacity, or normal pressure as a substitute for failed reads.

## Task 1: Shared contracts and invariants

**Files:** Create `Sources/ScanCore/AnalysisReport.swift` and `Tests/ScanCoreTests/AnalysisReportTests.swift`.

**Interfaces:** Produces the public types above. No engine or app consumer migrates in this task.

- [x] Write failing tests in `AnalysisReportTests.swift` for report status/scope/issue/timestamps, distinct byte provenance, and lower-bound limit validation. Example assertion:

```swift
@Test func reportRetainsStatusAndScope() {
    let root = URL(fileURLWithPath: "/fixture")
    let report = AnalysisReport(startedAt: .distantPast, finishedAt: .distantFuture,
                                roots: [root], status: .partial, issues: [], output: [String]())
    #expect(report.status == .partial)
    #expect(report.roots == [root])
}
```

- [x] Run `Scripts/test.sh --skip-update --filter AnalysisReportTests`. Expected: test compilation fails because shared types do not exist; observed missing-type diagnostics.
- [x] Add `AnalysisReport.swift` with the exact enums/structs above; implement `AnalysisLimits` validation with `maxConcurrentOperations >= 1`, `maxVisitedItems >= 1`, `maxResults >= 1`, `maxDepth >= 1`, `hashChunkBytes >= 4096`.
- [x] Run the targeted filter again. Expected: report and limit tests pass; observed 3 passing.
- [x] Run `git diff --check`, then commit `feat: add typed analysis result contracts` (`eae4b08`).

## Task 2: Read-only inventory, general scan, duplicates, and similar images

**Files:** Modify `Sources/ScanCore/ScanCore.swift`, `DuplicateEngine.swift`, `SimilarImagesEngine.swift`, and their existing test files. Create `FileInventory.swift` only after the semantic comparison below passes.

**Interfaces:** Add `analyze(rules:limits:pauseController:progress:) async -> AnalysisReport<ScanAnalysisSummary>` where `ScanAnalysisSummary` stores `findings`, `scannedItems`, and `measuredLogicalBytes`; add duplicate and image `analyze(limits:pauseController:progress:)` methods returning reports whose output includes groups and summary counts. Progress callback is `@Sendable (Int, URL?) async -> Void`; awaiting callback provides backpressure. Keep `run(...) -> AsyncStream<...>` as compatibility adapters. Findings/groups are retained only up to `maxResults`; reaching a cap returns `.partial` with `.resultLimitReached`. Root/item failures append typed issues and continue other safe roots. Cancellation checks happen during traversal and each hash chunk.

- [x] Cover missing roots, result caps, cancellation, corrupt image content failure, duplicate file removal between hash passes, cloud-file classification and zero-local-byte accounting. `LegacyStreamContractTests` verifies one terminal event per adapter.
- [x] Deterministic cancellation at the first full-hash chunk is covered with an internal chunk observer. Synthetic remote-placeholder fixture proves duplicate analysis excludes it before hashing (zero hash-chunk callbacks); live iCloud provider behavior remains untested. Existing `CloudFileTests`, placeholder measurement, and `CloudCleanupTests` cover classification and local-byte accounting.
- [x] Run focused ScanCore suites during implementation; final full script passes all 73 ScanCoreTests (included below).
- [x] Compared hidden/package/Photos-library/symlink/cloud/root policies. Kept separate walks because duplicate search includes hidden entries while image search skips them and `.photoslibrary`; both skip package descendants, symlinks, and cloud placeholders.
- [x] Typed entry points, issue reports, explicit `ByteMeasurement`, visit/result/depth bounds, chunk checks, and compatibility adapters are implemented. Candidate retention is bounded by visited item cap.
- [x] Cleanup, My Clutter, and Duplicates consume typed status; empty partial results display warning copy. Progress/pause controls remain covered by existing tests.
- [x] Full final `Scripts/test.sh --disable-sandbox --skip-update` passed 431 Swift Testing cases across 12 test runs; CoreTendAppTests 185/185 and ScanCoreTests 73/73.
- [x] Commits: `b9ebede feat: report partial scan and duplicate results`; final `git diff --check` rerun in Task 6.

## Task 3: Bounded SpaceLens measurements

**Files:** Modify `Sources/ScanCore/SpaceLensEngine.swift`, `Tests/ScanCoreTests/SpaceLensTests.swift`, `Tests/ScanCoreTests/StressTests.swift`, and `Sources/CoreTendApp/SpaceLensView.swift`.

**Interfaces:** Add async typed analysis entry point returning `AnalysisReport<SpaceNode>`; preserve existing stream method as adapter. Extend `SpaceNode` with logical/allocated/placeholder measurement provenance and explicit subtree completeness. Existing `size` stays temporarily as a compatibility accessor for allocated local bytes when known.

- [x] Test missing root, synthetic cloud placeholder with no local allocation claim, depth/visit/result bounds, and injected child metadata failure. Concurrent removal can be skipped silently by Foundation enumerator and is documented as a non-snapshot limitation.
- [x] Run focused `swift test --filter SpaceLensTests`: 10 tests pass, including existing roll-up, symlink, depth-cap, and treemap tests.
- [x] Implement typed issues, logical/allocated/remote-placeholder measurements, subtree completeness, visit/result/depth limits, and chunk-bounded shallow traversal. Existing `size` now reports known local allocated bytes; depth-capped shallow measurement remains covered by fixture.
- [x] Migrate `SpaceLensView` and depth-preserving rescan to typed reports; show partial state banner without changing treemap/navigation layout.
- [x] Run `swift test --filter SpaceLensTests` and `swift test --filter SpaceLensNavigationTests`: 10 engine tests and 6 navigation tests pass. Full global suite remains for Task 6.
- [x] Commit `930fc46 feat: bound space analysis and report incomplete trees`.

## Task 4: Application discovery and Integrity reports

**Files:** Modify `Package.swift`, `Sources/AppDiscovery/AppDiscovery.swift`, `Tests/AppDiscoveryTests/AppDiscoveryTests.swift`, `Sources/IntegrityCore/IntegrityCore.swift`, `Tests/IntegrityCoreTests/IntegrityCoreTests.swift`, and `Sources/CoreTendApp/ApplicationsView.swift`, `LeftoversView.swift`, `AppUpdatesView.swift`, `ProtectionView.swift`.

**Interfaces:** Add `analyzeApps(limits:) async -> AnalysisReport<[InstalledApp]>`, `analyzeAssociatedItems(for:limits:) async -> AnalysisReport<[AssociatedItem]>`, `analyzeLeftovers(installedBundleIDs:limits:) async -> AnalysisReport<[AssociatedItem]>`, `analyzeDownloads(folder:limits:) async -> AnalysisReport<[DownloadProvenance]>`, and `analyzeLoginItems(locations:limits:) async -> AnalysisReport<[LoginItem]>`. Inputs include explicit fixture roots/policy; old synchronous APIs remain adapters until UI migration. Keep `CodeSignInspector.inspect(at:)` native; add `CodeSignTier.unknown` and make `CodeSignInfo.signatureValid` optional so failed inspection differs from verified unsigned/ad-hoc and invalid signature.

- [x] Add typed missing-root, readable-root, and cancellation-during-sizing coverage. Permission-denied mapping is implemented; deterministic unreadable-permission fixture unavailable on this root-runner host (legacy unreadable cases remain).
- [x] Focused suites passed after implementation: AppDiscoveryTests 26/26; IntegrityCoreTests 23/23.
- [x] Implement bounded async enumeration/sizing, cancellation, exact bundle-ID classification, update-source precedence, stable app ordering, review-only launch items, and symlink-plist issue reporting.
- [x] Code-sign inspection now reports `.unknown` when Security cannot create a static code object; signature validity is optional.
- [x] Migrate Applications, Leftovers, App Updates, Protection, and diagnostic report to typed status; add EN/FR unknown-integrity copy.
- [x] Final focused validation: AppDiscoveryTests 26/26, IntegrityCoreTests 23/23, CoreTendAppTests 183/183; copy-honesty gate and locale parity (578/578) pass. `CoreTendUITests` excluded temporarily due known `_TestingInternals` issue; manifest restored.
- [x] Commit `feat: expose app discovery and integrity issues`.

## Task 5: Source-stamped system metric readings

**Files:** Modify `Sources/SystemMetrics/SystemMetrics.swift`, `Tests/SystemMetricsTests/MetricsTests.swift`, `Sources/CoreTendApp/PerformanceView.swift`, `DashboardView.swift`, and `CoreTendApp.swift`.

**Interfaces:** Wrap each snapshot field in `MetricMeasurement<Value>` as defined above. Add injectable provider closures to `MetricsCollector` initializer for Mach, sysctl, volume capacity, interface counters, and process-info reads; production initializer uses existing native APIs. Each failed provider result becomes unavailable with timestamp/source/reason. Compute disk capacity once per snapshot and use same sample for free/total. Keep no periodic sampler or persistence.

- [x] Fake-provider tests cover value/source/timestamp, first network sample unavailable, Mach/sysctl/disk failures, shared disk sample timestamp, and fraction without denominator.
- [x] Test-first compile failed against missing typed API; final MetricsTests passed 6/6.
- [x] Implement source-stamped measurements and injectable providers; derived fractions are optional. Failed providers stay unavailable.
- [x] Migrate Dashboard, Performance, menu bar, and sidebar. Missing readings show unavailable, no false attention state; source/time exposed in supporting/accessibility detail.
- [x] MetricsTests 6/6 and CoreTendAppTests 185/185 pass in final full run.
- [x] Commit `fa53142 feat: preserve provenance for system metrics`.

## Task 6: Integration, evidence, and documentation

**Files:** Modify `Documentation/ARCHITECTURE_OVERVIEW.md`, `Documentation/Reconstruction/REQUIREMENTS_TRACEABILITY.md`, and `passation.md`; update tests only for uncovered cross-capability regressions.

- [x] `AnalysisPresentationTests` checks partial status and `.rootMissing` survive App Updates adapter; injected child failure and hash-chunk cancellation remain partial/cancelled respectively; cloud-local-byte behavior covered by `CloudCleanupTests` and SpaceLens placeholder tests; `LegacyStreamContractTests` checks exactly one terminal event per adapter.
- [x] Focused suites passed; full script passed 431 Swift Testing cases with only `CoreTendUITests` temporarily omitted and manifest restored byte-for-byte. `CoreTendApp` release target build passed; full executable linked but dSYM generation failed with host `Operation not permitted`. Repository doctor, copy gate, 585/585 locale parity, and `git diff --check` passed. Direct standard run first failed before compilation because sandbox could not write `~/.cache/clang` module cache.
- [x] Update `Documentation/ARCHITECTURE_OVERVIEW.md` and `Documentation/Reconstruction/REQUIREMENTS_TRACEABILITY.md` with dependency direction, typed flow, inventory non-consolidation rationale, evidence, and host limitations.
- [x] Reviewed filesystem engines for mutating APIs/cloud hydration, symlink handling, explicit limit issues, status coercions, and source breakage. Final staged `git diff --check` follows. Synthetic duplicate-engine fixture confirms remote placeholder exclusion before any hash read; only live iCloud provider integration remains untested. Deterministic SpaceLens child-read and large-hash chunk cancellation tests pass.
- [x] Commit architecture/traceability evidence after doctor, links, copy, parity, and diff checks; refresh evidence for final gap-closure tests in follow-up commit.
- [x] Append final Programme 2 status and validation evidence to `passation.md`; keep this local handoff file untracked.

## Self-review

- Spec coverage: read-only operation, typed partial/error/cancellation, provenance, cloud placeholders, symlink policy, resource limits, Integrity signal limits, compatibility migration, fixtures, and evidence gates each map to Tasks 1–6.
- Placeholder scan: no TBD/TODO implementation steps. Defaults for resource caps are explicitly measured during implementation because the spec forbids inventing performance budgets.
- Type consistency: the shared report/status/issue/measurement/limits names are defined once above; engine entry points return `AnalysisReport`; metrics use `MetricMeasurement`; UI migration tasks name every known direct consumer.
- Scope check: Program 2 is one integrated programme because shared contracts and compatibility migration couple capability slices. No navigation, redesign, database migration, website, or release work included.
