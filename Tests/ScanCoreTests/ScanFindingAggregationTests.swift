// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import SafetyCore
@testable import ScanCore

private func finding(logicalSize: Int64, allocatedSize: Int64?) -> ScanFinding {
    ScanFinding(url: URL(fileURLWithPath: "/tmp/x"), logicalSize: logicalSize, allocatedSize: allocatedSize,
                modificationDate: nil, ruleID: "test", category: "test", explanation: "test",
                confidence: 1, risk: .low, preselected: false)
}

@Suite("[ScanFinding].totalAllocatedSizeIfFullyKnown")
struct ScanFindingAggregationTests {
    @Test func sumsAllocatedSizeWhenEveryFindingHasOne() {
        let findings = [finding(logicalSize: 100, allocatedSize: 90), finding(logicalSize: 200, allocatedSize: 180)]
        #expect(findings.totalAllocatedSizeIfFullyKnown == 270)
    }

    @Test func nilIfAnySingleFindingIsMissingAllocatedSize() {
        let findings = [finding(logicalSize: 100, allocatedSize: 90), finding(logicalSize: 200, allocatedSize: nil)]
        #expect(findings.totalAllocatedSizeIfFullyKnown == nil,
                "a partial sum must never be presented as if it covered every finding")
    }

    @Test func emptyArrayIsAMeasuredZeroNotNil() {
        let findings: [ScanFinding] = []
        #expect(findings.totalAllocatedSizeIfFullyKnown == 0, "no findings means zero allocated bytes, a real measurement")
    }

    @Test func singleFindingWithoutAllocatedSizeIsNil() {
        #expect([finding(logicalSize: 500, allocatedSize: nil)].totalAllocatedSizeIfFullyKnown == nil)
    }
}
