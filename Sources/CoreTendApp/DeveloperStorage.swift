// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore
import FileRules

/// Presentation over Cleanup findings, not another storage or risk taxonomy.
/// IDs remain Cleanup rule IDs throughout Advisor, selection and execution.
enum DeveloperStorage {
    static let xcodeRules = [UserCleanupRules.xcodeDerivedData, UserCleanupRules.xcodeArchives,
                             UserCleanupRules.xcodeDeviceSupport]
    static var rules: [ScanRule] { xcodeRules + PackageCacheRules.all }

    struct Group: Identifiable, Sendable {
        let ruleID: String
        let findings: [ScanFinding]
        var id: String { ruleID }
        let advisor: AdvisorFinding
        let logicalBytes: Int64
        let allocatedBytes: Int64?

        init(ruleID: String, findings: [ScanFinding]) {
            self.ruleID = ruleID
            self.findings = findings
            self.advisor = AdvisorService.advise(ruleID: ruleID, findings: findings)
            self.logicalBytes = findings.reduce(0) { $0 + $1.logicalSize }
            self.allocatedBytes = findings.totalAllocatedSizeIfFullyKnown
        }

        /// Uses the scan's existing paths, never another filesystem walk or a
        /// guessed project name. Names are literal first-level folder names.
        func breakdown(under root: URL) -> [FolderTotal] {
            var totals: [String: Int64] = [:]
            let prefix = root.standardizedFileURL.path + "/"
            for finding in findings where finding.url.standardizedFileURL.path.hasPrefix(prefix) {
                let relative = String(finding.url.standardizedFileURL.path.dropFirst(prefix.count))
                let name = relative.split(separator: "/").first.map(String.init) ?? relative
                totals[name, default: 0] += finding.logicalSize
            }
            return totals.map { FolderTotal(name: $0.key, logicalBytes: $0.value) }
                .sorted { $0.logicalBytes == $1.logicalBytes ? $0.name < $1.name : $0.logicalBytes > $1.logicalBytes }
        }
    }

    struct FolderTotal: Identifiable, Sendable {
        let name: String
        let logicalBytes: Int64
        var id: String { name }
    }

    static func groups(findings: [ScanFinding]) -> [Group] {
        let byRule = Dictionary(grouping: findings, by: \.ruleID)
        return rules.map { Group(ruleID: $0.id, findings: byRule[$0.id] ?? []) }
    }
}
