// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import SafetyCore
@testable import Persistence

private func tempDBPath() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent("restore-\(UUID().uuidString).sqlite").path
}

private func record(op: UUID = UUID(), original: String = "/Users/x/Downloads/a.txt",
                    trash: String = "/Users/x/.Trash/a.txt", dir: Bool = false,
                    size: Int64 = 10, inode: String? = "12345", volume: String? = "VOL-UUID",
                    date: Date = Date()) -> RestoreManifestRecord {
    RestoreManifestRecord(
        operationID: op, originalURL: URL(fileURLWithPath: original), trashURL: URL(fileURLWithPath: trash),
        isDirectory: dir, sizeBytes: size, modificationDate: date, volumeUUID: volume, inode: inode,
        ruleID: "user.caches", risk: .low, date: date)
}

@Suite("Restore manifest — migration")
struct RestoreManifestMigrationTests {
    @Test func migrationBringsSchemaToV7AndIsIdempotent() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        #expect(try await store.schemaVersion() == 7)
        // Re-opening the same file must not re-run migrations or fail.
        let reopened = try Store(path: path)
        #expect(try await reopened.schemaVersion() == 7)
        // And the table is usable after a reopen.
        #expect(try await reopened.restoreManifestCount() == 0)
    }
}

@Suite("Restore manifest — persistence")
struct RestoreManifestPersistenceTests {
    @Test func insertThenQueryRoundTripsEveryField() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let op = UUID()
        await store.recordRestoreManifest(record(op: op, original: "/Users/x/Documents/report.pdf",
                                                 trash: "/Users/x/.Trash/report.pdf", dir: false,
                                                 size: 4096, inode: "99", volume: "V1"))
        let items = try await store.restoreManifestItems()
        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.operationID == op.uuidString)
        #expect(item.originalPath == "/Users/x/Documents/report.pdf")
        #expect(item.trashPath == "/Users/x/.Trash/report.pdf")
        #expect(item.sizeBytes == 4096)
        #expect(item.inode == "99")
        #expect(item.volumeUUID == "V1")
        #expect(item.isDirectory == false)
        #expect(item.state == .available)
        #expect(item.restoredAt == nil)
        #expect(!item.id.isEmpty)
    }

    @Test func stateUpdateSetsRestoredAtOnlyWhenGiven() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        await store.recordRestoreManifest(record())
        let id = try #require(try await store.restoreManifestItems().first?.id)

        try await store.setRestoreManifestState(id: id, state: .missingFromTrash)
        var item = try #require(try await store.restoreManifestItem(id: id))
        #expect(item.state == .missingFromTrash)
        #expect(item.restoredAt == nil)

        let when = Date()
        try await store.setRestoreManifestState(id: id, state: .restored, restoredAt: when)
        item = try #require(try await store.restoreManifestItem(id: id))
        #expect(item.state == .restored)
        #expect(item.restoredAt != nil)
    }

    @Test func clearRemovesEveryManifestRow() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        await store.recordRestoreManifest(record())
        await store.recordRestoreManifest(record(original: "/Users/x/Downloads/b.txt"))
        #expect(try await store.restoreManifestCount() == 2)
        try await store.clearRestoreManifests()
        #expect(try await store.restoreManifestCount() == 0)
    }
}

@Suite("Restore manifest — retention")
struct RestoreManifestRetentionTests {
    @Test func rowsOlderThanNinetyDaysArePrunedRegardlessOfState() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let old = Date().addingTimeInterval(-100 * 24 * 3600)
        await store.recordRestoreManifest(record(original: "/Users/x/old.txt", date: old))
        await store.recordRestoreManifest(record(original: "/Users/x/fresh.txt", date: Date()))
        try await store.pruneRestoreManifests()
        let paths = try await store.restoreManifestItems().map(\.originalPath)
        #expect(paths == ["/Users/x/fresh.txt"])
    }

    @Test func nonAvailableRowsArePrunedAfterThirtyDaysWhileAvailableRowsSurvive() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let fortyDaysAgo = Date().addingTimeInterval(-40 * 24 * 3600)
        await store.recordRestoreManifest(record(original: "/Users/x/stillHere.txt", date: fortyDaysAgo))
        await store.recordRestoreManifest(record(original: "/Users/x/gone.txt", date: fortyDaysAgo))
        let gone = try #require(try await store.restoreManifestItems()
            .first { $0.originalPath == "/Users/x/gone.txt" }?.id)
        // Mark it terminal, with a check time also 40 days ago.
        try await store.setRestoreManifestState(id: gone, state: .missingFromTrash,
                                                checkedAt: fortyDaysAgo)
        try await store.pruneRestoreManifests()
        let paths = Set(try await store.restoreManifestItems().map(\.originalPath))
        #expect(paths == ["/Users/x/stillHere.txt"], "an available 40-day-old row stays; a terminal one is pruned")
    }
}
