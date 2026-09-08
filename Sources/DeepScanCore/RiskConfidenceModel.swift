// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// RiskConfidenceModel — the ONLY place risk/confidence/default-selection is
// decided. Fully deterministic: no LLM, no network, no cloud call. Given the
// same evidence set it always returns the same verdict.
//
// Two hard rules from the spec:
//   * A candidate whose subtree was not fully observed can never be CONFIRMED.
//   * UNKNOWN attribution fails closed -> PROTECTED, never selectable.

import Foundation

public struct RiskConfidenceModel: Sendable {
    public init() {}

    /// Evidence kinds that, if present, force the candidate to PROTECTED
    /// regardless of anything else.
    private static let protectingKinds: Set<Evidence.Kind> = [
        .userStateMarker,   // memory / conversation history / auth / config
        .cloudBacked,       // never silently remove a cloud object
    ]

    /// Evidence kinds that cap risk no lower than HIGH_RISK.
    private static let highRiskKinds: Set<Evidence.Kind> = [
        .sharedVendorDir, .runningProcess, .subtreeIncomplete, .mountBoundary,
    ]

    public struct Verdict: Sendable {
        public let confidence: Confidence
        public let risk: RiskClass
        public let defaultSelected: Bool
        public let protectedReason: String?
        /// Language-independent form of `protectedReason` for the localized UI.
        public var protectedReasonText: LocalizedText? = nil
    }

    /// `subtreeComplete` is the engine's truth about whether every node under
    /// the candidate was fully read. `reconstruction` is the detector's claim
    /// about how expensive recovery is.
    public func evaluate(evidence: [Evidence],
                         subtreeComplete: Bool,
                         reconstruction: Reconstructability,
                         activeState: ActiveState,
                         gitSafety: GitSafetyClass?) -> Verdict {
        let kinds = Set(evidence.map(\.kind))

        // 1. Hard PROTECTED gates.
        if let hit = evidence.first(where: { Self.protectingKinds.contains($0.kind) }) {
            return Verdict(confidence: .unknown, risk: .protected, defaultSelected: false,
                           protectedReason: hit.humanReadable,
                           protectedReasonText: hit.text
                             ?? LocalizedText("deepscan.protected.user_state", fallback: hit.humanReadable))
        }
        if gitSafety == .red {
            return Verdict(confidence: .weak, risk: .protected, defaultSelected: false,
                           protectedReason: "Git repository has uncommitted or unpushed work",
                           protectedReasonText: LocalizedText("deepscan.protected.git_red",
                             fallback: "Git repository has uncommitted or unpushed work"))
        }
        if activeState == .activelyWritten {
            return Verdict(confidence: .weak, risk: .protected, defaultSelected: false,
                           protectedReason: "A process is writing to this location right now",
                           protectedReasonText: LocalizedText("deepscan.protected.active_write",
                             fallback: "A process is writing to this location right now"))
        }
        // No positive evidence at all -> we do not know what this is.
        let attributionKinds: Set<Evidence.Kind> = [
            .bundleIDExactMatch, .bundleIDNoInstall, .pathPattern, .reconstructionKnown,
            .regenerableMarker, .gitClean, .duplicateRemote,
        ]
        if kinds.isDisjoint(with: attributionKinds) {
            return Verdict(confidence: .unknown, risk: .protected, defaultSelected: false,
                           protectedReason: "Not enough evidence to identify this data",
                           protectedReasonText: LocalizedText("deepscan.protected.unknown_attribution",
                             fallback: "Not enough evidence to identify this data"))
        }

        // 2. Confidence.
        var confidence: Confidence
        if kinds.contains(.bundleIDExactMatch) && kinds.contains(.noSiblingOwner) {
            confidence = .strong
        } else if kinds.contains(.bundleIDExactMatch) || kinds.contains(.gitClean) {
            confidence = .probable
        } else if kinds.contains(.regenerableMarker) {
            // A generated directory sitting next to the manifest that produces
            // it, with the whole subtree observed, is strongly attributed.
            confidence = subtreeComplete ? .strong : .probable
        } else if kinds.contains(.reconstructionKnown) {
            confidence = .probable
        } else if kinds.contains(.pathPattern) {
            confidence = .weak
        } else {
            confidence = .weak
        }
        // Complete evidence + a definitive marker can reach CONFIRMED.
        if subtreeComplete && confidence == .strong
            && (kinds.contains(.regenerableMarker) || kinds.contains(.reconstructionKnown)) {
            confidence = .confirmed
        }
        // The hard rule: no CONFIRMED without a complete subtree.
        if !subtreeComplete && confidence > .probable {
            confidence = .probable
        }
        if kinds.contains(.subtreeIncomplete) {
            confidence = min(confidence, .weak)
        }

        // 3. Risk.
        var risk: RiskClass = .review
        switch reconstruction {
        case .regeneratesLocally:
            risk = .safe
        case .reinstallRequired, .longCompile:
            risk = .review
        case .networkRedownload, .largeModelDownload:
            risk = .highRisk
        case .irreplaceable:
            risk = .protected
        case .unknown:
            risk = .highRisk
        }
        if !kinds.isDisjoint(with: Self.highRiskKinds) { risk = max(risk, .highRisk) }
        if activeState == .inUseByRunningApp { risk = max(risk, .review) }
        if gitSafety == .yellow { risk = max(risk, .highRisk) }
        if !subtreeComplete { risk = max(risk, .review) }

        // 4. Default selection — see DefaultSelectionPolicy for the narrative.
        let defaultSelected = DefaultSelectionPolicy.allows(
            risk: risk, confidence: confidence, reconstruction: reconstruction,
            subtreeComplete: subtreeComplete, evidenceKinds: kinds)

        return Verdict(confidence: confidence, risk: risk,
                       defaultSelected: defaultSelected, protectedReason: nil)
    }
}

/// Extremely conservative. The default answer is NO; a candidate must clear
/// every bar to be pre-ticked.
///
/// PRODUCTIZATION PHASE POLICY (spec §20/§35): pre-selection is held at **zero**
/// until the maintainer has reviewed real execution behaviour. `meetsBar`
/// captures the criteria a candidate would need; `allows` currently always
/// returns false so the UI ships with nothing pre-ticked. Flip
/// `preselectionEnabled` only after that review.
public enum DefaultSelectionPolicy {
    nonisolated(unsafe) public static var preselectionEnabled = false

    /// The bar a candidate must clear to be *eligible* for pre-selection.
    public static func meetsBar(risk: RiskClass, confidence: Confidence,
                                reconstruction: Reconstructability, subtreeComplete: Bool,
                                evidenceKinds: Set<Evidence.Kind>) -> Bool {
        guard risk == .safe, confidence >= .strong, subtreeComplete,
              reconstruction == .regeneratesLocally else { return false }
        let vetoes: Set<Evidence.Kind> = [
            .userStateMarker, .cloudBacked, .sharedVendorDir, .gitState, .gitClean,
            .mountBoundary, .subtreeIncomplete, .runningProcess, .duplicateRemote,
        ]
        return evidenceKinds.isDisjoint(with: vetoes)
    }

    public static func allows(risk: RiskClass, confidence: Confidence,
                              reconstruction: Reconstructability, subtreeComplete: Bool,
                              evidenceKinds: Set<Evidence.Kind>) -> Bool {
        guard preselectionEnabled else { return false }
        return meetsBar(risk: risk, confidence: confidence, reconstruction: reconstruction,
                        subtreeComplete: subtreeComplete, evidenceKinds: evidenceKinds)
    }
}
