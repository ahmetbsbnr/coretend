// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing

/// Focused check that this pass's new Smart Scan / Space Lens / Storage-
/// progress surfaces are fully translated. (Whole-catalogue key parity is
/// already asserted by `shippedEnglishAndFrenchCataloguesHaveExactKeyParity`.)
@Suite("Localization — v1.1 UI surfaces are translated")
struct LocalizationParityTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func keys(_ relativePath: String) throws -> Set<String> {
        let text = try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf16)
        var found: Set<String> = []
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\""), trimmed.contains("="),
                  let close = trimmed.dropFirst().firstIndex(of: "\"") else { continue }
            found.insert(String(trimmed[trimmed.index(after: trimmed.startIndex)..<close]))
        }
        return found
    }

    @Test func smartScanAndSpaceLensKeysAreAllTranslatedInBothLanguages() throws {
        let base = try keys("Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings")
        let fr = try keys("Sources/CoreTendApp/Resources/fr.lproj/Localizable.strings")
        let required = [
            "smartscan.title", "smartscan.start", "smartscan.review_recovery_plan",
            "smartscan.category.recoverable", "smartscan.recoverable.inexact_note",
            "smartscan.state.completed", "smartscan.cancelled.title", "smartscan.result.partial",
            "spacelens.other_bucket", "spacelens.bubble_a11y", "spacelens.drill_hint",
            "spacelens.folded_note", "spacelens.back", "spacelens.partial_top",
            "cleanup.phase.paused", "cleanup.phase.finalizing", "cleanup.elapsed",
            "recovery.from_smartscan",
        ]
        for key in required {
            #expect(base.contains(key), "Base missing \(key)")
            #expect(fr.contains(key), "fr missing \(key)")
        }
    }
}
