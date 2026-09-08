// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
import DeepScanCore
@testable import CoreTendApp

@MainActor
@Suite("Deep Scan view model")
struct DeepScanViewModelTests {
    private func candidate(_ path: String, category: CleanupCategory,
                           risk: RiskClass, bytes: Int64 = 1_000) -> CleanupCandidate {
        CleanupCandidate(path: path, canonicalPath: path, category: category, subcategory: "s",
            detector: "d", logicalBytes: bytes, allocatedBytes: bytes, estimatedReclaimableBytes: bytes,
            owner: nil, confidence: .probable, risk: risk, recoverability: .trashRestore,
            reconstructability: .regeneratesLocally, lastActivity: nil, activeState: .idle,
            evidence: [Evidence(.pathPattern, "matched")], protectedReason: risk == .protected ? "x" : nil,
            recommendedAction: risk == .protected ? .keep : .review, defaultSelected: false,
            rationale: "r", ifRemoved: "i")
    }

    @Test("protected rows can never be toggled into the selection")
    func protectedRowsNotSelectable() {
        let model = DeepScanViewModel()
        let prot = candidate("/a/mem", category: .aiAndLLM, risk: .protected)
        model.results = DeepScanResultsModel([prot])
        let row = DeepScanDisplayRow(prot)
        model.toggle(row)
        #expect(model.selectedIDs.isEmpty)
    }

    @Test("category rail filter narrows the visible rows")
    func categoryFilterNarrowsRows() {
        let model = DeepScanViewModel()
        let a = candidate("/a/.next", category: .developer, risk: .safe)
        let b = candidate("/b/tmp", category: .temporaryFiles, risk: .safe)
        model.results = DeepScanResultsModel([a, b])
        // reflect into the private candidate store via results is enough for rows()
        model.selectedCategory = .developer
        #expect(model.rows().allSatisfy { $0.candidate.category == .developer })
        model.selectedCategory = nil
        #expect(model.rows().count == 2)
    }

    @Test("execution availability tracks the feature gate")
    func executionAvailabilityFollowsGate() {
        let model = DeepScanViewModel()
        DeepScanExecutionGate.isEnabled = false
        #expect(model.executionAvailable == false)
        DeepScanExecutionGate.isEnabled = true
        #expect(model.executionAvailable == true)
        DeepScanExecutionGate.isEnabled = false
    }
}
