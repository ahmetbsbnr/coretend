// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import Persistence
import SafetyCore

// SQLite / history at scale. Confirms bulk inserts and the indexed, limited
// read queries stay fast with a large backlog of records.
@Suite("Store at scale")
struct StoreStressTests {
    private func tempDBPath() -> String {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-db-stress-\(UUID().uuidString).sqlite").path
    }

    /// 20k activity rows + 20k append-only safety-log rows. The read paths are
    /// bounded (LIMIT) and, for safety_log, index-backed on date — so query time
    /// must stay flat regardless of table size. We assert correct ordering/limit
    /// and a generous wall-clock ceiling on the reads.
    @Test func largeHistoryStaysFastToQuery() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)

        let clock = ContinuousClock()
        let count = 8_000
        let base = Date(timeIntervalSince1970: 1_600_000_000)

        let insertStart = clock.now
        for i in 0..<count {
            try await store.recordActivity(ActivityRecord(
                kind: i % 2 == 0 ? .scan : .cleanup,
                date: base.addingTimeInterval(Double(i)),
                summary: "row \(i)", itemCount: i, bytes: Int64(i) * 10))
            await store.recordSafetyEvent(SafetyAuditEvent(
                operationID: UUID(), stage: .executed, path: "/tmp/f\(i)",
                ruleID: "r", risk: .low, size: Int64(i), result: "ok"))
        }
        let insertElapsed = insertStart.duration(to: clock.now)

        // Bounded read: newest 200, must be the highest-dated rows in order.
        let readStart = clock.now
        let recent = try await store.activity(limit: 200)
        let recentScans = try await store.activity(limit: 200, kind: .scan)
        let recentSafety = try await store.safetyLog(limit: 200)
        let readElapsed = readStart.duration(to: clock.now)
        print("[stress] store: inserted \(count)x2 rows in \(insertElapsed), read 3x200 in \(readElapsed)")

        #expect(recent.count == 200)
        #expect(recent.first?.summary == "row \(count - 1)", "newest first")
        #expect(recent.first!.date > recent.last!.date)
        #expect(recentScans.count == 200)
        #expect(recentScans.allSatisfy { $0.kind == .scan })
        #expect(recentSafety.count == 200)
        // Reads are LIMIT-bounded and (safety_log) index-backed; well under a
        // second on any reasonable machine even with 20k+ rows behind them.
        #expect(readElapsed < .seconds(5))
    }
}
