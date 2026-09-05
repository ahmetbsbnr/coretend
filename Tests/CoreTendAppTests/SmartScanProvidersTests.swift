// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import SafetyCore
@testable import CoreTendApp

private func advisor(_ bytes: Int64?, id: String = UUID().uuidString,
                     category: TimelineScope = .cleanup) -> AdvisorFinding {
    AdvisorFinding(id: id, title: "t", summary: "s", reason: "r", consequence: "c",
                   risk: .low, confidence: .high, reversibility: .trash,
                   reclaimableBytes: bytes, category: category, source: "test")
}

private func data(_ payload: RecoveryPlanSourcePayload, bytes: Int64?,
                  category: RecoveryPlanCategory,
                  reason: RecoveryPlanExclusionReason? = nil) -> RecoveryPlanCandidateData {
    RecoveryPlanCandidateData(
        candidate: RecoveryPlanCandidate(finding: advisor(bytes), category: category, exclusionReason: reason),
        payload: payload)
}

@Suite("Smart Scan real providers — storage-family mapping")
struct SmartScanProvidersTests {

    private func storageProvider(_ candidates: [RecoveryPlanCandidateData]) -> SmartScanStorageFamilyProvider {
        SmartScanStorageFamilyProvider(module: .storage, candidates: SmartScanRecoveryCandidates(preloaded: candidates)) { payload in
            switch payload {
            case let .cleanup(ruleID, _): return !ruleID.hasPrefix("dev.")
            case .leftovers: return true
            case .duplicates, .privacy: return false
            }
        }
    }

    @Test func recommendedAndOptionalBecomeRecoverableReviewRequiredBecomesReview() async throws {
        let provider = storageProvider([
            data(.cleanup(ruleID: "user.logs", findings: []), bytes: 1_000, category: .recommended),
            data(.cleanup(ruleID: "user.oldinstallers", findings: []), bytes: 500, category: .optional),
            data(.leftovers(items: [], isAmbiguous: true), bytes: 400, category: .reviewRequired),
        ])
        let result = try await provider.scan { _ in }
        #expect(result.totals.potentiallyRecoverableBytes == 1_500)
        #expect(result.totals.needsReviewBytes == 400)
        #expect(result.overlapsStorage == false)
    }

    @Test func notIncludedNeverContributesBytesOnlyAnInformationalPointer() async throws {
        let provider = storageProvider([
            data(.cleanup(ruleID: "user.caches", findings: []), bytes: 9_000, category: .notIncluded,
                 reason: .overlapsAnotherSource),
        ])
        let result = try await provider.scan { _ in }
        #expect(result.totals.potentiallyRecoverableBytes == 0)
        #expect(result.totals.needsReviewBytes == 0)
        #expect(result.totals.informationalCount == 1)
    }

    @Test func developerRulesAreExcludedFromTheStorageModule() async throws {
        let provider = storageProvider([
            data(.cleanup(ruleID: "user.logs", findings: []), bytes: 1_000, category: .recommended),
            data(.cleanup(ruleID: "dev.xcode.deriveddata", findings: []), bytes: 8_000, category: .recommended),
        ])
        let result = try await provider.scan { _ in }
        #expect(result.totals.potentiallyRecoverableBytes == 1_000)
    }

    @Test func developerModuleTakesOnlyTheDevRules() async throws {
        let shared = SmartScanRecoveryCandidates(preloaded: [
            data(.cleanup(ruleID: "user.logs", findings: []), bytes: 1_000, category: .recommended),
            data(.cleanup(ruleID: "dev.xcode.deriveddata", findings: []), bytes: 8_000, category: .recommended),
        ])
        let dev = SmartScanStorageFamilyProvider(module: .developer, candidates: shared) { payload in
            if case let .cleanup(ruleID, _) = payload { return ruleID.hasPrefix("dev.") }
            return false
        }
        let result = try await dev.scan { _ in }
        #expect(result.module == .developer)
        #expect(result.totals.potentiallyRecoverableBytes == 8_000)
    }

    @Test func duplicatesAndPrivacyPartitionByPayload() async throws {
        let shared = SmartScanRecoveryCandidates(preloaded: [
            data(.duplicates(groups: []), bytes: 2_000, category: .reviewRequired),
            data(.privacy(profiles: []), bytes: 3_000, category: .recommended),
        ])
        let dupes = SmartScanStorageFamilyProvider(module: .duplicates, candidates: shared) {
            if case .duplicates = $0 { return true }; return false
        }
        let privacy = SmartScanStorageFamilyProvider(module: .privacy, candidates: shared) {
            if case .privacy = $0 { return true }; return false
        }
        let d = try await dupes.scan { _ in }
        let p = try await privacy.scan { _ in }
        #expect(d.totals.needsReviewBytes == 2_000)
        #expect(d.totals.potentiallyRecoverableBytes == 0)
        #expect(p.totals.potentiallyRecoverableBytes == 3_000)
    }

    @Test func headlineFallsBackWhenThereIsNothingToReclaim() {
        #expect(SmartScanStorageFamilyProvider.headline(SmartScanTotals()) == L("smartscan.headline.nothing"))
        let some = SmartScanTotals(potentiallyRecoverableBytes: 1_234)
        #expect(SmartScanStorageFamilyProvider.headline(some) != L("smartscan.headline.nothing"))
    }

    @Test func aCancelledTaskStopsTheProviderBeforeItReportsAnything() async {
        let provider = storageProvider([
            data(.cleanup(ruleID: "user.logs", findings: []), bytes: 1_000, category: .recommended),
        ])
        let task = Task { try await provider.scan { _ in } }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func theProvidersFileHasNoDestructiveDependency() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/CoreTendApp/SmartScanProviders.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        for forbidden in ["SafetyCenter", "CleanupExecution", "trashItem", ".execute(", "removeItem"] {
            #expect(!source.contains(forbidden), "SmartScanProviders must not reference \(forbidden)")
        }
    }
}
