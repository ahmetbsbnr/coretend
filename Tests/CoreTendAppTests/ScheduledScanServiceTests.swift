// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import FileRules
import Persistence
@testable import CoreTendApp

private struct Fixture {
    let home: URL
    let store: Store

    init() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("sched-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        store = try Store(path: home.appendingPathComponent("store.sqlite").path)
    }

    func cleanup() { try? FileManager.default.removeItem(at: home) }

    /// A stale log file that `user.logs` (low-risk, >7 days) will find.
    @discardableResult
    func staleLog(_ relative: String, bytes: Int) throws -> URL {
        let url = home.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(String(repeating: "x", count: bytes).utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-10 * 86_400)], ofItemAtPath: url.path)
        return url
    }
}

@Suite("ScheduledScanService — read-only, cancellable, Timeline-writing")
struct ScheduledScanServiceTests {
    @Test func aCompletedScanWritesAScheduledCleanupSnapshotAndAScanActivity() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.staleLog("Library/Logs/old.log", bytes: 4096)
        let service = ScheduledScanService(store: fx.store, home: fx.home)

        let result = await service.run(rules: UserCleanupRules.all)
        #expect(result.isCompleted)
        if case let .completed(reclaimable, _) = result {
            #expect(reclaimable >= 4096)
        }
        let snapshots = try await fx.store.timelineSnapshots(scope: "cleanup")
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.trigger == "scheduled")
        let scanActivity = try await fx.store.activity(kind: .scan)
        #expect(scanActivity.count == 1)
        #expect(scanActivity.first?.summary.contains("Scheduled") == true)
    }

    @Test func aScheduledScanNeverDeletesOrMovesAnything() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        let a = try fx.staleLog("Library/Logs/a.log", bytes: 2048)
        let b = try fx.staleLog("Library/Caches/App/data.cache", bytes: 8192)
        let c = try fx.staleLog("Library/Logs/nested/c.log", bytes: 1024)

        _ = await ScheduledScanService(store: fx.store, home: fx.home).run(rules: UserCleanupRules.all)

        for url in [a, b, c] {
            #expect(FileManager.default.fileExists(atPath: url.path),
                    "a scheduled scan is read-only — \(url.lastPathComponent) must still be on disk")
        }
    }

    @Test func aCancelledScanWritesNoSnapshotAndNoActivity() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.staleLog("Library/Logs/old.log", bytes: 4096)
        let service = ScheduledScanService(store: fx.store, home: fx.home)

        let result = await service.run(rules: UserCleanupRules.all, isCancelled: { true })
        #expect(result == .cancelled)
        #expect(try await fx.store.timelineSnapshots(scope: "cleanup").isEmpty)
        #expect(try await fx.store.activity(kind: .scan).isEmpty)
    }

    @Test func anOverlappingSecondRunIsSkipped() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        // Enough stale files that the scan has real work and yields at least
        // once, giving the actor a reentrancy point.
        for i in 0..<40 { try fx.staleLog("Library/Logs/log-\(i).log", bytes: 512) }
        let service = ScheduledScanService(store: fx.store, home: fx.home)

        async let first = service.run(rules: UserCleanupRules.all)
        async let second = service.run(rules: UserCleanupRules.all)
        let results = await [first, second]

        #expect(results.contains(.skippedAlreadyRunning), "the second concurrent run must be dropped")
        #expect(results.contains { $0.isCompleted })
        // Exactly one snapshot, from the run that actually completed.
        #expect(try await fx.store.timelineSnapshots(scope: "cleanup").count == 1)
    }

    @Test func growthIsReportedOnlyWhenTheTotalActuallyIncreased() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.staleLog("Library/Logs/old.log", bytes: 10_000)
        // A previous, smaller cleanup snapshot to compare against.
        try await fx.store.recordTimelineSnapshot(scope: "cleanup", trigger: "manual", samples: [
            TimelineCategorySample(category: "user.logs", engine: "cleanup", logicalBytes: 1_000,
                                    physicalBytes: nil, fileCount: 1, risk: "low"),
        ])
        let result = await ScheduledScanService(store: fx.store, home: fx.home).run(rules: UserCleanupRules.all)
        if case let .completed(_, growth) = result {
            #expect((growth ?? 0) > 0, "the new scan found more than the baseline")
        } else {
            Issue.record("expected .completed")
        }
    }

    @Test func anEmptyHomeStillCompletesWithAZeroSnapshotNotAFailure() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        let result = await ScheduledScanService(store: fx.store, home: fx.home).run(rules: UserCleanupRules.all)
        #expect(result == .completed(reclaimableBytes: 0, growthBytes: nil))
        #expect(try await fx.store.timelineSnapshots(scope: "cleanup").count == 1,
                "an empty scan is a real data point, not a missing one")
    }
}

@Suite("ScanCadence")
struct ScanCadenceTests {
    @Test func onlyThreeCadencesAndOffHasNoInterval() {
        #expect(ScanCadence.allCases == [.off, .daily, .weekly])
        #expect(ScanCadence.off.interval == nil)
        #expect(ScanCadence.daily.interval == 24.0 * 3600)
        #expect(ScanCadence.weekly.interval == 7.0 * 24 * 3600)
    }
}
