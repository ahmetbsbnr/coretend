// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

private extension RecoveryPlanCategory {
    /// How confidently usable this category is, ascending — used only for
    /// ordering, never displayed.
    var preferenceRank: Int {
        switch self {
        case .recommended: 0
        case .reviewRequired: 1
        case .optional: 2
        case .notIncluded: 3
        }
    }
}

/// The single deterministic ordering used both to sort candidates within a
/// section for display and to decide which `.recommended` candidates to
/// preselect first toward a goal. Explicit precedence, no numeric score:
/// risk (safer first) → category (more confidently usable first) →
/// confidence (more certain first) → bytes (larger first, fewer actions for
/// the same goal) → id (final tiebreak, so identical input always produces
/// identical output).
enum RecoveryPlanOrdering {
    static func isPreferred(_ lhs: RecoveryPlanCandidate, over rhs: RecoveryPlanCandidate) -> Bool {
        if lhs.finding.risk != rhs.finding.risk { return lhs.finding.risk < rhs.finding.risk }
        if lhs.category.preferenceRank != rhs.category.preferenceRank {
            return lhs.category.preferenceRank < rhs.category.preferenceRank
        }
        if lhs.finding.confidence != rhs.finding.confidence { return lhs.finding.confidence > rhs.finding.confidence }
        if lhs.reclaimableBytes != rhs.reclaimableBytes { return lhs.reclaimableBytes > rhs.reclaimableBytes }
        return lhs.id < rhs.id
    }
}

/// Builds an immutable `RecoveryPlan` from a flat candidate list and a goal.
/// No filesystem access, no scanning — pure arrangement of data already
/// computed by `RecoveryPlanService`.
enum RecoveryPlanBuilder {
    static func build(candidates: [RecoveryPlanCandidate], goal: RecoveryGoal,
                       preparedAt: Date = Date()) -> RecoveryPlan {
        let sections = RecoveryPlanCategory.allCases.map { category in
            RecoveryPlanSection(
                category: category,
                candidates: candidates.filter { $0.category == category }
                    .sorted { RecoveryPlanOrdering.isPreferred($0, over: $1) })
        }

        // Deterministic, explainable accumulation — never an exact-match
        // knapsack search: walk .recommended in preference order, stop once
        // the goal is met or exceeded. A goal of 0 (or negative — never
        // trusted from a raw text field without validation) preselects
        // nothing; there is nothing to "reach". reviewRequired/optional are
        // never preselected, regardless of goal size or how far short the
        // recommended total falls.
        var preselected: Set<String> = []
        if goal.bytes > 0 {
            var accumulated: Int64 = 0
            let recommended = sections.first { $0.category == .recommended }?.candidates ?? []
            for candidate in recommended {
                guard accumulated < goal.bytes else { break }
                preselected.insert(candidate.id)
                accumulated += candidate.reclaimableBytes
            }
        }

        return RecoveryPlan(goal: goal, preparedAt: preparedAt, sections: sections, preselectedIDs: preselected)
    }
}
