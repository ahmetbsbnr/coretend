// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp
@testable import SystemMetrics

@Suite("Privacy Lab localization parity")
struct PrivacyLabLocalizationTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func stringsText(_ folder: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(
            "Sources/CoreTendApp/Resources/\(folder).lproj/Localizable.strings"), encoding: .utf16)
    }

    /// Every key Privacy Lab looks up, static plus the per-category ones.
    private var requiredKeys: [String] {
        var keys = [
            "module.privacy_lab",
            "privacylab.title", "privacylab.intro", "privacylab.local_note",
            "privacylab.choose_image", "privacylab.choose_different", "privacylab.clear",
            "privacylab.empty.title", "privacylab.empty.message",
            "privacylab.inspecting", "privacylab.inspecting_named", "privacylab.inspected_named",
            "privacylab.summary.header", "privacylab.summary.present",
            "privacylab.summary.none_detected", "privacylab.summary.incomplete",
            "privacylab.summary.not_a_score", "privacylab.format",
            "privacylab.section.categories", "privacylab.section.categories.subtitle",
            "privacylab.section.blocks", "privacylab.section.blocks.note",
            "privacylab.embedded_value",
            "privacylab.state.present", "privacylab.state.not_detected", "privacylab.state.unavailable",
            "privacylab.state.unavailable.reason",
            "privacylab.status.unsupported", "privacylab.status.unsupported.detail",
            "privacylab.status.unreadable", "privacylab.status.unreadable.detail",
            "privacylab.status.file_missing", "privacylab.status.file_missing.detail",
            "privacylab.location.no_geocode", "privacylab.location.no_coordinate",
            "privacylab.location.reveal", "privacylab.location.precise_label",
        ]
        for category in ImageMetadataCategory.allCases {
            keys.append("privacylab.category.\(category.rawValue).title")
            keys.append("privacylab.category.\(category.rawValue).why")
        }
        return keys
    }

    @Test func everyPrivacyLabKeyExistsInBothBaseAndFrench() throws {
        let base = try stringsText("Base")
        let fr = try stringsText("fr")
        for key in requiredKeys {
            #expect(base.contains("\"\(key)\""), "Base.lproj is missing \(key)")
            #expect(fr.contains("\"\(key)\""), "fr.lproj is missing \(key)")
        }
    }

    @Test func catalogResolvesADistinctFrenchStringForEveryCategory() {
        for category in ImageMetadataCategory.allCases {
            let en = LocalizationManager.string(forKey: "privacylab.category.\(category.rawValue).title", language: .en)
            let fr = LocalizationManager.string(forKey: "privacylab.category.\(category.rawValue).title", language: .fr)
            let enWhy = LocalizationManager.string(forKey: "privacylab.category.\(category.rawValue).why", language: .en)
            let frWhy = LocalizationManager.string(forKey: "privacylab.category.\(category.rawValue).why", language: .fr)
            // Resolved (not echoed back as the key) and actually translated.
            #expect(en != "privacylab.category.\(category.rawValue).title")
            #expect(fr != "privacylab.category.\(category.rawValue).title")
            #expect(!enWhy.isEmpty && !frWhy.isEmpty)
            #expect(enWhy != frWhy, "\(category) explanation is not translated")
        }
    }

    @Test func moduleLabelIsTranslated() {
        #expect(LocalizationManager.string(forKey: "module.privacy_lab", language: .en) == "Privacy Lab")
        #expect(LocalizationManager.string(forKey: "module.privacy_lab", language: .fr) != "Privacy Lab")
    }
}
