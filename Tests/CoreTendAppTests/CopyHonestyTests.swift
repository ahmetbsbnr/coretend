// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// The interface may not claim to measure, guarantee or verify something
/// CoreTend does not actually know.
///
/// Three of these shipped:
///
/// - `"Freed (real)"` summed bytes *moved to the Trash* and called the sum
///   verified. The space returns only when the user empties the Trash, outside
///   the app, at a time the app is never told about. The word "real" claimed a
///   check that was never performed.
/// - `"%@ will be reclaimed."` promised a future reclaim in a destructive
///   confirmation, then contradicted itself in its own next sentence — if the
///   files stay recoverable, nothing has been reclaimed.
/// - `"No telemetry, no accounts, no network calls."` was shown in Settings by
///   a build that checks for updates over the network. That is a privacy claim,
///   not a wording preference, and it was false in one of the two products.
///
/// Prose cannot be unit-tested, so this tests the narrow, checkable part: the
/// specific vocabulary those three failures were made of. It is a tripwire, not
/// a proof of honesty — a new claim in new words still needs a person.
@Suite("Copy does not claim what the app cannot know")
struct CopyHonestyTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func table(_ lang: String) throws -> [String: String] {
        let url = root.appendingPathComponent(
            "Sources/CoreTendApp/Resources/\(lang).lproj/Localizable.strings")
        return try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url), format: nil) as? [String: String] ?? [:]
    }

    /// "Freed" and "reclaimed" describe space returning to the volume. Only
    /// emptying the Trash does that, and CoreTend never learns when it happens.
    /// "Moved to the Trash" is the true statement and is always available.
    @Test(arguments: ["Base", "fr"])
    func nothingClaimsSpaceWasFreed(_ lang: String) throws {
        // "recoverable" / "récupérable" is deliberately *not* here. A file in
        // the Trash genuinely is recoverable, and saying so is the honest
        // version of the claim. What is forbidden is the past tense that says
        // the space has come back, because only emptying the Trash does that.
        let forbidden = ["freed", "reclaim", "récupéré", "libéré"]
        for (key, value) in try table(lang) {
            let text = value.lowercased()
            for word in forbidden {
                #expect(!text.contains(word),
                        "\(lang)/\(key) claims space was freed: \"\(value)\"")
            }
        }
    }

    /// An absolute "no network calls" is false in the Developer ID build, which
    /// checks for updates. The claim has to be the one the running build can
    /// actually make, so it is split in two and chosen by capability.
    @Test(arguments: ["Base", "fr"])
    func noAbsoluteNetworkClaim(_ lang: String) throws {
        let forbidden = ["no network calls", "aucun appel réseau"]
        for (key, value) in try table(lang) {
            let text = value.lowercased()
            for phrase in forbidden {
                #expect(!text.contains(phrase),
                        "\(lang)/\(key) denies all network use, false in the Developer ID build: \"\(value)\"")
            }
        }
    }

    /// Both halves of the split claim must exist, or the capability branch in
    /// Settings renders a raw key to the user.
    @Test(arguments: ["Base", "fr"])
    func bothPrivacyStatementsExist(_ lang: String) throws {
        let table = try table(lang)
        #expect(table["settings.data_detail_offline"] != nil)
        #expect(table["settings.data_detail_updates"] != nil)
        // The build that cannot reach the network is the one allowed to deny it.
        #expect(table["settings.data_detail_updates"]?.isEmpty == false)
    }

    /// A scan proposes candidates; the person decides. "Safe to remove" and
    /// "safe to delete" state a verdict the scan never reaches.
    @Test(arguments: ["Base", "fr"])
    func nothingIsDeclaredSafeToRemove(_ lang: String) throws {
        let forbidden = ["safe-to-remove", "safe to remove", "safe to delete",
                         "sans risque", "en toute sécurité"]
        for (key, value) in try table(lang) {
            let text = value.lowercased()
            for phrase in forbidden {
                #expect(!text.contains(phrase),
                        "\(lang)/\(key) declares a safety verdict: \"\(value)\"")
            }
        }
    }

    /// Both tables carry the same keys, so a claim cannot be fixed in one
    /// language and left standing in the other.
    @Test func theTwoLanguagesCarryTheSameKeys() throws {
        let base = Set(try table("Base").keys), fr = Set(try table("fr").keys)
        #expect(base.subtracting(fr).isEmpty, "missing from fr: \(base.subtracting(fr).sorted())")
        #expect(fr.subtracting(base).isEmpty, "missing from Base: \(fr.subtracting(base).sorted())")
    }
}
