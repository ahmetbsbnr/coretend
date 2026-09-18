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
struct ExecutionOutcome: Equatable {
    let executedCount: Int
    let skippedCount: Int
    let freedBytes: Int64

    var hasSkips: Bool { skippedCount > 0 }

    init(result: SafetyCenter.ExecutionResult) {
        executedCount = result.executed.count
        skippedCount = result.skipped.count
        freedBytes = result.executed.reduce(0) { $0 + $1.logicalSize }
    }

    /// Test seam: building one directly avoids constructing approved
    /// operations, which require a validator and real paths.
    init(executedCount: Int, skippedCount: Int, freedBytes: Int64) {
        self.executedCount = executedCount
        self.skippedCount = skippedCount
        self.freedBytes = freedBytes
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
        guard hasSkips else { return nil }
        return L("cleanup.done.skipped", skippedCount)
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
        hasSkips ? "\(summary) · \(skippedCount) skipped" : summary
    }
}
