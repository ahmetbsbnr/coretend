// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import ScanCore

@Suite("CoreTend scan performance")
struct ScanPerformanceTests {
    @Test func smallDeterministicScanCompletesWithinBudget() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-perf-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for index in 0..<300 {
            try Data(repeating: UInt8(index % 251), count: 1024)
                .write(to: root.appendingPathComponent("file-\(index).tmp"))
        }

        let start = ContinuousClock.now
        var count = 0
        let rule = ScanRule(
            id: "performance.files",
            name: "Performance files",
            category: "Performance",
            explanation: "Deterministic performance fixture",
            risk: .low,
            preselect: false,
            minimumSizeBytes: 1
        ) { home in
            [home]
        }
        let engine = ScanEngine(configuration: ScanConfiguration(home: root))

        for await event in engine.run(rules: [rule]) {
            if case .finding = event { count += 1 }
        }
        let duration = start.duration(to: .now)

        #expect(count == 300)
        #expect(duration < .seconds(5))
    }
}
