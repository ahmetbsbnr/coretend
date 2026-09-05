// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import AppDiscovery
import IntegrityCore
import Persistence
import DesignSystem

// MARK: - Shared Recovery Plan scan (run once, read by four modules)

/// Smart Scan's storage-family modules (Storage, Developer, Duplicates,
/// Privacy) are all slices of the SAME work `RecoveryPlanService` already
/// does: one Cleanup + Duplicates + Leftovers + Privacy pass that produces
/// `RecoveryPlanCandidateData` with the proven `RecoveryPlanEligibility`
/// categories and the proven anti-double-counting (Cleanup's `user.caches`
/// is forced `.notIncluded` so browser/leftover cache bytes are never
/// counted twice). Rather than re-run that pass per module, the four
/// providers share this actor: the first to ask triggers the scan, the rest
/// await the same result.
actor SmartScanRecoveryCandidates {
    private let home: URL
    private let store: Store?
    private var cached: [RecoveryPlanCandidateData]?
    private var inFlight: Task<[RecoveryPlanCandidateData], Never>?

    init(home: URL, store: Store?) {
        self.home = home
        self.store = store
    }

    /// Test seam: start from a fixed candidate set instead of running the
    /// real four-engine pass, so the module → totals mapping can be verified
    /// deterministically.
    init(preloaded: [RecoveryPlanCandidateData]) {
        self.home = URL(fileURLWithPath: "/dev/null")
        self.store = nil
        self.cached = preloaded
    }

    func candidates() async -> [RecoveryPlanCandidateData] {
        if let cached { return cached }
        if let inFlight { return await inFlight.value }
        let home = home
        let store = store
        let task = Task { await RecoveryPlanService.prepareCandidates(home: home, store: store) }
        inFlight = task
        let result = await task.value
        cached = result
        inFlight = nil
        return result
    }
}

// MARK: - Storage-family provider

/// Maps one module's slice of the shared Recovery Plan candidates into
/// `SmartScanTotals`. It never walks the filesystem itself and never
/// executes anything — it reads structured candidates only.
struct SmartScanStorageFamilyProvider: SmartScanProvider {
    let module: SmartScanModuleID
    let candidates: SmartScanRecoveryCandidates
    /// Which payloads belong to this module. Pure, captures nothing.
    let belongs: @Sendable (RecoveryPlanSourcePayload) -> Bool

    func scan(progress: @Sendable (String) -> Void) async throws -> SmartScanModuleResult {
        try Task.checkCancellation()
        let all = await candidates.candidates()
        try Task.checkCancellation()

        var totals = SmartScanTotals()
        for data in all where belongs(data.payload) {
            let bytes = data.candidate.reclaimableBytes
            switch data.candidate.category {
            case .recommended, .optional:
                totals.potentiallyRecoverableBytes += bytes
            case .reviewRequired:
                totals.needsReviewBytes += bytes
            case .notIncluded:
                // Excluded from planning (overlap, read-only, high-risk,
                // uncertain). Surfaced as an informational pointer — the
                // Recovery Plan screen shows the detail — never folded into
                // recoverable or review bytes here (that is what would
                // double-count).
                totals.informationalCount += 1
            }
        }

        progress(mcFormatBytes(totals.potentiallyRecoverableBytes))
        return SmartScanModuleResult(
            module: module,
            headline: Self.headline(totals),
            totals: totals,
            // The recoverable bytes are already overlap-free by construction
            // (RecoveryPlanEligibility resolved the overlap upstream), so the
            // global Smart Scan total stays exact.
            overlapsStorage: false
        )
    }

    static func headline(_ totals: SmartScanTotals) -> String {
        if totals.potentiallyRecoverableBytes > 0 {
            return L("smartscan.headline.recoverable", mcFormatBytes(totals.potentiallyRecoverableBytes))
        }
        if totals.needsReviewBytes > 0 {
            return L("smartscan.headline.recoverable", mcFormatBytes(totals.needsReviewBytes))
        }
        return L("smartscan.headline.nothing")
    }
}

// MARK: - Applications provider (cheap metadata — counts, never bytes)

/// Reports the installed-app inventory and how many of those apps have a
/// managed update path (App Store / Homebrew / Sparkle). It never claims a
/// specific update is *available* — CoreTend does not fetch appcasts — so
/// every figure here is an informational count.
struct SmartScanApplicationsProvider: SmartScanProvider {
    let module = SmartScanModuleID.applications
    let environment: [String: String]

    func scan(progress: @Sendable (String) -> Void) async throws -> SmartScanModuleResult {
        try Task.checkCancellation()
        let discovery = ApplicationInventoryLocations.resolve(environment: environment).discovery
        let apps = await Task.detached(priority: .utility) { discovery.discoverApps() }.value
        try Task.checkCancellation()

        let managed = apps.filter { AppUpdateSource.detect(for: $0).source != .none }.count
        var totals = SmartScanTotals()
        totals.informationalCount = apps.count
        progress("\(apps.count)")

        return SmartScanModuleResult(
            module: module,
            headline: L("smartscan.headline.apps", apps.count, managed),
            totals: totals
        )
    }
}

// MARK: - Integrity provider (cheap metadata — attention / informational only)

/// Surfaces read-only IntegrityCore signals: system-wide launch daemons are
/// worth a look (attention); quarantined downloads and per-user launch
/// agents are informational. No malware/antivirus claim is made, and a valid
/// signature is never presented as "safe".
struct SmartScanIntegrityProvider: SmartScanProvider {
    let module = SmartScanModuleID.integrity
    let home: URL
    /// nil → the real system LaunchAgents/LaunchDaemons directories; tests
    /// inject isolated temp directories.
    let loginItemLocations: [(URL, LoginItem.Scope)]?

    func scan(progress: @Sendable (String) -> Void) async throws -> SmartScanModuleResult {
        try Task.checkCancellation()
        let downloads = home.appendingPathComponent("Downloads")
        let locations = loginItemLocations
        let (quarantined, daemons, agents) = await Task.detached(priority: .utility) { () -> (Int, Int, Int) in
            let provenance = ProvenanceScanner.scan(folder: downloads)
            let items = locations.map { LoginItemScanner.scan(locations: $0) } ?? LoginItemScanner.scan()
            let q = provenance.filter(\.isQuarantined).count
            let d = items.filter { $0.scope == .globalDaemon }.count
            let a = items.count - d
            return (q, d, a)
        }.value
        try Task.checkCancellation()

        var totals = SmartScanTotals()
        totals.attentionCount = daemons
        totals.informationalCount = quarantined + agents
        progress("\(daemons + quarantined + agents)")

        return SmartScanModuleResult(
            module: module,
            headline: L("smartscan.headline.signals", totals.attentionCount, totals.informationalCount),
            totals: totals
        )
    }
}

// MARK: - Factory

enum SmartScanProviders {
    /// The six real providers, wired to the engines CoreTend already ships.
    /// `home` / `environment` / `store` are injectable so tests run against a
    /// disposable fixture tree and a throwaway store.
    @MainActor
    static func live(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        store: Store? = AppEnvironment.shared.store
    ) -> [SmartScanProvider] {
        let candidates = SmartScanRecoveryCandidates(home: home, store: store)
        let integrityHome = ApplicationInventoryLocations.resolve(environment: environment).home

        return [
            SmartScanStorageFamilyProvider(module: .storage, candidates: candidates) { payload in
                switch payload {
                case let .cleanup(ruleID, _): return !ruleID.hasPrefix("dev.")
                case .leftovers: return true
                case .duplicates, .privacy: return false
                }
            },
            SmartScanStorageFamilyProvider(module: .developer, candidates: candidates) { payload in
                if case let .cleanup(ruleID, _) = payload { return ruleID.hasPrefix("dev.") }
                return false
            },
            SmartScanStorageFamilyProvider(module: .duplicates, candidates: candidates) { payload in
                if case .duplicates = payload { return true }
                return false
            },
            SmartScanStorageFamilyProvider(module: .privacy, candidates: candidates) { payload in
                if case .privacy = payload { return true }
                return false
            },
            SmartScanApplicationsProvider(environment: environment),
            SmartScanIntegrityProvider(home: integrityHome, loginItemLocations: nil),
        ]
    }
}
