// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
import DeepScanCore
@testable import CoreTendApp

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

    @Test func everyStructuredReasonKeyEmittedByDetectorsExistsInBothLanguages() async throws {
        let base = try keysAndValues("Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings")
        let fr = try keysAndValues("Sources/CoreTendApp/Resources/fr.lproj/Localizable.strings")

        // Build a fixture that trips most detectors and collect every
        // LocalizedText.key the pipeline actually produces.
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ds-l10n-\(UUID().uuidString)")
        let fm = FileManager.default
        func mk(_ rel: String, _ bytes: Int) {
            let u = tmp.appendingPathComponent(rel)
            try? fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            fm.createFile(atPath: u.path, contents: Data(count: bytes))
        }
        defer { try? fm.removeItem(at: tmp) }
        mk(".claude/projects/-x/memory/M.md", 10)
        mk(".claude/statsig/e.json", 10)
        mk(".cache/lm-studio/models/f.gguf", 10)
        mk(".cache/lm-studio/bin/llama", 10)
        mk("proj/package.json", 20)
        mk("proj/.next/cache/c.js", 4096)
        mk("Library/Caches/com.evil.Ghost/blob", 5000)
        mk("Library/LaunchAgents/com.evil.agent.plist", 100)
        mk("Downloads/Thing-1.0.dmg", 3_000_000)
        try? fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -400 * 86_400)],
            ofItemAtPath: tmp.appendingPathComponent("Downloads/Thing-1.0.dmg").path)

        let cfg = DeepScanConfiguration(roots: [tmp], maxConcurrency: 4, timeBudget: .seconds(30))
        let g = await DeepScanEngine().scan(cfg)
        let ctx = DetectorContext(home: tmp, installedApps: [], runningBundleIDs: [],
            runningExecutablePaths: [], scanStartedAt: g.startedAt, scanFinishedAt: g.finishedAt, gitRepos: [])
        var keys = Set<String>()
        for d in DeepScanPipeline.defaultDetectors {
            for c in d.detect(in: g, context: ctx) {
                if let k = c.rationaleText?.key { keys.insert(k) }
                if let k = c.ifRemovedText?.key { keys.insert(k) }
                if let k = c.protectedReasonText?.key { keys.insert(k) }
                for e in c.evidence { if let k = e.text?.key { keys.insert(k) } }
            }
        }
        #expect(keys.count > 15, "expected many structured keys, got \(keys)")
        for k in keys {
            #expect(base[k] != nil, "structured key \(k) missing from Base.lproj")
            #expect(fr[k] != nil, "structured key \(k) missing from fr.lproj")
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
