// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore
import SafetyCore
import FileRules
import AppDiscovery
import Persistence

/// What Recovery Plan needs to remember about a candidate to execute it
/// later, through the exact same engine that produced it — never a second,
/// parallel destructive path. Holds the real scan-time data (paths,
/// modification dates for staleness checks, etc.), never just a byte count.
enum RecoveryPlanSourcePayload: Sendable {
    case cleanup(ruleID: String, findings: [ScanFinding])
    case duplicates(groups: [DuplicateGroup])
    /// `isAmbiguous` classifies every item in this payload — one payload per
    /// classification, matching the aggregate `AdvisorFinding` built from it.
    case leftovers(items: [AssociatedItem], isAmbiguous: Bool)
    case privacy(profiles: [BrowserProfile])
}

/// One candidate's real scan data alongside its `RecoveryPlanCandidate` id,
/// so the view model can look up "what do I actually act on" when the user
/// confirms a selection, without threading payloads through the plan model
/// itself (which stays a plain, Equatable, testable value type).
struct RecoveryPlanCandidateData {
    let candidate: RecoveryPlanCandidate
    let payload: RecoveryPlanSourcePayload
}

/// One source's real execution outcome — never a promise of the bytes a
/// plan predicted, only what actually happened.
struct RecoveryPlanSourceResult: Identifiable, Sendable {
    let id: String
    let category: TimelineScope
    let processedBytes: Int64
    let processedCount: Int
    let skippedCount: Int
}

/// The full outcome of executing a selection — per source, plus a total.
/// Deliberately not "atomic": each source executes through its own
/// `SafetyCenter` sequentially; a failure in one source never rolls back
/// another, and this type's job is to report that honestly rather than
/// imply a transaction that doesn't exist.
struct RecoveryPlanExecutionResult: Sendable {
    let sources: [RecoveryPlanSourceResult]
    var processedBytes: Int64 { sources.reduce(0) { $0 + $1.processedBytes } }
    var processedCount: Int { sources.reduce(0) { $0 + $1.processedCount } }
    var skippedCount: Int { sources.reduce(0) { $0 + $1.skippedCount } }
}

/// Orchestrates the four existing engines Recovery Plan is wired to. Never
/// walks the filesystem itself — every method here calls the same
/// `ScanEngine`/`DuplicateEngine`/`AppDiscovery`/`BrowserCatalog` entry
/// points `CleanupView`/`DuplicatesView`/`LeftoversView`/`PrivacyCleanerView`
/// already call, and executes through the same `SafetyCenter`/`PathValidator`
/// pair each of those views already uses — this is a second call site into
/// existing safe paths, never a second implementation of them.
enum RecoveryPlanService {
    // MARK: - Anti-double-counting
    //
    // Cleanup's `user.caches` rule scans all of ~/Library/Caches
    // recursively (Sources/FileRules/UserCleanupRules.swift), which
    // structurally overlaps two other wired sources at the filesystem
    // level: every browser cache Privacy Cleaner reports lives under
    // ~/Library/Caches/<browser> (Sources/CoreTendApp/BrowserDetection.swift),
    // and any leftover app's cache directory Leftovers reports (the
    // "Caches" location in AppDiscovery.leftovers) is also a subtree of
    // ~/Library/Caches. None of the three engines share a per-file
    // identifier that would let Recovery Plan reliably subtract the
    // overlap, so rather than risk the same bytes counted toward one goal
    // twice, `user.caches` is always `.notIncluded` here (exclusion reason
    // `.overlapsAnotherSource`) — still shown, with its real bytes, never
    // silently dropped. Package caches own disjoint subtrees excluded from
    // user.caches. SwiftPM's org.swift.swiftpm directory can also be reported
    // by Leftovers' reverse-DNS heuristic; overlapping Leftovers candidates
    // are excluded below, leaving the strict SwiftPM cache rule actionable.
    private static let overlappingCleanupRuleIDs: Set<String> = ["user.caches"]

    /// Runs all four wired engines and returns their real results as
    /// candidates. No demo data, no caching of a previous run — every call
    /// re-scans, exactly like opening Cleanup/Duplicates/Leftovers/Privacy
    /// directly would. `home` and `store` are injectable so tests exercise
    /// real scans against a disposable fixture tree and a throwaway store,
    /// never the real user's home or `~/Library/Application Support/CoreTend`
    /// (Leftovers uses its own existing `ApplicationInventoryLocations`
    /// environment-based isolation instead, unchanged).
    @MainActor
    static func prepareCandidates(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                                   store: Store? = AppEnvironment.shared.store) async -> [RecoveryPlanCandidateData] {
        async let cleanup = cleanupCandidates(home: home, store: store)
        async let duplicates = duplicateCandidates(home: home)
        async let leftovers = leftoverCandidates()
        async let privacy = privacyCandidates(home: home)
        return await cleanup + duplicates + leftovers + privacy
    }

    static func cleanupCandidates(home: URL, store: Store?) async -> [RecoveryPlanCandidateData] {
        let excluded = (try? await store?.exclusions()) ?? []
        let engine = ScanEngine(configuration: ScanConfiguration(home: home, excludedPaths: excluded))
        var byRule: [String: [ScanFinding]] = [:]
        for await event in engine.run(rules: UserCleanupRules.all) {
            if case let .finding(finding) = event {
                byRule[finding.ruleID, default: []].append(finding)
            }
        }
        return UserCleanupRules.all.map { rule in
            let findings = byRule[rule.id] ?? []
            let advisor = AdvisorService.advise(ruleID: rule.id, findings: findings)
            let overlaps = overlappingCleanupRuleIDs.contains(rule.id)
            let eligibility = RecoveryPlanEligibility.evaluate(advisor, overlapsAnotherSource: overlaps)
            let candidate = RecoveryPlanCandidate(
                finding: advisor, category: eligibility.category, exclusionReason: eligibility.exclusionReason)
            return RecoveryPlanCandidateData(candidate: candidate, payload: .cleanup(ruleID: rule.id, findings: findings))
        }
    }

    static func duplicateCandidates(home: URL) async -> [RecoveryPlanCandidateData] {
        let roots = duplicateRoots(home: home)
        let engine = DuplicateEngine(roots: roots)
        var groups: [DuplicateGroup] = []
        for await event in engine.run() {
            if case let .group(group) = event { groups.append(group) }
        }
        guard !groups.isEmpty else { return [] }
        // One aggregate candidate across every group — Recovery Plan is a
        // plan-level view, not a per-group micro-management tool (that's
        // DuplicatesView); execution still acts group-by-group via the payload.
        let totalWasted = groups.reduce(Int64(0)) { $0 + $1.wastedBytes }
        let combined = AdvisorFinding(
            id: "duplicates.aggregate", title: TimelineCategoryLabel.display(engine: "duplicates", category: "wastedSpace"),
            summary: L("advisor.duplicates.summary"), reason: L("advisor.duplicates.reason"),
            consequence: L("advisor.duplicates.consequence"), risk: .medium, confidence: .exact,
            reversibility: .trash, reclaimableBytes: totalWasted, category: .duplicates, source: "duplicateEngine",
            recommendation: L("advisor.duplicates.recommendation"))
        let eligibility = RecoveryPlanEligibility.evaluate(combined)
        let candidate = RecoveryPlanCandidate(
            finding: combined, category: eligibility.category, exclusionReason: eligibility.exclusionReason)
        return [RecoveryPlanCandidateData(candidate: candidate, payload: .duplicates(groups: groups))]
    }

    /// Same three roots `DuplicatesView` scans — shared so scanning and
    /// execution never drift onto different roots for the same feature.
    static func duplicateRoots(home: URL) -> [URL] {
        ["Downloads", "Documents", "Desktop"].map { home.appendingPathComponent($0) }
    }

    private static func leftoverCandidates() async -> [RecoveryPlanCandidateData] {
        let discovery = ApplicationInventoryLocations.resolve(environment: ProcessInfo.processInfo.environment).discovery
        let found = await Task.detached(priority: .utility) {
            let installed = Set(discovery.discoverApps().compactMap(\.bundleIdentifier))
            return discovery.leftovers(installedBundleIDs: installed)
        }.value
        guard !found.isEmpty else { return [] }
        let (ambiguous, exact) = found.reduce(into: ([AssociatedItem](), [AssociatedItem]())) { partial, item in
            if LeftoversAmbiguity.isAmbiguous(item, among: found) { partial.0.append(item) } else { partial.1.append(item) }
        }
        var results: [RecoveryPlanCandidateData] = []
        for (items, isAmbiguous) in [(exact, false), (ambiguous, true)] where !items.isEmpty {
            let advisor = AdvisorService.advise(leftovers: items, isAmbiguous: isAmbiguous)
            let home = ApplicationInventoryLocations.resolve(environment: ProcessInfo.processInfo.environment).discovery.home
            let overlaps = overlapsPackageCaches(items: items, home: home)
            let eligibility = RecoveryPlanEligibility.evaluate(advisor, overlapsAnotherSource: overlaps)
            let candidate = RecoveryPlanCandidate(
                finding: advisor, category: eligibility.category, exclusionReason: eligibility.exclusionReason)
            results.append(RecoveryPlanCandidateData(candidate: candidate, payload: .leftovers(items: items, isAmbiguous: isAmbiguous)))
        }
        return results
    }

    static func privacyCandidates(home: URL) async -> [RecoveryPlanCandidateData] {
        let profiles = await Task.detached(priority: .utility) { BrowserCatalog.detect(home: home) }.value
        guard !profiles.isEmpty else { return [] }
        let advisor = AdvisorService.advise(browserProfiles: profiles)
        let eligibility = RecoveryPlanEligibility.evaluate(advisor)
        let candidate = RecoveryPlanCandidate(
            finding: advisor, category: eligibility.category, exclusionReason: eligibility.exclusionReason)
        return [RecoveryPlanCandidateData(candidate: candidate, payload: .privacy(profiles: profiles))]
    }

    static func overlapsPackageCaches(items: [AssociatedItem], home: URL) -> Bool {
        let roots = PackageCacheRules.all.flatMap { $0.roots(home) }
        return items.contains { item in
            roots.contains { root in
                PathValidator.isPath(root.path, under: item.url.path)
                    || PathValidator.isPath(item.url.path, under: root.path)
            }
        }
    }

    // MARK: - Execution
    //
    // Sequential, per source, each through that source's own validator and
    // `SafetyCenter` — the same construction its own view already uses.
    // Never atomic across sources: a failure in one never rolls back
    // another, and the result below reports each source's real outcome
    // rather than implying a transaction that doesn't exist.

    @MainActor
    static func execute(selected: [RecoveryPlanCandidateData],
                        home: URL = FileManager.default.homeDirectoryForCurrentUser,
                        store: Store? = AppEnvironment.shared.store) async -> RecoveryPlanExecutionResult {
        var results: [RecoveryPlanSourceResult] = []
        for data in selected {
            let result = await executeOne(data, home: home, store: store)
            results.append(result)
        }
        return RecoveryPlanExecutionResult(sources: results)
    }

    @MainActor
    static func executeOne(_ data: RecoveryPlanCandidateData, home: URL, store: Store?) async -> RecoveryPlanSourceResult {
        switch data.payload {
        case let .cleanup(ruleID, findings):
            let excluded = (try? await store?.exclusions()) ?? []
            let result = await CleanupExecution.execute(findings.filter { $0.ruleID == ruleID }, home: home,
                                                        excludedPaths: excluded, sink: store)
            if let store {
                try? await store.recordActivity(ActivityRecord(kind: .cleanup,
                    summary: "Recovery Plan: moved \(result.executed.count) items (\(ruleID)) to Trash",
                    itemCount: result.executed.count, bytes: result.processedBytes))
            }
            return RecoveryPlanSourceResult(id: data.candidate.id, category: .cleanup,
                processedBytes: result.processedBytes, processedCount: result.executed.count,
                skippedCount: findings.count - result.executed.count)

        case let .duplicates(groups):
            let allNonKeeperPaths = Set(groups.flatMap { group in group.urls.filter { $0 != group.keeper }.map(\.path) })
            let safePaths = DuplicateSafety.safeSelection(selectedPaths: allNonKeeperPaths, groups: groups)
            let center = SafetyCenter(validator: PathValidator(allowedRoots: duplicateRoots(home: home)), sink: store)
            var approved: [ApprovedFileOperation] = []
            for group in groups {
                for url in group.urls where safePaths.contains(url.path) {
                    if let op = try? await center.approve(
                        url: url, logicalSize: group.fileSize, ruleID: "clutter.duplicates", risk: .medium) {
                        approved.append(op)
                    }
                }
            }
            let result = await center.execute(approved)
            return finish(id: data.candidate.id, category: data.candidate.finding.category, result: result,
                          totalRequested: allNonKeeperPaths.count, store: store,
                          summary: "Recovery Plan: moved \(result.executed.count) duplicate copies to Trash")

        case let .leftovers(items, _):
            let center = SafetyCenter(
                validator: PathValidator(allowedRoots: [home.appendingPathComponent("Library")]), sink: store)
            var approved: [ApprovedFileOperation] = []
            for item in items {
                if let op = try? await center.approve(
                    url: item.url, logicalSize: item.sizeBytes, ruleID: "apps.leftovers", risk: .medium) {
                    approved.append(op)
                }
            }
            let result = await center.execute(approved)
            return finish(id: data.candidate.id, category: data.candidate.finding.category, result: result,
                          totalRequested: items.count, store: store,
                          summary: "Recovery Plan: removed \(result.executed.count) leftover items")

        case let .privacy(profiles):
            // Re-check each profile's browser is still closed right before
            // acting — state can go stale between plan preparation and
            // confirmation, exactly like PrivacyCleanerViewModel.cleanCaches().
            let stillClosed = profiles.filter { !PrivacyCleanerViewModel.isRunning($0) }
            let center = SafetyCenter(
                validator: PathValidator(allowedRoots: [home.appendingPathComponent("Library/Caches")]), sink: store)
            var approved: [ApprovedFileOperation] = []
            for profile in stillClosed {
                for url in profile.cacheURLs {
                    if let op = try? await center.approve(
                        url: url, logicalSize: profile.cacheBytes, ruleID: "privacy.browsercache", risk: .low) {
                        approved.append(op)
                    }
                }
            }
            let result = await center.execute(approved)
            return finish(id: data.candidate.id, category: data.candidate.finding.category, result: result,
                          totalRequested: profiles.count, store: store,
                          summary: "Recovery Plan: moved browser caches to Trash")
        }
    }

    /// Fire-and-forget activity recording, mirroring `AppEnvironment.record(_:)`
    /// exactly (same rationale: a missed write costs history, never
    /// correctness) but against an explicit `store` so tests can inject a
    /// throwaway one instead of touching the real app-wide singleton.
    private static func finish(id: String, category: TimelineScope, result: SafetyCenter.ExecutionResult,
                                totalRequested: Int, store: Store?, summary: String) -> RecoveryPlanSourceResult {
        let processedBytes = result.executed.reduce(Int64(0)) { $0 + $1.logicalSize }
        if let store {
            Task { try? await store.recordActivity(ActivityRecord(
                kind: .cleanup, summary: summary, itemCount: result.executed.count, bytes: processedBytes)) }
        }
        return RecoveryPlanSourceResult(
            id: id, category: category, processedBytes: processedBytes,
            processedCount: result.executed.count, skippedCount: totalRequested - result.executed.count)
    }
}
