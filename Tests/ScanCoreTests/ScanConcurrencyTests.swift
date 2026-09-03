// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import SafetyCore
@testable import ScanCore

/// Verifies bounded concurrent rule execution: the finding *set* and totals are
/// independent of `maxConcurrency`, aggregation never double-counts, a failing
/// (empty-root) rule does not poison the run, and cancellation still terminates.
@Suite("ScanEngine bounded concurrency")
struct ScanConcurrencyTests {
    let tempRoot: URL

    init() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-conc-\(UUID().uuidString)")
        // Ten independent roots, each with a couple of files, one rule per root.
        for r in 0..<10 {
            let dir = tempRoot.appendingPathComponent("root\(r)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for f in 0..<3 {
                try Data(repeating: 0, count: 100 + f).write(
                    to: dir.appendingPathComponent("file\(f).bin"))
            }
        }
    }

    private func cleanup() { try? FileManager.default.removeItem(at: tempRoot) }

    private func rules() -> [ScanRule] {
        (0..<10).map { r in
            ScanRule(id: "rule.\(r)", name: "root \(r)", category: "Test",
                     explanation: "test", minimumAgeDays: 0,
                     risk: .low, preselect: true) { home in
                [home.appendingPathComponent("root\(r)")]
            }
        }
    }

    private func collect(maxConcurrency: Int, rules: [ScanRule]) async
        -> (paths: Set<String>, bytes: Int64, findings: Int) {
        let engine = ScanEngine(configuration:
            ScanConfiguration(home: tempRoot, maxConcurrency: maxConcurrency))
        var paths: Set<String> = []
        var findings = 0
        var bytes: Int64 = -1
        for await event in engine.run(rules: rules) {
            switch event {
            case let .finding(f): paths.insert(f.url.lastPathComponent + "@" + f.ruleID); findings += 1
            case let .finished(_, b): bytes = b
            default: break
            }
        }
        return (paths, bytes, findings)
    }

    @Test func identicalResultSetAcrossConcurrencyLevels() async {
        defer { cleanup() }
        let seq = await collect(maxConcurrency: 1, rules: rules())     // sequential
        let two = await collect(maxConcurrency: 2, rules: rules())
        let over = await collect(maxConcurrency: 4, rules: rules())    // clamped, > effective need
        #expect(seq.paths == two.paths)
        #expect(seq.paths == over.paths)
        #expect(seq.findings == 30)
        #expect(two.findings == 30)
        #expect(over.findings == 30)
    }

    @Test func totalsDoNotDoubleCount() async {
        defer { cleanup() }
        let seq = await collect(maxConcurrency: 1, rules: rules())
        let par = await collect(maxConcurrency: 4, rules: rules())
        #expect(seq.bytes == par.bytes)
        #expect(seq.bytes > 0)
    }

    @Test func failingRuleDoesNotPoisonRun() async {
        defer { cleanup() }
        var rs = rules()
        // A rule whose root does not exist behaves like a no-op failure.
        rs.append(ScanRule(id: "rule.missing", name: "missing", category: "Test",
                           explanation: "test", minimumAgeDays: 0,
                           risk: .low, preselect: true) { home in
            [home.appendingPathComponent("no-such-root")]
        })
        let result = await collect(maxConcurrency: 3, rules: rs)
        #expect(result.findings == 30, "missing-root rule must not drop other rules' findings")
    }

    @Test func cancellationMidRunTerminates() async {
        defer { cleanup() }
        let engine = ScanEngine(configuration:
            ScanConfiguration(home: tempRoot, maxConcurrency: 4))
        var count = 0
        for await event in engine.run(rules: rules()) {
            if case .finding = event {
                count += 1
                if count >= 3 { break }
            }
        }
        #expect(count == 3)
    }
}
