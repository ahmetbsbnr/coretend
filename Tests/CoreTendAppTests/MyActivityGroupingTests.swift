import Testing
import Foundation
import Persistence
@testable import CoreTendApp

private func record(kind: ActivityRecord.Kind, daysAgo: Int, bytes: Int64 = 0, items: Int = 1, dryRun: Bool = false) -> ActivityRecord {
    ActivityRecord(id: 0, kind: kind, date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
                   summary: "x", itemCount: items, bytes: bytes, dryRun: dryRun)
}

@Suite("My Activity day grouping")
struct MyActivityGroupingTests {
    @Test("groups records by calendar day, preserving order")
    func groupsByDay() {
        let records = [
            record(kind: .scan, daysAgo: 0),
            record(kind: .cleanup, daysAgo: 0),
            record(kind: .scan, daysAgo: 1),
        ]
        let groups = ActivityGrouping.byDay(records)
        #expect(groups.count == 2)
        #expect(groups[0].records.count == 2)
        #expect(groups[1].records.count == 1)
    }

    @Test("date range filters honestly by real elapsed time")
    func dateRangeFilters() {
        let now = Date()
        let recent = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let old = Calendar.current.date(byAdding: .day, value: -40, to: now)!
        #expect(ActivityDateRange.last7.contains(recent, now: now))
        #expect(!ActivityDateRange.last7.contains(old, now: now))
        #expect(ActivityDateRange.all.contains(old, now: now))
    }

    @Test("real vs simulated cleanup bytes never merge")
    func realVsSimulated() {
        let records = [
            record(kind: .cleanup, daysAgo: 0, bytes: 100, dryRun: false),
            record(kind: .cleanup, daysAgo: 0, bytes: 500, dryRun: true),
            record(kind: .scan, daysAgo: 0, bytes: 999, dryRun: true), // scans never count as freed
        ]
        let summary = ActivityImpactSummary(records)
        #expect(summary.realFreedBytes == 100)
        #expect(summary.simulatedFreedBytes == 500)
        #expect(summary.itemCount == 3)
    }
}

@Suite("Cloud Cleanup sync state")
struct CloudSyncStateTests {
    @Test("fully local file with no placeholder signal classifies local")
    func fullyLocal() {
        let state = CloudCleanupViewModel.SyncState.classify(logicalBytes: 1000, localBytes: 1000, isCloudPlaceholder: false)
        #expect(state == .local)
    }

    @Test("real ubiquitous placeholder signal always wins, even with stale byte counts")
    func placeholderSignalWins() {
        let state = CloudCleanupViewModel.SyncState.classify(logicalBytes: 1000, localBytes: 1000, isCloudPlaceholder: true)
        #expect(state == .placeholder)
    }

    @Test("mixed local/remote bytes without a placeholder signal is partial")
    func partialByRatio() {
        let state = CloudCleanupViewModel.SyncState.classify(logicalBytes: 1000, localBytes: 500, isCloudPlaceholder: false)
        #expect(state == .partial)
    }

    @Test("near-zero local bytes without explicit signal still reads as placeholder")
    func nearZeroLocalReadsPlaceholder() {
        let state = CloudCleanupViewModel.SyncState.classify(logicalBytes: 1000, localBytes: 10, isCloudPlaceholder: false)
        #expect(state == .placeholder)
    }
}
