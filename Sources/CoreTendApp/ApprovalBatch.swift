// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SafetyCore

/// Approving many paths at once, keeping the refusals.
///
/// Six screens wrote the same loop:
///
/// ```swift
/// for item in selected {
///     if let op = try? await center.approve(...) { approved.append(op) }
/// }
/// ```
///
/// That `try?` is where the bug lived. A path the validator refuses — outside
/// the allowed roots, inside a protected root, a symlink pointing out of the
/// tree — is discarded by it and never reaches `execute`, so it appears in no
/// result and no count. A user who selected forty files and had every one of
/// them refused saw "Moved 0 bytes to Trash" and nothing else.
///
/// The loop is written once here, it cannot discard a refusal because the
/// refusal is part of its return type, and there is no longer a `try?` at any
/// of the six call sites for a future edit to reintroduce.
struct ApprovalRequest {
    let url: URL
    let logicalSize: Int64
    let ruleID: String
    let risk: RiskLevel

    init(url: URL, logicalSize: Int64, ruleID: String, risk: RiskLevel) {
        self.url = url
        self.logicalSize = logicalSize
        self.ruleID = ruleID
        self.risk = risk
    }
}

struct ApprovalBatch {
    let approved: [ApprovedFileOperation]
    /// One entry per refusal, in request order. Feeds `ExecutionOutcome` so the
    /// user is told how many were refused and why.
    let rejections: [SafetyError]

    var isEmpty: Bool { approved.isEmpty && rejections.isEmpty }
}

extension SafetyCenter {
    /// Approves every request, keeping refusals rather than dropping them.
    ///
    /// Deliberately sequential: `approve` writes an audit row per path, and the
    /// Safety Log is an ordered account of what the app decided. Fanning these
    /// out would reorder that account for no useful gain — validation is a
    /// handful of path operations, not I/O worth parallelising.
    func approveAll(_ requests: [ApprovalRequest]) async -> ApprovalBatch {
        var approved: [ApprovedFileOperation] = []
        var rejections: [SafetyError] = []
        for request in requests {
            do throws(SafetyError) {
                approved.append(try await approve(
                    url: request.url,
                    logicalSize: request.logicalSize,
                    ruleID: request.ruleID,
                    risk: request.risk))
            } catch {
                rejections.append(error)
            }
        }
        return ApprovalBatch(approved: approved, rejections: rejections)
    }
}
