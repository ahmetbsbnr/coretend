// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing

@Suite("CoreTend accessibility contract")
struct AccessibilityContractTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    @Test func primaryPauseControlsHaveLocalizedVoiceOverHints() throws {
        let base = root.appendingPathComponent("Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings")
        let fr = root.appendingPathComponent("Sources/CoreTendApp/Resources/fr.lproj/Localizable.strings")
        let baseText = try String(contentsOf: base, encoding: .utf16)
        let frText = try String(contentsOf: fr, encoding: .utf16)

        for key in [
            "common.pause", "common.resume", "common.cancel",
            "cleanup.pause_hint", "cleanup.resume_hint",
            "clutter.pause_hint", "clutter.resume_hint",
        ] {
            #expect(baseText.contains("\"\(key)\""))
            #expect(frText.contains("\"\(key)\""))
        }
    }

    // MARK: - Information hidden from VoiceOver must be surfaced elsewhere

    /// Reading a source file from the test bundle's own location, like the
    /// localization check above: these are structural contracts about the view
    /// code, not runtime behaviour, and a SwiftUI accessibility tree is not
    /// inspectable from a unit test.
    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    @Test func cleanupEvidenceLineIsHiddenButReachesTheSelectionLabel() throws {
        // The evidence line under a finding (risk and age) is marked
        // accessibilityHidden so VoiceOver reads the row as one sentence rather
        // than stopping on it separately. That is only acceptable because the
        // same text is folded into the selection toggle's label.
        //
        // Remove the fold and keep the hiding — an easy thing to do while
        // tidying — and the information disappears for screen-reader users
        // entirely, silently, with every visual test still passing.
        let view = try source("Sources/CoreTendApp/CleanupView.swift")
        #expect(view.contains("accessibilityHidden(true)"))
        #expect(view.contains("finding.a11y.evidence"))
        #expect(view.contains("FindingMetadata.summary"))
    }

    @Test func provenanceRowCombinesItsLinesIntoOneAnnouncement() throws {
        // The Integrity download rows gained a third line ("Downloaded by
        // Safari · 12 Mar 2026"). Without the combine, each line becomes its
        // own VoiceOver stop and a list of 25 downloads turns into 75.
        let view = try source("Sources/CoreTendApp/ProtectionView.swift")
        #expect(view.contains("accessibilityElement(children: .combine)"))
        #expect(view.contains("ProvenanceSummary.acquisition"))
    }

    @Test func skipReportingKeysExistInBothLanguages() throws {
        // A partial cleanup says so on screen. If the key is missing from one
        // table the sentence silently becomes its own key name.
        let base = root.appendingPathComponent("Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings")
        let fr = root.appendingPathComponent("Sources/CoreTendApp/Resources/fr.lproj/Localizable.strings")
        let baseText = try String(contentsOf: base, encoding: .utf16)
        let frText = try String(contentsOf: fr, encoding: .utf16)

        for key in [
            "cleanup.done.skipped",
            "finding.a11y.evidence", "risk.low", "risk.medium", "risk.high",
            "integrity.downloads.by_agent_on_date", "integrity.downloads.by_agent",
            "integrity.downloads.on_date",
        ] {
            #expect(baseText.contains("\"\(key)\""), "missing from Base: \(key)")
            #expect(frText.contains("\"\(key)\""), "missing from fr: \(key)")
        }
    }
}
