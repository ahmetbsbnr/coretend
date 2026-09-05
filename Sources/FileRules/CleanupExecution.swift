// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore
import SafetyCore

/// Shared Cleanup orchestration: rule-scoped approval -> SafetyCenter -> Trash
/// and audit sink. No filesystem mutation is implemented here.
public enum CleanupExecution {
    public struct Result: Sendable {
        public let executed: [ApprovedFileOperation]
        public let skippedCount: Int
        public var processedBytes: Int64 { executed.reduce(0) { $0 + $1.logicalSize } }
    }

    public static func execute(_ findings: [ScanFinding], home: URL,
                               excludedPaths: [String] = [], sink: SafetyAuditSink? = nil) async -> Result {
        var executed: [ApprovedFileOperation] = []
        var seen: Set<String> = []
        for finding in findings {
            guard !Task.isCancelled else { break }
            guard let rule = UserCleanupRules.all.first(where: { $0.id == finding.ruleID }),
                  seen.insert(finding.url.standardizedFileURL.path).inserted,
                  rule.matches?(finding.url) != false else { continue }
            let center = SafetyCenter(validator: PathValidator(
                allowedRoots: rule.roots(home),
                excludedRoots: rule.excludedRoots(home) + excludedPaths.map { URL(fileURLWithPath: $0) },
                regularFilesOnly: true), sink: sink)
            if let operation = try? await center.approve(url: finding.url, logicalSize: finding.logicalSize,
                                                        ruleID: rule.id, risk: rule.risk) {
                let result = await center.execute([operation])
                executed.append(contentsOf: result.executed)
            }
        }
        return Result(executed: executed, skippedCount: findings.count - executed.count)
    }
}
