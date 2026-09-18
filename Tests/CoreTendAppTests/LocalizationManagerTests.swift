// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import CoreTendApp

@Suite("LocalizationManager runtime language override")
struct LocalizationManagerTests {
    /// A key known to exist, with a different value in Base vs fr, so a
    /// real mismatch would be caught rather than a coincidental match.
    private let key = "common.cancel"

    @Test("system language resolves no override bundle — falls back to Bundle.module")
    func systemHasNoOverride() {
        #expect(LocalizationManager.bundle(for: .system) == nil)
    }

    @Test("fr resolves to a real bundle whose lookup is actually French, independent of the system locale")
    func frResolvesRealFrenchBundle() throws {
        let bundle = try #require(LocalizationManager.bundle(for: .fr))
        let value = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        #expect(value == "Annuler")
    }

    @Test("en resolves to a real bundle whose lookup is actually English")
    func enResolvesRealEnglishBundle() throws {
        let bundle = try #require(LocalizationManager.bundle(for: .en))
        let value = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        #expect(value == "Cancel")
    }

    @Test("an unknown persisted value falls back to .system rather than crashing")
    func unknownStoredValueFallsBackSafely() {
        #expect(LocalizationManager.language(fromStoredValue: "de") == .system)
        #expect(LocalizationManager.language(fromStoredValue: nil) == .system)
    }
}

/// The strings tables must actually *parse*, not merely contain the right text.
///
/// A `|||||||` merge-conflict marker survived a UTF-16 merge into both tables
/// and shipped. `plutil -lint` reported OK, every existing test passed — they
/// all searched the file as text — and the app looked fine, because the
/// old-style .strings parser does not fail on a bad line: it stops. Every one
/// of the 18 keys after the marker silently resolved to its own key name at
/// runtime, in both languages, in a released build.
@Suite("Localization tables parse completely")
struct LocalizationParsingTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func table(_ lang: String) throws -> (source: String, parsed: [String: Any]) {
        let url = root.appendingPathComponent("Sources/CoreTendApp/Resources/\(lang).lproj/Localizable.strings")
        let source = try String(contentsOf: url, encoding: .utf16)
        let parsed = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url), format: nil) as? [String: Any] ?? [:]
        return (source, parsed)
    }

    private func declaredKeys(in source: String) -> [String] {
        source.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\""), let end = trimmed.dropFirst().firstIndex(of: "\"") else { return nil }
            let key = String(trimmed[trimmed.index(after: trimmed.startIndex)..<end])
            return trimmed[end...].dropFirst().trimmingCharacters(in: .whitespaces).hasPrefix("=") ? key : nil
        }
    }

    /// The load-bearing assertion: every key written in the file is a key the
    /// parser actually returns. A truncating parse fails here and nowhere else.
    @Test(arguments: ["Base", "fr"] as [String])
    func everyDeclaredKeyIsReachableAtRuntime(_ lang: String) throws {
        let (source, parsed) = try table(lang)
        let declared = declaredKeys(in: source)
        let unreachable = declared.filter { parsed[$0] == nil }
        let firstUnreachable = unreachable.first ?? "-"
        #expect(unreachable.isEmpty,
                "\(lang): \(unreachable.count) key(s) in the file are not returned by the parser — the table stops parsing before them. First: \(firstUnreachable)")
        #expect(declared.count == parsed.count, "\(lang): \(declared.count) declared vs \(parsed.count) parsed")
    }

    @Test(arguments: ["Base", "fr"] as [String])
    func noMergeConflictMarkerSurvives(_ lang: String) throws {
        for line in try table(lang).source.split(separator: "\n") {
            for marker in ["<<<<<<<", "=======", ">>>>>>>", "|||||||"] {
                #expect(!line.hasPrefix(marker), "\(lang): conflict marker \(marker) in the strings table")
            }
        }
    }

    /// Both languages must define the same keys — a key present only in Base
    /// renders as its own key name for French users.
    @Test func bothLanguagesDefineTheSameKeys() throws {
        let base = Set(try table("Base").parsed.keys)
        let french = Set(try table("fr").parsed.keys)
        #expect(base.subtracting(french).isEmpty, "missing from fr: \(base.subtracting(french).sorted())")
        #expect(french.subtracting(base).isEmpty, "missing from Base: \(french.subtracting(base).sorted())")
    }
}
