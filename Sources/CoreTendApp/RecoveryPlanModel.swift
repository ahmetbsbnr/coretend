// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SafetyCore

/// A user-supplied storage target, in bytes — never a formatted string, so
/// the whole model works in exact byte arithmetic.
struct RecoveryGoal: Sendable, Equatable {
    let bytes: Int64
    static let zero = RecoveryGoal(bytes: 0)
}

/// Why a candidate is not offered for automatic planning at all. Only ever
/// set alongside `.notIncluded` — a `.reviewRequired`/`.optional` candidate
/// is fully included, just not preselected, so it carries no exclusion
/// reason (its Advisor risk/confidence badges already explain the caution).
enum RecoveryPlanExclusionReason: String, Sendable, CaseIterable {
    /// The category matched nothing this scan (a real, distinct zero — not
    /// a stand-in for "couldn't compute").
    case noReclaimableBytes
    /// A pure inspection signal (`AdvisorReversibility.readOnly`) — there is
    /// nothing to plan.
    case readOnly
    /// The finding's reversibility is neither `.readOnly` nor `.trash`
    /// (`.irreversible`/`.partial`/`.restorableByCoreTend`) — Recovery Plan
    /// only ever proposes actions with a real, already-proven undo path.
    case destructiveActionUnavailable
    /// `AdvisorConfidence.uncertain` — not produced by any wired engine
    /// today, kept for when one might.
    case uncertainAssociation
    /// High risk is never used to reach a goal automatically, regardless of
    /// confidence — the user can still act on it from its own screen.
    case highRisk
    /// The candidate's engine isn't one Recovery Plan builds candidates
    /// from — not reachable today (every candidate comes from a wired
    /// engine by construction), kept for a future engine addition.
    case unsupportedSource
    /// This candidate's bytes structurally overlap another source's — see
    /// `RecoveryPlanService`'s "Anti-double-counting" note. Excluded rather
    /// than risking the same bytes counted twice toward one goal.
    case overlapsAnotherSource
}

/// Where a candidate lands in the review UI.
enum RecoveryPlanCategory: String, Sendable, CaseIterable, Identifiable {
    /// Low risk, high-or-better confidence, Trash-reversible — reasonable to
    /// preselect toward the goal.
    case recommended
    /// Valid and actionable, but needs a human decision Recovery Plan can't
    /// make for the user (which duplicate copy, a real association
    /// ambiguity) — included, never preselected.
    case reviewRequired
    /// Valid and Trash-reversible, but the product deliberately doesn't
    /// nudge the user toward it by default.
    case optional
    /// Not offered for planning; see `exclusionReason` for why.
    case notIncluded

    var id: String { rawValue }
}

/// One thing Recovery Plan can present — always built from a real
/// `AdvisorFinding` a wired engine actually produced this scan, never
/// invented data. `id` is the underlying finding's own id (already stable
/// across rescans of the same rule/group/profile — see `AdvisorFinding`).
struct RecoveryPlanCandidate: Identifiable, Sendable, Equatable {
    let id: String
    let finding: AdvisorFinding
    let category: RecoveryPlanCategory
    let exclusionReason: RecoveryPlanExclusionReason?

    var reclaimableBytes: Int64 { finding.reclaimableBytes ?? 0 }

    init(finding: AdvisorFinding, category: RecoveryPlanCategory, exclusionReason: RecoveryPlanExclusionReason? = nil) {
        self.id = finding.id
        self.finding = finding
        self.category = category
        self.exclusionReason = exclusionReason
    }
}

struct RecoveryPlanSection: Identifiable, Sendable {
    let category: RecoveryPlanCategory
    var id: RecoveryPlanCategory { category }
    let candidates: [RecoveryPlanCandidate]

    var totalBytes: Int64 { candidates.reduce(0) { $0 + $1.reclaimableBytes } }
}

/// One prepared scan-and-plan pass. Immutable — live user selection is
/// tracked separately by the view model (mirroring how CleanupViewModel/
/// DuplicatesViewModel already track selectedIDs/selectedPaths outside
/// their own immutable scan results).
struct RecoveryPlan: Sendable {
    let goal: RecoveryGoal
    let preparedAt: Date
    let sections: [RecoveryPlanSection]
    /// Candidate ids preselected to (approximately) reach `goal` — every one
    /// is `.recommended`; `.reviewRequired`/`.optional` are never preselected.
    let preselectedIDs: Set<String>

    var allCandidates: [RecoveryPlanCandidate] { sections.flatMap(\.candidates) }

    func section(_ category: RecoveryPlanCategory) -> RecoveryPlanSection {
        sections.first { $0.category == category } ?? RecoveryPlanSection(category: category, candidates: [])
    }

    /// Sum of every actionable candidate's bytes (everything except
    /// `.notIncluded`) — "potentially recoverable" for the summary header.
    var potentiallyRecoverableBytes: Int64 {
        RecoveryPlanCategory.allCases
            .filter { $0 != .notIncluded }
            .reduce(0) { $0 + section($1).totalBytes }
    }

    var isEmpty: Bool { allCandidates.isEmpty }
    var hasNoEligibleCandidates: Bool {
        RecoveryPlanCategory.allCases.filter { $0 != .notIncluded }.allSatisfy { section($0).candidates.isEmpty }
    }
}

/// The deterministic rule "is this finding eligible for Recovery Plan, and
/// which category does it land in?" — evaluated once per candidate,
/// structurally (never by parsing Advisor's display text).
enum RecoveryPlanEligibility {
    struct Result: Equatable {
        let category: RecoveryPlanCategory
        let exclusionReason: RecoveryPlanExclusionReason?
    }

    /// `overlapsAnotherSource`, when true, forces `.notIncluded` regardless
    /// of risk/confidence — set by `RecoveryPlanService` for sources it
    /// knows structurally double-count with another wired engine (see its
    /// "Anti-double-counting" note).
    static func evaluate(_ finding: AdvisorFinding, overlapsAnotherSource: Bool = false) -> Result {
        if overlapsAnotherSource {
            return Result(category: .notIncluded, exclusionReason: .overlapsAnotherSource)
        }
        guard let bytes = finding.reclaimableBytes, bytes > 0 else {
            return Result(category: .notIncluded, exclusionReason: .noReclaimableBytes)
        }
        guard finding.reversibility != .readOnly else {
            return Result(category: .notIncluded, exclusionReason: .readOnly)
        }
        guard finding.reversibility == .trash else {
            // .irreversible, .partial, .restorableByCoreTend: no engine
            // produces these today, but if one someday does, Recovery Plan
            // must not plan around an undo guarantee it hasn't verified.
            return Result(category: .notIncluded, exclusionReason: .destructiveActionUnavailable)
        }
        guard finding.confidence != .uncertain else {
            return Result(category: .notIncluded, exclusionReason: .uncertainAssociation)
        }
        guard finding.risk != .high else {
            // Still explainable in "Not included" — never silently dropped —
            // just never used to reach a goal automatically.
            return Result(category: .notIncluded, exclusionReason: .highRisk)
        }
        switch (finding.risk, finding.confidence) {
        case (.low, .exact), (.low, .high):
            return Result(category: .recommended, exclusionReason: nil)
        case (.low, .probable):
            // Low risk but a real, known ambiguity — conservative: review, not auto.
            return Result(category: .reviewRequired, exclusionReason: nil)
        case (.medium, .exact):
            // A verified identity (e.g. Duplicates' content hash) doesn't
            // remove the human decision "which copy do I keep" — always review.
            return Result(category: .reviewRequired, exclusionReason: nil)
        case (.medium, .probable):
            // A real, known ambiguity on top of medium risk (e.g. an
            // ambiguous Leftover) — review, never optional.
            return Result(category: .reviewRequired, exclusionReason: nil)
        case (.medium, .high):
            return Result(category: .optional, exclusionReason: nil)
        case (.high, _), (_, .uncertain):
            // Unreachable (guarded above) — kept so the switch stays exhaustive
            // without a `default:` masking a future new (risk, confidence) pair.
            return Result(category: .notIncluded, exclusionReason: .highRisk)
        }
    }
}
