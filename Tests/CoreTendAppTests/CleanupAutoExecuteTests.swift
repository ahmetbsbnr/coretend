// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
import SafetyCore
import FileRules

/// The safety-critical invariant that outlived the retired standalone Smart
/// Care view: any automated flow may only ever act, without a per-item review,
/// on reversible low-risk preselected findings. The medium/high-risk cleanup
/// rules must be structurally incapable of being auto-cleaned, both at the
/// finding-filter level and at the rule-catalog level.
@Suite("Cleanup auto-execute selection")
struct CleanupAutoExecuteTests {
    private func finding(risk: RiskLevel, preselected: Bool, size: Int64 = 100) -> ScanFinding {
        ScanFinding(
            url: URL(fileURLWithPath: "/tmp/x-\(UUID().uuidString)"),
            logicalSize: size, allocatedSize: nil, modificationDate: nil,
            ruleID: "test", category: "test", explanation: "test",
            confidence: 1.0, risk: risk, preselected: preselected)
    }

    @Test("only low-risk AND preselected findings are auto-executable")
    func onlyLowAndPreselected() {
        let mixed = [
            finding(risk: .low, preselected: true),      // ✓ keep
            finding(risk: .low, preselected: false),     // skip — not preselected
            finding(risk: .medium, preselected: true),   // skip — medium, even if preselected
            finding(risk: .high, preselected: true),     // skip — high
            finding(risk: .medium, preselected: false),  // skip
            finding(risk: .high, preselected: false),    // skip
        ]
        let selected = UserCleanupRules.autoExecutable(mixed)
        #expect(selected.count == 1)
        #expect(selected.allSatisfy { $0.risk == .low && $0.preselected })
    }

    @Test("empty and all-ineligible inputs select nothing")
    func nothingWhenIneligible() {
        #expect(UserCleanupRules.autoExecutable([]).isEmpty)
        let ineligible = [finding(risk: .medium, preselected: true),
                          finding(risk: .high, preselected: true),
                          finding(risk: .low, preselected: false)]
        #expect(UserCleanupRules.autoExecutable(ineligible).isEmpty)
    }
}

/// Catalog-level guarantee tying the abstract filter to the real rules: a
/// normal scan can never hand an automated flow a preselected medium/high
/// finding, because no such rule exists. If someone adds a preselected risky
/// rule, this fails loudly.
@Suite("Cleanup rule catalog risk/preselect invariant")
struct CleanupRuleCatalogTests {
    @Test("every preselected rule is low-risk")
    func preselectedImpliesLowRisk() {
        for rule in UserCleanupRules.all where rule.preselect {
            #expect(rule.risk == .low, "rule \(rule.id) is preselected but risk \(rule.risk)")
        }
    }

    @Test("every medium/high-risk rule is not preselected")
    func riskyRulesAreNeverPreselected() {
        for rule in UserCleanupRules.all where rule.risk != .low {
            #expect(!rule.preselect, "rule \(rule.id) is risk \(rule.risk) but preselected")
        }
    }

    @Test("the new installer/archive/Xcode rules are present, medium-risk, unchecked")
    func newRulesAreUncheckedMediumRisk() {
        let newIDs = ["user.oldinstallers", "user.oldarchives", "dev.xcode.archives"]
        for id in newIDs {
            let rule = UserCleanupRules.all.first { $0.id == id }
            #expect(rule != nil, "missing rule \(id)")
            #expect(rule?.risk == .medium)
            #expect(rule?.preselect == false)
        }
    }
}
