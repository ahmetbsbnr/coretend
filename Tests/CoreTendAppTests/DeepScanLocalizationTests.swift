// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing

@Suite("Deep Scan localization parity")
struct DeepScanLocalizationTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func keysAndValues(_ rel: String) throws -> [String: String] {
        let url = root.appendingPathComponent(rel)
        let text = try String(contentsOf: url, encoding: .utf16)
        var out: [String: String] = [:]
        // "key" = "value";  (value may contain escaped quotes)
        let pattern = #"^"([^"]+)"\s*=\s*"(.*)";\s*$"#
        let re = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let ns = text as NSString
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out[ns.substring(with: m.range(at: 1))] = ns.substring(with: m.range(at: 2))
        }
        return out
    }

    @Test func everyDeepScanKeyExistsInBothLanguagesWithNonEmptyValues() throws {
        let base = try keysAndValues("Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings")
        let fr = try keysAndValues("Sources/CoreTendApp/Resources/fr.lproj/Localizable.strings")

        let baseDeep = Set(base.keys.filter { $0.hasPrefix("deepscan.") })
        let frDeep = Set(fr.keys.filter { $0.hasPrefix("deepscan.") })

        #expect(baseDeep.count >= 100, "expected the full Deep Scan key set, got \(baseDeep.count)")
        #expect(baseDeep == frDeep, "missing in fr: \(baseDeep.subtracting(frDeep)); missing in base: \(frDeep.subtracting(baseDeep))")

        for key in baseDeep {
            #expect(!(base[key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty, "empty EN value for \(key)")
            #expect(!(fr[key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty, "empty FR value for \(key)")
        }
    }

    @Test func frenchValuesActuallyDifferFromEnglishForProseKeys() throws {
        // Spot-check: prose keys must not be left as the English string.
        let base = try keysAndValues("Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings")
        let fr = try keysAndValues("Sources/CoreTendApp/Resources/fr.lproj/Localizable.strings")
        for key in ["deepscan.intro", "deepscan.readonly_note", "deepscan.permission.partial",
                    "deepscan.settings.protections_note", "deepscan.exec_disabled_note"] {
            #expect(base[key] != nil && fr[key] != nil)
            #expect(base[key] != fr[key], "\(key) is not translated")
        }
    }
}
