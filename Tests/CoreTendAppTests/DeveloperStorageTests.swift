// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
@testable import CoreTendApp

@Suite("Developer storage presentation")
struct DeveloperStorageTests {
    @Test func xcodeReusesExistingRulesAndReviewPolicy() {
        let rules = DeveloperStorage.xcodeRules
        #expect(rules.map(\.id) == ["dev.xcode.deriveddata", "dev.xcode.archives", "dev.xcode.devicesupport"])
        #expect(rules.map(\.preselect) == [true, false, false])
        #expect(rules.map(\.risk) == [.low, .medium, .medium])
        #expect(rules.map(\.minimumAgeDays) == [0, 30, 90])
    }

    @Test func breakdownPreservesLiteralFolderNamesAndUsesExistingBytes() {
        let root = URL(fileURLWithPath: "/fixture/DerivedData")
        let findings = ["App-abcd/Build/a", "App-abcd/Index/b", "ModuleCache.noindex/c"].map {
            ScanFinding(url: root.appendingPathComponent($0), logicalSize: 100, allocatedSize: 4096,
                        modificationDate: nil, ruleID: "dev.xcode.deriveddata", category: "Cleanup",
                        explanation: "", confidence: 0.9, risk: .low, preselected: true)
        }
        let group = DeveloperStorage.Group(ruleID: "dev.xcode.deriveddata", findings: findings)
        #expect(group.logicalBytes == 300)
        #expect(group.allocatedBytes == 12288)
        #expect(group.breakdown(under: root).map(\.name) == ["App-abcd", "ModuleCache.noindex"])
        #expect(group.breakdown(under: root).map(\.logicalBytes) == [200, 100])
        #expect(group.advisor.id == "cleanup.dev.xcode.deriveddata")
    }

    @Test func emptyPresentationKeepsXcodeCategoriesWithoutInventingFindings() {
        let groups = DeveloperStorage.groups(findings: [])
        #expect(groups.prefix(3).map(\.ruleID) == DeveloperStorage.xcodeRules.map(\.id))
        #expect(groups.allSatisfy { $0.findings.isEmpty })
    }
}
