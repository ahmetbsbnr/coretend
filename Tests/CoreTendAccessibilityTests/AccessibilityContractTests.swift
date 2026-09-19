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

    @Test func provenanceRowIsOneAnnouncementThatSaysAllThreeThings() throws {
        // A provenance row is a name, where it came from, and whether macOS
        // quarantined it. Combining the children made it one VoiceOver stop
        // but read the parts in layout order with the quarantine state
        // carried only by an icon's tint — which says nothing at all.
        //
        // It is now an explicit sentence, so the check is that the label
        // exists and names all three, not that the children are combined.
        let view = try source("Sources/CoreTendApp/ProtectionView.swift")
        #expect(view.contains("accessibilityElement(children: .ignore)"))
        #expect(view.contains("integrity.row_a11y"))
        #expect(view.contains("ProvenanceSummary.acquisition"))
        #expect(view.contains("integrity.a11y.quarantined"))
    }

    @Test func evidenceLinesWrapRatherThanTruncateAtAccessibilitySizes() throws {
        // Both evidence lines are caption2 with a single-line limit, which keeps
        // rows compact at ordinary text sizes. Left unconditional, large
        // Dynamic Type would cut "Low risk · modified 1 month ago" down to the
        // risk alone — removing exactly the evidence the line exists to show,
        // from the readers who most need it. The limit is therefore relaxed at
        // accessibility sizes rather than fixed at 1.
        //
        // The path line above keeps a hard limit deliberately: paths are
        // arbitrarily long and middle-truncate readably.
        for file in ["Sources/CoreTendApp/CleanupView.swift",
                     "Sources/CoreTendApp/ProtectionView.swift"] {
            let view = try source(file)
            #expect(view.contains("dynamicTypeSize.isAccessibilitySize"), "no Dynamic Type handling in \(file)")
            #expect(view.contains("lineLimit(evidenceLineLimit)"), "evidence line not using the relaxed limit in \(file)")
        }
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
