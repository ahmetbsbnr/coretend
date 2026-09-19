// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// Every key the source asks for must exist, and every key that exists should
/// be asked for.
///
/// Nothing checked either direction. Two consequences shipped:
///
/// - `PlaceholderView` called `L("placeholder.under_construction")` after that
///   key had been deleted from both tables. `L` falls back to returning the key
///   itself, so the failure mode is a screen displaying
///   "placeholder.under_construction" to a user. It was unreachable, so it was
///   only ever going to be embarrassing rather than harmful — but nothing in
///   the build knew that, and the next deletion might not be unreachable.
/// - Sixteen keys for a notifications feature that no longer existed sat in
///   both tables for months, each one a translation someone paid attention to
///   for nothing.
@Suite("Localization keys: used and defined agree")
struct LocalizationUsageTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func definedKeys() throws -> Set<String> {
        let url = root.appendingPathComponent("Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings")
        let table = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url), format: nil) as? [String: Any] ?? [:]
        return Set(table.keys)
    }

    /// Keys referenced as `L("…")` or `LocalizationManager.string(forKey: "…")`.
    ///
    /// Only literal keys can be found this way. A handful of call sites build a
    /// key by interpolation — `"authorization.\(rawValue).title"`,
    /// `"risk.\(level)"` — and those are covered by their own tests, which
    /// enumerate the enum and assert each key exists.
    private func usedKeys() throws -> Set<String> {
        let dir = root.appendingPathComponent("Sources/CoreTendApp")
        var keys = Set<String>()
        for name in try SourceTree.swiftFiles(under: dir)
            where name.hasSuffix(".swift") {
            let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
            for pattern in [#"\bL\("([^"\\]+)"\)"#,
                            #"\bL\("([^"\\]+)","#,
                            #"forKey:\s*"([^"\\]+)""#] {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(text.startIndex..., in: text)
                for match in regex.matches(in: text, range: range) {
                    guard let captured = Range(match.range(at: 1), in: text) else { continue }
                    keys.insert(String(text[captured]))
                }
            }
        }
        return keys
    }

    /// The direction that reaches users: asking for a key that does not exist
    /// puts the key itself on screen.
    @Test func everyKeyTheSourceAsksForIsDefined() throws {
        let missing = try usedKeys().subtracting(definedKeys()).sorted()
        #expect(missing.isEmpty, "\(missing.count) key(s) used in source but absent from the table: \(missing)")
    }

    /// The other direction is not an error, but it is debt: a key nobody asks
    /// for is a sentence two languages are maintaining for nothing. Reported
    /// against a documented allowance so that removing a feature and leaving
    /// its vocabulary behind is visible.
    @Test func unusedKeysStayBelowTheKnownAllowance() throws {
        let defined = try definedKeys()
        let used = try usedKeys()
        // Interpolated families, enumerated by the tests that own them.
        let interpolatedPrefixes = [
            "authorization.", "risk.", "integrity.tier.", "cloud.state.",
            "apps.grouping.", "safety.reason.", "shortcuts.", "menu.help.",
            "module.", "sidebar.", "updates.", "record.filter_",
        ]
        // Plural families: `L(count == 1 ? base + "_one" : base + "_other")`.
        // The base is a literal, the whole key never is.
        let pluralSuffixes = ["_one", "_other"]
        let orphans = defined.subtracting(used).filter { key in
            if interpolatedPrefixes.contains(where: { key.hasPrefix($0) }) { return false }
            for suffix in pluralSuffixes where key.hasSuffix(suffix) {
                if used.contains(String(key.dropLast(suffix.count))) { return false }
            }
            return true
        }
        // A ratchet, not a target: it may go down freely and must not drift up
        // without someone noticing. Was 120 when three modules and a
        // seven-step wizard were retired; 76 dead keys went with them.
        #expect(orphans.count <= 25,
                "\(orphans.count) unused keys — up from the recorded allowance. Sample: \(orphans.sorted().prefix(15))")
    }
}
