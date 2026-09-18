// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SafetyCore
import Testing
@testable import CoreTendApp

/// A run where the user asked for something and nothing happened must say so.
///
/// `ExecutionOutcome` was built only from `SafetyCenter.ExecutionResult`, which
/// describes operations that reached execution. Paths the validator refused
/// were dropped one step earlier by `try? await center.approve(...)` and
/// appeared in no count at all — so forty files, every one refused, rendered as
/// "Moved 0 bytes to Trash" with no second line. Exactly the failure this type
/// exists to prevent, one stage upstream of where it was looking.
@Suite("Approval rejections are reported")
struct ApprovalRejectionTests {

    @Test func aRunWhereEverythingWasRefusedIsNotSilent() {
        let outcome = ExecutionOutcome(
            executedCount: 0, skippedCount: 0, movedToTrashBytes: 0,
            rejectedCount: 40, rejectionReasons: [.outsideAllowedRoots])
        #expect(outcome.hasRejections)
        #expect(outcome.didNothing)
        let message = try? #require(outcome.message)
        #expect(message != nil, "a run that did nothing produced no message")
    }

    /// The regression in its exact original shape: the old type had no notion
    /// of rejection, so `hasSkips` was false and `message` was nil.
    @Test func rejectionsAloneAreEnoughToProduceAMessage() {
        let outcome = ExecutionOutcome(
            executedCount: 0, skippedCount: 0, movedToTrashBytes: 0,
            rejectedCount: 3, rejectionReasons: [.protectedRoot("/System")])
        #expect(outcome.hasSkips == false)
        #expect(outcome.message != nil)
    }

    /// A completely clean run still says nothing. "0 refused" on every
    /// successful cleanup is noise, and noise is what hides the one run that
    /// did refuse something.
    @Test func aCleanRunStillProducesNoMessage() {
        let outcome = ExecutionOutcome(executedCount: 12, skippedCount: 0, movedToTrashBytes: 4096)
        #expect(outcome.message == nil)
        #expect(outcome.didNothing == false)
        #expect(outcome.hasRejections == false)
    }

    /// Skips and rejections are different events and are reported separately:
    /// refused before anything was attempted is not the same as re-validated
    /// away at the moment of acting.
    @Test func skipsAndRejectionsAreBothReported() {
        let outcome = ExecutionOutcome(
            executedCount: 5, skippedCount: 2, movedToTrashBytes: 1024,
            rejectedCount: 3, rejectionReasons: [.symlinkTraversal("/tmp/link")])
        let message = outcome.message ?? ""
        #expect(message.contains("2"), "the skip count is missing")
        #expect(message.contains("3"), "the rejection count is missing")
    }

    /// Forty files refused for one reason is one fact, not forty. The dominant
    /// reason leads.
    @Test func reasonsAreDeduplicatedAndOrderedByFrequency() async {
        // Through the real SafetyCenter rather than a synthesized result: its
        // ExecutionResult initializer is internal, and driving the actual
        // approval path is a stronger test anyway.
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [
            URL(fileURLWithPath: NSTemporaryDirectory())
        ]), sink: nil)
        let outside = URL(fileURLWithPath: "/Users/nobody/elsewhere/file")
        let protectedPath = URL(fileURLWithPath: "/System/Library/CoreServices/thing")
        let batch = await center.approveAll([
            ApprovalRequest(url: outside, logicalSize: 1, ruleID: "t", risk: .low),
            ApprovalRequest(url: protectedPath, logicalSize: 1, ruleID: "t", risk: .low),
            ApprovalRequest(url: outside, logicalSize: 1, ruleID: "t", risk: .low),
            ApprovalRequest(url: outside, logicalSize: 1, ruleID: "t", risk: .low),
        ])
        #expect(batch.approved.isEmpty, "none of these paths should be approvable")
        #expect(batch.rejections.count == 4, "approveAll dropped a refusal")

        let outcome = ExecutionOutcome(
            result: await center.execute(batch.approved), rejections: batch.rejections)
        #expect(outcome.rejectedCount == 4)
        #expect(outcome.rejectionReasons.count == 2, "reasons were not deduplicated")
        #expect(outcome.rejectionReasons.first == batch.rejections[0],
                "the most frequent reason is not first")
    }

    /// Every refusal the validator can produce has a sentence about the user's
    /// files. A missing case would render as a raw key in the one place the
    /// user is trying to understand what just happened.
    @Test func everyValidatorRefusalHasAnExplanation() {
        let every: [SafetyError] = [
            .emptyPath, .relativePath, .protectedRoot("/System"), .outsideAllowedRoots,
            .symlinkTraversal("/x"), .fileVanished, .permissionDenied,
            .trashFailed(domain: NSCocoaErrorDomain, code: 513),
        ]
        for error in every {
            let text = ExecutionOutcome.explain(error)
            #expect(!text.isEmpty)
            #expect(!text.hasPrefix("safety.reason."), "unlocalized: \(text)")
        }
    }

    /// The activity summary carries both counts, so the Activity view cannot
    /// show a partial run as a complete one.
    @Test func theActivitySummaryCarriesBothCounts() {
        let outcome = ExecutionOutcome(
            executedCount: 1, skippedCount: 2, movedToTrashBytes: 0,
            rejectedCount: 3, rejectionReasons: [.fileVanished])
        let summary = outcome.annotate("Cleanup")
        #expect(summary.contains("2 skipped"))
        #expect(summary.contains("3 refused"))
    }

    // MARK: - Structural

    /// `try? await center.approve(...)` is the shape that caused this. It is
    /// replaced by `approveAll`, whose return type cannot drop a refusal, and
    /// no call site may reintroduce it.
    @Test func noCallSiteDiscardsAnApprovalRefusal() throws {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/CoreTendApp")
        let names = try SourceTree.swiftFiles(under: dir)
            .filter { $0.hasSuffix(".swift") }
        for name in names {
            let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
            for line in text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Skip the doc comments that quote the old shape on purpose.
                guard !trimmed.hasPrefix("///") && !trimmed.hasPrefix("//") else { continue }
                #expect(!trimmed.contains("try? await center.approve"),
                        "\(name) discards an approval refusal — use approveAll")
            }
        }
    }
}
