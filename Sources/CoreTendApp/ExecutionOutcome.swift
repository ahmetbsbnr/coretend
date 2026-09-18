// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SafetyCore
import DesignSystem

/// What actually happened when approved operations ran, in the user's words.
///
/// `SafetyCenter.execute` returns `executed` **and** `skipped`, each skip
/// carrying the `SafetyError` that caused it. Every cleanup screen read only
/// `executed` and threw the rest away, so selecting ten files and having three
/// re-validated away at execution time produced "Moved 7 items to Trash" and
/// no hint that anything else happened. The only place the truth survived was
/// the Safety Log — a different screen the user has to know to go and find.
///
/// That matters more here than it would elsewhere. Skipping is not a bug: it
/// is SafetyCore refusing to act on a path that changed between approval and
/// execution, which is one of the product's central promises. A promise kept
/// silently reads exactly like a promise broken.
///
/// ## The half this type could not see
///
/// It was built from `SafetyCenter.ExecutionResult` alone, and that result only
/// describes operations that made it as far as execution. Every caller approved
/// like this:
///
/// ```swift
/// if let op = try? await center.approve(...) { approved.append(op) }
/// ```
///
/// A path the validator *rejects* — outside the allowed roots, inside a
/// protected root, a symlink out of the tree — is dropped by that `try?` and
/// never reaches `execute`. So a run where all forty selected files were
/// refused produced `executedCount == 0, skippedCount == 0`, therefore
/// `hasSkips == false`, therefore `message == nil`: "Moved 0 bytes to Trash"
/// and not one word about the other forty. Precisely the failure this type's
/// own doc comment says it exists to prevent, one step earlier in the pipeline.
///
/// Rejections are now counted, kept distinct from skips because they are a
/// different event — refused *before* anything was attempted, rather than
/// re-validated away at the moment of acting — and carry their reasons so the
/// screen can say which rule refused rather than only how many.
struct ExecutionOutcome: Equatable {
    let executedCount: Int
    /// Refused at execution time, after approval, because the path changed.
    let skippedCount: Int
    /// Refused at approval time: never attempted at all.
    let rejectedCount: Int
    let freedBytes: Int64
    /// Distinct reasons behind the rejections, most frequent first. Empty when
    /// nothing was rejected.
    let rejectionReasons: [SafetyError]

    var hasSkips: Bool { skippedCount > 0 }
    var hasRejections: Bool { rejectedCount > 0 }

    /// True when the user asked for something and none of it happened. This is
    /// the state that must never render as a quiet success.
    var didNothing: Bool { executedCount == 0 && (hasSkips || hasRejections) }

    init(result: SafetyCenter.ExecutionResult,
         rejections: [SafetyError] = []) {
        executedCount = result.executed.count
        skippedCount = result.skipped.count
        freedBytes = result.executed.reduce(0) { $0 + $1.logicalSize }
        rejectedCount = rejections.count
        // Ordered by frequency so the dominant reason is the one shown, and
        // deduplicated: forty files refused for the same reason is one fact.
        var counts: [SafetyError: Int] = [:]
        for reason in rejections { counts[reason, default: 0] += 1 }
        rejectionReasons = counts.sorted { $0.value > $1.value }.map(\.key)
    }

    /// Test seam: building one directly avoids constructing approved
    /// operations, which require a validator and real paths.
    init(executedCount: Int, skippedCount: Int, freedBytes: Int64,
         rejectedCount: Int = 0, rejectionReasons: [SafetyError] = []) {
        self.executedCount = executedCount
        self.skippedCount = skippedCount
        self.freedBytes = freedBytes
        self.rejectedCount = rejectedCount
        self.rejectionReasons = rejectionReasons
    }

    /// Headline for the success screen.
    var title: String {
        L("cleanup.done.moved", mcFormatBytes(freedBytes))
    }

    /// Second line, present only when something was skipped.
    ///
    /// Returns nil rather than an empty string so a clean run shows no message
    /// at all: "0 skipped" on every successful cleanup would be noise, and
    /// noise is what makes the one run that *did* skip something invisible.
    var message: String? {
        var lines: [String] = []
        if hasSkips { lines.append(L("cleanup.done.skipped", skippedCount)) }
        if hasRejections {
            lines.append(L("cleanup.done.rejected", rejectedCount))
            // One reason, not a list: the dominant one explains the run, and a
            // wall of validator vocabulary explains nothing.
            if let reason = rejectionReasons.first {
                lines.append(Self.explain(reason))
            }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// Turns a validator refusal into a sentence about the user's files rather
    /// than about the validator.
    static func explain(_ error: SafetyError) -> String {
        switch error {
        case .protectedRoot: L("safety.reason.protected_root")
        case .outsideAllowedRoots: L("safety.reason.outside_roots")
        case .symlinkTraversal: L("safety.reason.symlink")
        case .fileVanished: L("safety.reason.vanished")
        case .emptyPath, .relativePath: L("safety.reason.invalid_path")
        }
    }

    /// Appends the skip count to an activity summary.
    ///
    /// The summaries these screens store are hardcoded English rather than
    /// localized — they are written into the database and read back by the
    /// Activity view, so translating them properly means storing a key and its
    /// arguments instead of a sentence. That is a real gap and a separate
    /// change; this suffix deliberately matches the English around it rather
    /// than producing a half-translated line.
    func annotate(_ summary: String) -> String {
        var parts = [summary]
        if hasSkips { parts.append("\(skippedCount) skipped") }
        if hasRejections { parts.append("\(rejectedCount) refused") }
        return parts.joined(separator: " · ")
    }
}
