// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SafetyCore
import DesignSystem

/// Approves a reviewed batch while retaining paths refused during validation.
/// Refusals happen before `execute`, so callers must carry this count into the
/// visible outcome instead of silently shrinking the selected batch.
struct OperationApprovalBatch {
    struct Candidate {
        let url: URL
        let logicalSize: Int64
        let ruleID: String
        let risk: RiskLevel
    }

    let operations: [ApprovedFileOperation]
    let failureCount: Int

    static func approve(_ candidates: [Candidate], through center: SafetyCenter) async -> Self {
        var operations: [ApprovedFileOperation] = []
        var failureCount = 0
        for candidate in candidates {
            do {
                operations.append(try await center.approve(
                    url: candidate.url, logicalSize: candidate.logicalSize,
                    ruleID: candidate.ruleID, risk: candidate.risk
                ))
            } catch {
                failureCount += 1
            }
        }
        return Self(operations: operations, failureCount: failureCount)
    }
}

/// What actually happened when approved operations ran, in the user's words.
///
/// `SafetyCenter.execute` returns `executed` **and** `skipped`, while batch
/// approval separately counts candidates refused by path validation. Keeping
/// both counts prevents a partially completed selection from reading as a
/// fully successful batch. The Safety Log remains the place to inspect causes.
///
/// That matters more here than it would elsewhere. Skipping is not a bug: it
/// is SafetyCore refusing to act on a path that changed between approval and
/// execution, which is one of the product's central promises. A promise kept
/// silently reads exactly like a promise broken.
struct ExecutionOutcome: Equatable {
    let executedCount: Int
    let skippedCount: Int
    let approvalFailureCount: Int
    let freedBytes: Int64

    var hasSkips: Bool { skippedCount + approvalFailureCount > 0 }
    var uncompletedCount: Int { skippedCount + approvalFailureCount }

    init(result: SafetyCenter.ExecutionResult, approvalFailureCount: Int = 0) {
        executedCount = result.executed.count
        skippedCount = result.skipped.count
        self.approvalFailureCount = approvalFailureCount
        freedBytes = result.executed.reduce(0) { $0 + $1.logicalSize }
    }

    /// Test seam: building one directly avoids constructing approved
    /// operations, which require a validator and real paths.
    init(executedCount: Int, skippedCount: Int, approvalFailureCount: Int = 0, freedBytes: Int64) {
        self.executedCount = executedCount
        self.skippedCount = skippedCount
        self.approvalFailureCount = approvalFailureCount
        self.freedBytes = freedBytes
    }

    /// Headline for the success screen.
    var title: String {
        L("cleanup.done.moved", mcFormatBytes(freedBytes))
    }

    /// Second line, present only when an item was not moved.
    ///
    /// Returns nil rather than an empty string so a clean run shows no message
    /// at all: "0 skipped" on every successful cleanup would be noise, and
    /// noise is what makes the one run that *did* skip something invisible.
    var message: String? {
        guard hasSkips else { return nil }
        return L("cleanup.done.skipped", uncompletedCount)
    }

    /// Appends the not-moved count to an activity summary.
    ///
    /// The summaries these screens store are hardcoded English rather than
    /// localized — they are written into the database and read back by the
    /// Activity view, so translating them properly means storing a key and its
    /// arguments instead of a sentence. That is a real gap and a separate
    /// change; this suffix deliberately matches the English around it rather
    /// than producing a half-translated line.
    func annotate(_ summary: String) -> String {
        hasSkips ? "\(summary) · \(uncompletedCount) not moved" : summary
    }
}
