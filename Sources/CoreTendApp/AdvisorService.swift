// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore
import SafetyCore
import FileRules
import AppDiscovery

/// Turns a scan/engine result into a structured, localized, deterministic
/// `AdvisorFinding`. Pure functions only — no I/O, no persistence, no
/// mutation, no network. `AdvisorServiceTests` asserts this stays true (no
/// method here can delete, move, or write anything).
///
/// This is the one place business rules like "which risk/confidence applies
/// to this kind of result" live — a View must never re-derive them (e.g.
/// `if result.path.contains("DerivedData") { risk = ... }`).
enum AdvisorService {
    // MARK: - Cleanup

    /// One finding per Cleanup rule group. `findings` share `ruleID` — this
    /// is the same grouping `CleanupViewModel.groups` already does; this
    /// function takes the raw findings rather than that view-model's nested
    /// type so it has no dependency on UI code.
    static func advise(ruleID: String, findings: [ScanFinding]) -> AdvisorFinding {
        let bytes = findings.reduce(Int64(0)) { $0 + $1.logicalSize }
        let rule = UserCleanupRules.all.first { $0.id == ruleID }
        // An unrecognized rule ID (a retired rule still referenced by old
        // data, or a future bug) must never be presented as confidently
        // low-risk just because that's a common default — fall back to a
        // conservative, honestly-labeled unknown state instead.
        let risk = rule?.risk ?? .medium
        let confidence: AdvisorConfidence = rule != nil ? .high : .uncertain
        let content = cleanupContent(ruleID: ruleID, isKnown: rule != nil)
        return AdvisorFinding(
            id: "cleanup.\(ruleID)",
            title: TimelineCategoryLabel.display(engine: "cleanup", category: ruleID),
            summary: content.summary,
            reason: content.reason,
            consequence: content.consequence,
            risk: risk,
            confidence: confidence,
            reversibility: .trash,
            reclaimableBytes: bytes,
            category: .cleanup,
            source: ruleID)
    }

    private struct CleanupContent { let summary: String; let reason: String; let consequence: String }

    private static func cleanupContent(ruleID: String, isKnown: Bool) -> CleanupContent {
        guard isKnown else {
            return CleanupContent(
                summary: L("advisor.cleanup.unknown.summary"),
                reason: L("advisor.cleanup.unknown.reason"),
                consequence: L("advisor.cleanup.unknown.consequence"))
        }
        return CleanupContent(
            summary: L("advisor.cleanup.\(ruleID).summary"),
            reason: L("advisor.cleanup.\(ruleID).reason"),
            consequence: L("advisor.cleanup.\(ruleID).consequence"))
    }

    // MARK: - Duplicates

    /// One finding per duplicate group. Confidence is `.exact` — the group
    /// was formed by a verified content hash, not a guess — but risk stays
    /// `.medium`: the user still has to choose which copy to keep, and
    /// Advisor never claims a copy is safe to remove without that review.
    static func advise(duplicateGroup group: DuplicateGroup) -> AdvisorFinding {
        AdvisorFinding(
            id: "duplicates.\(group.id)",
            title: TimelineCategoryLabel.display(engine: "duplicates", category: "wastedSpace"),
            summary: L("advisor.duplicates.summary"),
            reason: L("advisor.duplicates.reason"),
            consequence: L("advisor.duplicates.consequence"),
            risk: .medium,
            confidence: .exact,
            reversibility: .trash,
            reclaimableBytes: group.wastedBytes,
            category: .duplicates,
            source: "duplicateEngine",
            recommendation: L("advisor.duplicates.recommendation"))
    }

    // MARK: - Leftovers

    /// One finding per leftover candidate. `isAmbiguous` must come from the
    /// same signal already shown in the UI (`LeftoversViewModel.isAmbiguous`)
    /// — a `group.`-prefixed container, or a vendor prefix shared by more
    /// than one leftover — never re-derived here from scratch.
    static func advise(leftover item: AssociatedItem, isAmbiguous: Bool) -> AdvisorFinding {
        advise(leftoversID: "leftovers.\(item.id)", bytes: item.sizeBytes, isAmbiguous: isAmbiguous)
    }

    /// The aggregate across every leftover candidate sharing one ambiguity
    /// classification — used where a plan-level view (Recovery Plan) needs
    /// one line per classification rather than one per item, while still
    /// keeping the ambiguous/non-ambiguous confidence split Leftovers itself
    /// already makes. `items` must already be filtered to one classification;
    /// this never re-derives ambiguity.
    static func advise(leftovers items: [AssociatedItem], isAmbiguous: Bool) -> AdvisorFinding {
        let bytes = items.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return advise(leftoversID: "leftovers.aggregate.\(isAmbiguous ? "ambiguous" : "exact")",
                       bytes: bytes, isAmbiguous: isAmbiguous)
    }

    private static func advise(leftoversID: String, bytes: Int64, isAmbiguous: Bool) -> AdvisorFinding {
        AdvisorFinding(
            id: leftoversID,
            title: TimelineCategoryLabel.display(engine: "leftovers", category: "applicationData"),
            summary: L("advisor.leftovers.summary"),
            reason: L(isAmbiguous ? "advisor.leftovers.reason.ambiguous" : "advisor.leftovers.reason.exact"),
            consequence: L("advisor.leftovers.consequence"),
            risk: .medium,
            confidence: isAmbiguous ? .probable : .high,
            reversibility: .trash,
            reclaimableBytes: bytes,
            category: .leftovers,
            source: "bundleIdFormatMatch",
            recommendation: isAmbiguous ? L("advisor.leftovers.recommendation.ambiguous") : nil)
    }

    // MARK: - Privacy

    /// One finding per browser profile — the same granularity
    /// `PrivacyCleanerView` already lists (unlike Timeline's Privacy scope,
    /// which aggregates by browser for long-term storage; Advisor explains
    /// what's on screen right now). `notRemoved` states exactly what this
    /// product does today (cache-only cleaning) — never a generic privacy
    /// claim broader than the real behavior.
    static func advise(browserProfile profile: BrowserProfile) -> AdvisorFinding {
        advise(privacyID: "privacy.\(profile.id)", title: profile.browser, bytes: profile.cacheBytes)
    }

    /// The aggregate across every detected browser profile — one line for a
    /// plan-level view instead of one per browser. Title is generic
    /// ("Browser caches"), not a specific browser's proper noun, since it no
    /// longer names just one.
    static func advise(browserProfiles profiles: [BrowserProfile]) -> AdvisorFinding {
        let bytes = profiles.reduce(Int64(0)) { $0 + $1.cacheBytes }
        return advise(privacyID: "privacy.aggregate", title: L("advisor.privacy.aggregate_title"), bytes: bytes)
    }

    private static func advise(privacyID: String, title: String, bytes: Int64) -> AdvisorFinding {
        AdvisorFinding(
            id: privacyID,
            title: title,
            summary: L("advisor.privacy.summary"),
            reason: L("advisor.privacy.reason"),
            consequence: L("advisor.privacy.consequence"),
            risk: .low,
            confidence: .high,
            reversibility: .trash,
            reclaimableBytes: bytes,
            category: .privacy,
            source: title,
            notRemoved: [L("advisor.privacy.not_removed.history"), L("advisor.privacy.not_removed.cookies")])
    }
}
