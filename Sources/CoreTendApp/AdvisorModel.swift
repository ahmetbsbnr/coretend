// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SafetyCore

/// How certain CoreTend is that this finding's category or association is
/// correct — independent of `RiskLevel`, which is about the danger of
/// *acting* on a correct finding, not about how sure CoreTend is that the
/// finding is correct in the first place. A browser cache can be
/// `risk: .low, confidence: .exact`; a leftover match by a shared vendor
/// prefix can be `risk: .medium, confidence: .probable` — the two axes move
/// independently.
enum AdvisorConfidence: String, Sendable, CaseIterable, Comparable {
    /// A verified identity match: a bundle identifier read from a live
    /// Info.plist, or a cryptographic content hash. Not a guess.
    case exact
    /// A deterministic rule/pattern match (a fixed path, a fixed file
    /// extension, a fixed age threshold) — reliable, but not an identity
    /// proof the way `.exact` is.
    case high
    /// A heuristic match with a known, real ambiguity (e.g. a vendor prefix
    /// shared by more than one leftover, or a `group.`-prefixed container
    /// that Apple's own convention marks as shared across an app family).
    case probable
    /// Reserved for a weaker heuristic no current engine actually produces
    /// (e.g. fuzzy name matching, deliberately not implemented anywhere in
    /// CoreTend today).
    case uncertain

    private var rank: Int {
        switch self {
        case .exact: 3
        case .high: 2
        case .probable: 1
        case .uncertain: 0
        }
    }

    static func < (lhs: AdvisorConfidence, rhs: AdvisorConfidence) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Whether, and how, an action can be undone — using only guarantees the
/// product actually provides today. In particular, never `.restorableByCoreTend`
/// merely because a Restore Center is planned: that case exists for when one
/// is real, and no `AdvisorService` mapping produces it yet
/// (`AdvisorServiceTests` asserts this).
enum AdvisorReversibility: String, Sendable, CaseIterable {
    /// Nothing is changed — this is inspection only, nothing to reverse.
    case readOnly
    /// Moved to the macOS Trash by `SafetyCenter.execute` — recoverable there
    /// until the user empties it. This is how every current CoreTend
    /// deletion works; there is no `rm`-equivalent path anywhere.
    case trash
    /// CoreTend itself can restore the exact prior state (a real Restore
    /// Center manifest, not merely "it's in the Trash"). Not produced by any
    /// current engine.
    case restorableByCoreTend
    /// Part of the action is reversible (e.g. Trash) and part is not.
    case partial
    /// No recovery path exists once performed.
    case irreversible
}

/// A deterministic, localized, structured explanation of one scan result —
/// produced by `AdvisorService`, never a mutation, never a network call,
/// never dynamically generated text. Every field is either copied from a
/// verified domain value (a `RiskLevel`, a byte count) or looked up from
/// `Localizable.strings` by a stable key — nothing here is templated from
/// unverified input.
struct AdvisorFinding: Sendable, Identifiable, Equatable {
    /// Stable across repeated scans of the same thing (a rule ID, a content
    /// hash, a browser+profile pair) — never a random UUID — so UI list
    /// identity and tests can both rely on it.
    let id: String
    /// Short display name — already localized (e.g. via
    /// `TimelineCategoryLabel`, or the source's own display name for a
    /// proper noun like a browser).
    let title: String
    /// One compact line for the collapsed/list state.
    let summary: String
    /// The fuller "why CoreTend flagged this" explanation, for the expanded
    /// or full-detail state.
    let reason: String
    /// What happens functionally if the user acts on this (never a
    /// restatement of `reversibility` — that's its own field).
    let consequence: String
    let risk: RiskLevel
    let confidence: AdvisorConfidence
    let reversibility: AdvisorReversibility
    /// nil when not applicable (a pure read-only signal with nothing to
    /// reclaim); 0 is a real, distinct value (a category that matched
    /// nothing this scan) and must never be confused with nil.
    let reclaimableBytes: Int64?
    /// Coarse grouping — reuses `TimelineScope` rather than inventing a
    /// second categorization scheme for the same four engines.
    let category: TimelineScope
    /// Stable, machine-identifiable origin (a Cleanup rule ID, "wastedSpace",
    /// a leftover matching method, a browser name) — never a file path, so
    /// nothing here needs redaction to be safe to log or test against.
    let source: String
    /// A cautious next step, only when one is genuinely warranted (e.g.
    /// Duplicates' "review which copy to keep"). nil when the finding needs
    /// no extra caution beyond its risk/confidence already shown.
    let recommendation: String?
    /// What CoreTend explicitly does *not* touch, when relevant (e.g.
    /// Privacy Cleaner: browsing history, cookies). Empty when not
    /// applicable — never inflated with items the product doesn't actually
    /// track just to look thorough.
    let notRemoved: [String]

    init(id: String, title: String, summary: String, reason: String, consequence: String,
         risk: RiskLevel, confidence: AdvisorConfidence, reversibility: AdvisorReversibility,
         reclaimableBytes: Int64?, category: TimelineScope, source: String,
         recommendation: String? = nil, notRemoved: [String] = []) {
        self.id = id
        self.title = title
        self.summary = summary
        self.reason = reason
        self.consequence = consequence
        self.risk = risk
        self.confidence = confidence
        self.reversibility = reversibility
        self.reclaimableBytes = reclaimableBytes
        self.category = category
        self.source = source
        self.recommendation = recommendation
        self.notRemoved = notRemoved
    }
}
