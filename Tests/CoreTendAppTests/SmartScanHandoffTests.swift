// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import SafetyCore
@testable import CoreTendApp

private struct QuickProvider: SmartScanProvider {
    let module: SmartScanModuleID
    var hang = false
    func scan(progress: @Sendable (String) -> Void) async throws -> SmartScanModuleResult {
        if hang {
            for _ in 0..<10_000 { try Task.checkCancellation(); try await Task.sleep(for: .milliseconds(5)) }
        }
        return SmartScanModuleResult(module: module, headline: "h",
                                     totals: SmartScanTotals(potentiallyRecoverableBytes: 5))
    }
}

private func advisorFinding(_ bytes: Int64?, id: String) -> AdvisorFinding {
    AdvisorFinding(id: id, title: "t", summary: "s", reason: "r", consequence: "c",
                   risk: .low, confidence: .high, reversibility: .trash,
                   reclaimableBytes: bytes, category: .cleanup, source: "test")
}

private func candidateData(_ id: String, _ bytes: Int64, _ category: RecoveryPlanCategory)
-> RecoveryPlanCandidateData {
    RecoveryPlanCandidateData(
        candidate: RecoveryPlanCandidate(finding: advisorFinding(bytes, id: id), category: category),
        payload: .cleanup(ruleID: "user.logs", findings: []))
}

@MainActor
@Suite("Smart Scan → Recovery Plan handoff")
struct SmartScanHandoffTests {

    private func waitUntil(_ timeout: Duration = .seconds(3), _ cond: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if cond() { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func aCompletedScanPublishesTheExactCandidatesToTheHandoff() async {
        SmartScanHandoff.shared.clear()
        let prepared = [
            candidateData("a", 1_000, .recommended),
            candidateData("b", 500, .reviewRequired),
            candidateData("c", 9_000, .notIncluded),
        ]
        let cache = SmartScanRecoveryCandidates(preloaded: prepared)
        let model = SmartScanModel(
            coordinator: SmartScanCoordinator(providers: [QuickProvider(module: .storage)]),
            candidates: cache,
            pollInterval: .milliseconds(20))

        model.start()
        await waitUntil { model.phase == .completed }

        let handed = await SmartScanHandoff.shared.freshCandidates()
        #expect(handed?.count == 3)
        #expect(handed?.map(\.candidate.id) == ["a", "b", "c"])
        // Categories preserved exactly — no reclassification in the handoff.
        #expect(handed?.map(\.candidate.category) == [.recommended, .reviewRequired, .notIncluded])
        #expect(SmartScanHandoff.shared.report?.wasCancelled == false)
    }

    @Test func aCancelledScanPublishesNothing() async {
        SmartScanHandoff.shared.clear()
        let cache = SmartScanRecoveryCandidates(preloaded: [candidateData("a", 1_000, .recommended)])
        let model = SmartScanModel(
            coordinator: SmartScanCoordinator(providers: [QuickProvider(module: .storage, hang: true)]),
            candidates: cache,
            pollInterval: .milliseconds(20))

        model.start()
        await waitUntil { model.phase == .running }
        model.cancel()
        await waitUntil { model.phase == .cancelled }

        #expect(await SmartScanHandoff.shared.freshCandidates() == nil)
        #expect(SmartScanHandoff.shared.cache == nil)
    }

    @Test func startingANewScanClearsAPriorHandoff() async {
        SmartScanHandoff.shared.clear()
        let cache = SmartScanRecoveryCandidates(preloaded: [candidateData("a", 1_000, .recommended)])
        let model = SmartScanModel(
            coordinator: SmartScanCoordinator(providers: [QuickProvider(module: .storage)]),
            candidates: cache, pollInterval: .milliseconds(20))
        model.start()
        await waitUntil { model.phase == .completed }
        #expect(await SmartScanHandoff.shared.freshCandidates() != nil)

        model.reset()
        model.start()
        // Immediately after starting again, the old handoff must be gone.
        #expect(SmartScanHandoff.shared.cache == nil)
        await waitUntil { model.phase == .completed }
    }

    @Test func staleHandoffIsNotUsed() async {
        SmartScanHandoff.shared.clear()
        let cache = SmartScanRecoveryCandidates(preloaded: [candidateData("a", 1_000, .recommended)])
        // Recorded well beyond the freshness window.
        SmartScanHandoff.shared.record(
            cache: cache, report: SmartScanReport(),
            at: Date().addingTimeInterval(-(SmartScanHandoff.freshness + 60)))
        #expect(SmartScanHandoff.shared.isFresh == false)
        #expect(await SmartScanHandoff.shared.freshCandidates() == nil)
        SmartScanHandoff.shared.clear()
    }

    @Test func moduleDrillTargetsMapToRealSidebarModules() {
        #expect(SmartScanModuleID.storage.sidebarModule == .cleanup)
        #expect(SmartScanModuleID.developer.sidebarModule == .developer)
        #expect(SmartScanModuleID.duplicates.sidebarModule == .duplicates)
        #expect(SmartScanModuleID.privacy.sidebarModule == .privacyLab)
        #expect(SmartScanModuleID.applications.sidebarModule == .applications)
        #expect(SmartScanModuleID.integrity.sidebarModule == .protection)
    }

    @Test func elapsedTextIsMinutesAndSeconds() {
        #expect(smartScanElapsedText(0) == "0:00")
        #expect(smartScanElapsedText(9) == "0:09")
        #expect(smartScanElapsedText(75) == "1:15")
        #expect(smartScanElapsedText(-3) == "0:00")
    }
}
