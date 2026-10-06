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

        // Foundation silently stops reading a .strings plist at an unresolved
        // diff3 ancestor marker. Checking only text presence would therefore
        // pass while packaged apps display raw localization keys.
        for (url, text) in [(base, baseText), (fr, frText)] {
            #expect(!text.contains("|||||||"))
            let data = try Data(contentsOf: url)
            let catalogue = try #require(
                PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
            )
            for key in ["sidebar.reclaim", "sidebar.disk_label", "sidebar.search", "dashboard.storage.used"] {
                #expect(catalogue[key] != nil)
            }
        }

        for key in [
            "common.pause", "common.resume", "common.cancel",
            "cleanup.pause_hint", "cleanup.resume_hint",
            "clutter.pause_hint", "clutter.resume_hint",
        ] {
            #expect(baseText.contains("\"\(key)\""))
            #expect(frText.contains("\"\(key)\""))
        }
    }
}
