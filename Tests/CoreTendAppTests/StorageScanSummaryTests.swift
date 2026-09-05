// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
import SafetyCore
@testable import CoreTendApp

private func finding(_ bytes: Int64, risk: RiskLevel = .low, preselected: Bool = false) -> ScanFinding {
    ScanFinding(
        url: URL(fileURLWithPath: "/tmp/x-\(UUID().uuidString)"),
        logicalSize: bytes, allocatedSize: bytes, modificationDate: nil,
        ruleID: "test.rule", category: "cache", explanation: "e",
        confidence: 1, risk: risk, preselected: preselected)
}

@Suite("StorageScanSummary — the six quantities never collapse into one")
struct StorageScanSummaryTests {

    @Test func inspectedIsNotDetected() {
        let s = StorageScanSummary.from(
            findings: [finding(100), finding(200)],
            itemsInspected: 345_331, totalDetectedCount: 2, totalDetectedBytes: 300,
            selectedIDs: [])
        #expect(s.itemsInspected == 345_331)
        #expect(s.detectedBytes == 300)
        #expect(s.detectedCount == 2)
        #expect(Int64(s.itemsInspected) != s.detectedBytes, "items inspected is a count, not a byte figure")
    }

    @Test func detectedIsNotReclaimableWhenSomethingNeedsReview() {
        let a = finding(1_000, risk: .low)
        let b = finding(4_000, risk: .high)   // needs individual review
        let s = StorageScanSummary.from(
            findings: [a, b], itemsInspected: 10, totalDetectedCount: 2, totalDetectedBytes: 5_000,
            selectedIDs: [])
        #expect(s.detectedBytes == 5_000)
        #expect(s.reviewRequiredBytes == 4_000)
        #expect(s.reclaimableBytes == 1_000)
        #expect(s.reclaimableBytes != s.detectedBytes, "high-risk bytes are detected but not auto-reclaimable")
        #expect(s.reclaimableBytes + s.reviewRequiredBytes == s.detectedBytes, "the split is exhaustive")
    }

    @Test func reclaimableIsNotSelected() {
        let a = finding(1_000, risk: .low)
        let b = finding(2_000, risk: .low)
        let c = finding(3_000, risk: .low)
        let s = StorageScanSummary.from(
            findings: [a, b, c], itemsInspected: 9, totalDetectedCount: 3, totalDetectedBytes: 6_000,
            selectedIDs: [a.id])                       // only the smallest ticked
        #expect(s.reclaimableBytes == 6_000)
        #expect(s.selectedBytes == 1_000)
        #expect(s.selectedBytes != s.reclaimableBytes, "the CTA spends the selection, not the whole reclaimable pool")
        #expect(s.selectedBytes < s.detectedBytes)
    }

    @Test func selectedIsNotRecovered() {
        let a = finding(1_000)
        var s = StorageScanSummary.from(
            findings: [a], itemsInspected: 1, totalDetectedCount: 1, totalDetectedBytes: 1_000,
            selectedIDs: [a.id])
        #expect(s.selectedBytes == 1_000)
        #expect(s.recoveredBytes == nil, "nothing is recovered until execution reports a real outcome")
        // A move that freed less than intended (e.g. a file changed) still round-trips honestly.
        s = StorageScanSummary.from(
            findings: [a], itemsInspected: 1, totalDetectedCount: 1, totalDetectedBytes: 1_000,
            selectedIDs: [a.id], recoveredBytes: 720)
        #expect(s.recoveredBytes == 720)
        #expect((s.recoveredBytes ?? 0) <= s.selectedBytes, "recovered can never exceed what was selected")
    }

    @Test func emptySelectionMeansNoDestructiveCTA() {
        let s = StorageScanSummary.from(
            findings: [finding(9_999)], itemsInspected: 1, totalDetectedCount: 1, totalDetectedBytes: 9_999,
            selectedIDs: [])
        #expect(s.hasSelection == false)
        #expect(s.selectedBytes == 0)
    }

    @Test func partialSelectionCtaMathMatchesTheTickedItemsOnly() {
        let items = (1...10).map { finding(Int64($0) * 100) }        // 100..1000, sum 5500
        let ticked = Set(items.prefix(3).map(\.id))                  // 100+200+300 = 600
        let s = StorageScanSummary.from(
            findings: items, itemsInspected: 4_200, totalDetectedCount: 10, totalDetectedBytes: 5_500,
            selectedIDs: ticked)
        #expect(s.selectedBytes == 600)
        #expect(s.detectedBytes == 5_500)
        // The "Move X to Trash" label must read 600, never 5500.
        #expect(s.selectedBytes == 600 && s.selectedBytes != s.detectedBytes)
    }

    @Test func displayTruncationInflatesReclaimableNotReviewRequired() {
        // 3 findings shown (600 B), but the engine reported 50 findings / 9000 B.
        let shown = [finding(100), finding(200, risk: .high), finding(300)]
        let s = StorageScanSummary.from(
            findings: shown, itemsInspected: 99, totalDetectedCount: 50, totalDetectedBytes: 9_000,
            selectedIDs: [])
        #expect(s.reviewRequiredBytes == 200, "only the shown high-risk finding counts as review-required")
        #expect(s.reclaimableBytes == 9_000 - 200, "the unshown remainder is attributed to reclaimable")
        #expect(s.reclaimableBytes + s.reviewRequiredBytes == s.detectedBytes)
    }
}
