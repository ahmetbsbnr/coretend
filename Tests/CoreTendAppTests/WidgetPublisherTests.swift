// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import Persistence
import WidgetShared
@testable import CoreTendApp

private final class SpyReloader: WidgetReloading, @unchecked Sendable {
    private(set) var count = 0
    func reload() { count += 1 }
}

private func tempStore() throws -> Store {
    try Store(path: FileManager.default.temporaryDirectory
        .appendingPathComponent("wp-\(UUID().uuidString).sqlite").path)
}

private func tempDir() -> URL {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent("wp-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

@Suite("WidgetPublisher — pure snapshot assembly")
struct WidgetPublisherSnapshotTests {
    @Test func carriesEveryFieldThrough() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let s = WidgetPublisher.snapshot(
            freeBytes: 42, totalBytes: 100, reclaimableBytes: 8, sinceLastScanDeltaBytes: -3,
            lastScanDate: Date(timeIntervalSince1970: 1_699_000_000), lastActivityKind: "cleanup", now: now)
        #expect(s.generatedAt == now)
        #expect(s.freeBytes == 42)
        #expect(s.reclaimableBytes == 8)
        #expect(s.sinceLastScanDeltaBytes == -3)
        #expect(s.lastActivityKind == "cleanup")
        #expect(s.schemaVersion == WidgetSnapshot.currentSchemaVersion)
    }
}

@Suite("WidgetPublisher — gather & publish")
struct WidgetPublisherGatherTests {
    @Test func publishesADerivedSnapshotAndReloadsOnceOnSuccess() async throws {
        let store = try tempStore()
        // Seed a completed cleanup scan + an activity row, like a real scan would.
        try await store.recordTimelineSnapshot(scope: "cleanup", trigger: "manual", samples: [
            TimelineCategorySample(category: "user.caches", engine: "cleanup", logicalBytes: 9_000_000_000,
                                    physicalBytes: nil, fileCount: 3, risk: "low"),
        ])
        _ = try await store.recordActivity(ActivityRecord(kind: .cleanup, summary: "x", itemCount: 1, bytes: 1))

        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let widgetStore = WidgetSnapshotStore(directory: dir)
        let reloader = SpyReloader()

        let published = await WidgetPublisher.gatherAndPublish(
            store: store, freeBytes: 40_000_000_000, totalBytes: 500_000_000_000,
            widgetStore: widgetStore, reloader: reloader)

        let snapshot = try #require(published)
        #expect(snapshot.freeBytes == 40_000_000_000)
        #expect(snapshot.reclaimableBytes == 9_000_000_000, "from the latest cleanup Timeline snapshot")
        #expect(snapshot.lastActivityKind == "cleanup")
        #expect(reloader.count == 1)

        // The published file round-trips (dates within Double-serialization tolerance).
        guard case let .snapshot(readBack) = widgetStore.read() else { Issue.record("not readable"); return }
        #expect(readBack.freeBytes == snapshot.freeBytes)
        #expect(readBack.totalBytes == snapshot.totalBytes)
        #expect(readBack.reclaimableBytes == snapshot.reclaimableBytes)
        #expect(readBack.sinceLastScanDeltaBytes == snapshot.sinceLastScanDeltaBytes)
        #expect(readBack.lastActivityKind == snapshot.lastActivityKind)
        #expect(readBack.schemaVersion == snapshot.schemaVersion)
        #expect(abs(readBack.generatedAt.timeIntervalSince(snapshot.generatedAt)) < 0.001)
    }

    @Test func nilStorePublishesNothing() async throws {
        let reloader = SpyReloader()
        let published = await WidgetPublisher.gatherAndPublish(
            store: nil, freeBytes: 1, totalBytes: 2,
            widgetStore: WidgetSnapshotStore(directory: tempDir()), reloader: reloader)
        #expect(published == nil)
        #expect(reloader.count == 0)
    }

    @Test func aFailedWriteDoesNotReloadTheWidget() async throws {
        let store = try tempStore()
        let reloader = SpyReloader()
        // App Group container unavailable -> write() returns false.
        let published = await WidgetPublisher.gatherAndPublish(
            store: store, freeBytes: 1, totalBytes: 2,
            widgetStore: WidgetSnapshotStore(containerURL: nil), reloader: reloader)
        #expect(published == nil)
        #expect(reloader.count == 0, "no reload when nothing was published")
    }

    @Test func theSnapshotFileNeverContainsAPathLikeString() async throws {
        let store = try tempStore()
        try await store.recordTimelineSnapshot(scope: "cleanup", trigger: "manual", samples: [
            TimelineCategorySample(category: "user.caches", engine: "cleanup", logicalBytes: 1,
                                    physicalBytes: nil, fileCount: 1, risk: "low"),
        ])
        _ = try await store.recordActivity(ActivityRecord(kind: .restore, summary: "restored /Users/x/secret", itemCount: 1, bytes: 1))

        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let widgetStore = WidgetSnapshotStore(directory: dir)
        _ = await WidgetPublisher.gatherAndPublish(store: store, freeBytes: 1, totalBytes: 2,
                                                   widgetStore: widgetStore, reloader: SpyReloader())
        let json = try String(contentsOf: try #require(widgetStore.fileURL), encoding: .utf8)
        #expect(!json.contains("/Users/"))
        #expect(!json.contains("secret"))
        #expect(!json.contains(NSHomeDirectory()))
        // Only the activity KIND leaks, never its summary.
        #expect(json.contains("restore"))
        #expect(!json.contains("restored /Users"))
    }
}
