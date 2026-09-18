// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// French has typographic rules a native reader notices in the first
/// sentence: the apostrophe is ’ not ', and a thin or non-breaking space
/// precedes : ; ! ?. Fifty-nine strings shipped with the ASCII apostrophe.
/// This keeps the table honest as strings are added.
@Suite("French typography")
struct LocalizationTypographyTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func french() throws -> [String: String] {
        let url = root.appendingPathComponent("Sources/CoreTendApp/Resources/fr.lproj/Localizable.strings")
        return try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url), format: nil) as? [String: String] ?? [:]
    }

    @Test func frenchUsesTypographicApostrophes() throws {
        let pattern = try NSRegularExpression(pattern: "[A-Za-zÀ-ÿ]'[A-Za-zÀ-ÿ]")
        for (key, value) in try french() {
            let range = NSRange(value.startIndex..., in: value)
            #expect(pattern.firstMatch(in: value, range: range) == nil,
                    "fr/\(key) uses an ASCII apostrophe: \(value)")
        }
    }

    /// Both tables define the same keys, so a fix in one language cannot be
    /// silently missing from the other.
    @Test func frenchIsNotMissingKeys() throws {
        let base = root.appendingPathComponent("Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings")
        let baseKeys = Set((try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: base), format: nil) as? [String: String] ?? [:]).keys)
        #expect(baseKeys.subtracting(Set(try french().keys)).isEmpty)
    }
}
