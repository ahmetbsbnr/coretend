// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import SafetyCore
@testable import CoreTendApp

private func finding(bytes: Int64? = 1_000, risk: RiskLevel = .low, confidence: AdvisorConfidence = .high,
                      reversibility: AdvisorReversibility = .trash, id: String = "x") -> AdvisorFinding {
    AdvisorFinding(id: id, title: "t", summary: "s", reason: "r", consequence: "c", risk: risk,
                   confidence: confidence, reversibility: reversibility, reclaimableBytes: bytes,
                   category: .cleanup, source: "test")
}

@Suite("RecoveryPlanEligibility")
struct RecoveryPlanEligibilityTests {
    @Test func lowRiskHighOrExactConfidenceIsRecommended() {
        #expect(RecoveryPlanEligibility.evaluate(finding(risk: .low, confidence: .high)).category == .recommended)
        #expect(RecoveryPlanEligibility.evaluate(finding(risk: .low, confidence: .exact)).category == .recommended)
    }

    @Test func zeroOrMissingBytesIsNotIncluded() {
        let zero = RecoveryPlanEligibility.evaluate(finding(bytes: 0))
        #expect(zero.category == .notIncluded)
        #expect(zero.exclusionReason == .noReclaimableBytes)
        let missing = RecoveryPlanEligibility.evaluate(finding(bytes: nil))
        #expect(missing.category == .notIncluded)
        #expect(missing.exclusionReason == .noReclaimableBytes)
    }

    @Test func readOnlyIsNotIncludedWithItsOwnReason() {
        let result = RecoveryPlanEligibility.evaluate(finding(reversibility: .readOnly))
        #expect(result.category == .notIncluded)
        #expect(result.exclusionReason == .readOnly)
    }

    @Test func nonTrashNonReadOnlyReversibilityIsNotIncluded() {
        for reversibility: AdvisorReversibility in [.irreversible, .partial, .restorableByCoreTend] {
            let result = RecoveryPlanEligibility.evaluate(finding(reversibility: reversibility))
            #expect(result.category == .notIncluded)
            #expect(result.exclusionReason == .destructiveActionUnavailable)
        }
    }

    @Test func uncertainConfidenceIsNotIncluded() {
        let result = RecoveryPlanEligibility.evaluate(finding(confidence: .uncertain))
        #expect(result.category == .notIncluded)
        #expect(result.exclusionReason == .uncertainAssociation)
    }

    @Test func highRiskIsNeverUsedAutomaticallyRegardlessOfConfidence() {
        // .uncertain is excluded from this loop: uncertain confidence is
        // checked first and reported as .uncertainAssociation regardless of
        // risk (covered by uncertainConfidenceIsNotIncluded above) — this
        // test is about risk being the reason for every *trusted* confidence.
        for confidence: AdvisorConfidence in [.exact, .high, .probable] {
            let result = RecoveryPlanEligibility.evaluate(finding(risk: .high, confidence: confidence))
            #expect(result.category == .notIncluded, "\(confidence)")
            #expect(result.exclusionReason == .highRisk, "\(confidence)")
        }
    }

    @Test func mediumRiskIsNeverRecommendedRegardlessOfConfidence() {
        for confidence: AdvisorConfidence in [.exact, .high, .probable] {
            let result = RecoveryPlanEligibility.evaluate(finding(risk: .medium, confidence: confidence))
            #expect(result.category != .recommended, "\(confidence)")
        }
    }

    @Test func exactConfidenceMediumRiskAlwaysRequiresReview() {
        // This is Duplicates' exact shape: verified identity, but the user
        // still has to choose which copy to keep.
        let result = RecoveryPlanEligibility.evaluate(finding(risk: .medium, confidence: .exact))
        #expect(result.category == .reviewRequired)
    }

    @Test func probableConfidenceAlwaysRequiresReviewRegardlessOfRisk() {
        #expect(RecoveryPlanEligibility.evaluate(finding(risk: .low, confidence: .probable)).category == .reviewRequired)
        #expect(RecoveryPlanEligibility.evaluate(finding(risk: .medium, confidence: .probable)).category == .reviewRequired)
    }

    @Test func mediumRiskHighConfidenceIsOptionalNotHiddenNotPushed() {
        let result = RecoveryPlanEligibility.evaluate(finding(risk: .medium, confidence: .high))
        #expect(result.category == .optional)
        #expect(result.exclusionReason == nil, "optional is not an exclusion")
    }

    @Test func overlapFlagForcesNotIncludedRegardlessOfOtherwiseFavorableRiskAndConfidence() {
        // Even the most favorable possible finding (low risk, exact
        // confidence) must never leak into an automatic plan once flagged
        // as overlapping another source.
        let result = RecoveryPlanEligibility.evaluate(finding(risk: .low, confidence: .exact), overlapsAnotherSource: true)
        #expect(result.category == .notIncluded)
        #expect(result.exclusionReason == .overlapsAnotherSource)
    }
}

@Suite("RecoveryPlanBuilder — goal")
struct RecoveryPlanBuilderGoalTests {
    private func candidate(id: String, bytes: Int64, risk: RiskLevel = .low,
                            confidence: AdvisorConfidence = .high) -> RecoveryPlanCandidate {
        let f = finding(bytes: bytes, risk: risk, confidence: confidence, id: id)
        let eligibility = RecoveryPlanEligibility.evaluate(f)
        return RecoveryPlanCandidate(finding: f, category: eligibility.category, exclusionReason: eligibility.exclusionReason)
    }

    @Test func zeroGoalPreselectsNothing() {
        let candidates = [candidate(id: "a", bytes: 1_000)]
        let plan = RecoveryPlanBuilder.build(candidates: candidates, goal: .zero)
        #expect(plan.preselectedIDs.isEmpty)
    }

    @Test func exactMatchStopsAfterReachingTheGoal() {
        let candidates = [candidate(id: "a", bytes: 1_000), candidate(id: "b", bytes: 1_000), candidate(id: "c", bytes: 1_000)]
        let plan = RecoveryPlanBuilder.build(candidates: candidates, goal: RecoveryGoal(bytes: 2_000))
        #expect(plan.preselectedIDs.count == 2, "stops once the goal is met, never over-preselects")
    }

    @Test func goalUnderTotalPreselectsOnlyWhatsNeeded() {
        let candidates = [candidate(id: "a", bytes: 5_000)]
        let plan = RecoveryPlanBuilder.build(candidates: candidates, goal: RecoveryGoal(bytes: 100))
        #expect(plan.preselectedIDs == ["a"])
    }

    @Test func goalOverTotalPreselectsEverythingRecommendedWithoutCrashing() {
        let candidates = [candidate(id: "a", bytes: 1_000), candidate(id: "b", bytes: 1_000)]
        let plan = RecoveryPlanBuilder.build(candidates: candidates, goal: RecoveryGoal(bytes: 1_000_000_000))
        #expect(plan.preselectedIDs == ["a", "b"])
        #expect(plan.potentiallyRecoverableBytes == 2_000)
    }

    @Test func veryLargeGoalNeverOverflows() {
        let candidates = [candidate(id: "a", bytes: Int64.max / 2)]
        let plan = RecoveryPlanBuilder.build(candidates: candidates, goal: RecoveryGoal(bytes: .max))
        #expect(plan.preselectedIDs == ["a"])
    }

    @Test func reviewRequiredAndOptionalAreNeverPreselectedRegardlessOfGoalSize() {
        let review = candidate(id: "r", bytes: 10_000, risk: .medium, confidence: .exact)
        let optional = candidate(id: "o", bytes: 10_000, risk: .medium, confidence: .high)
        let plan = RecoveryPlanBuilder.build(candidates: [review, optional], goal: RecoveryGoal(bytes: 1_000_000))
        #expect(plan.preselectedIDs.isEmpty)
        #expect(plan.section(.reviewRequired).candidates.map(\.id) == ["r"])
        #expect(plan.section(.optional).candidates.map(\.id) == ["o"])
    }

    @Test func noCandidatesAtAllIsAnEmptyPlanNotAnError() {
        let plan = RecoveryPlanBuilder.build(candidates: [], goal: RecoveryGoal(bytes: 20_000_000_000))
        #expect(plan.isEmpty)
        #expect(plan.hasNoEligibleCandidates)
        #expect(plan.potentiallyRecoverableBytes == 0)
        #expect(plan.preselectedIDs.isEmpty)
    }

    @Test func onlyReviewRequiredCandidatesStillReportsThemNotAsEmpty() {
        let review = candidate(id: "r", bytes: 10_000, risk: .medium, confidence: .exact)
        let plan = RecoveryPlanBuilder.build(candidates: [review], goal: RecoveryGoal(bytes: 5_000))
        #expect(!plan.isEmpty)
        #expect(!plan.hasNoEligibleCandidates)
        #expect(plan.preselectedIDs.isEmpty, "review-required is never auto-selected even though it could meet the goal alone")
    }
}

@Suite("RecoveryPlanBuilder — ordering")
struct RecoveryPlanBuilderOrderingTests {
    @Test func sameInputAlwaysProducesTheSameOrder() {
        let f1 = finding(bytes: 500, id: "a")
        let f2 = finding(bytes: 500, id: "b")
        let candidates = [f1, f2].map { f in
            let e = RecoveryPlanEligibility.evaluate(f)
            return RecoveryPlanCandidate(finding: f, category: e.category, exclusionReason: e.exclusionReason)
        }
        let first = RecoveryPlanBuilder.build(candidates: candidates, goal: .zero).section(.recommended).candidates.map(\.id)
        let second = RecoveryPlanBuilder.build(candidates: candidates.reversed(), goal: .zero)
            .section(.recommended).candidates.map(\.id)
        #expect(first == second, "input order must not affect the built plan's order")
    }

    @Test func largerBytesSortsFirstWithinTheSameRiskAndConfidence() {
        let small = finding(bytes: 100, id: "small")
        let large = finding(bytes: 900, id: "large")
        let candidates = [small, large].map { f in
            let e = RecoveryPlanEligibility.evaluate(f)
            return RecoveryPlanCandidate(finding: f, category: e.category, exclusionReason: e.exclusionReason)
        }
        let ordered = RecoveryPlanBuilder.build(candidates: candidates, goal: .zero).section(.recommended).candidates
        #expect(ordered.map(\.id) == ["large", "small"])
    }

    @Test func lowerRiskSortsBeforeHigherRiskAcrossSections() {
        let low = finding(bytes: 100, risk: .low, confidence: .high, id: "low")
        let medium = finding(bytes: 100_000, risk: .medium, confidence: .high, id: "medium")
        let candidates = [low, medium].map { f in
            let e = RecoveryPlanEligibility.evaluate(f)
            return RecoveryPlanCandidate(finding: f, category: e.category, exclusionReason: e.exclusionReason)
        }
        let plan = RecoveryPlanBuilder.build(candidates: candidates, goal: .zero)
        // low lands in .recommended, medium in .optional — verifies risk
        // gates the category boundary even though medium has far more bytes.
        #expect(plan.section(.recommended).candidates.map(\.id) == ["low"])
        #expect(plan.section(.optional).candidates.map(\.id) == ["medium"])
    }
}
