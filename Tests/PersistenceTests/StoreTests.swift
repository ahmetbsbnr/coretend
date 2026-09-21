// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import Persistence
import SafetyCore
import SQLite3

private func tempDBPath() -> String {
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("coretend-db-\(UUID().uuidString).sqlite").path
}

@Suite("Store")
struct StoreTests {
    @Test func migrationsApplyOnceAndAreIdempotent() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        #expect(try await store.schemaVersion() == 4)
        // Re-opening must not re-run migrations or fail.
        let store2 = try Store(path: path)
        #expect(try await store2.schemaVersion() == 4)
    }

    @Test func activityRoundTrip() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordActivity(ActivityRecord(
            kind: .cleanup, summary: "Completed cleanup", itemCount: 12, bytes: 1_234_567))
        try await store.recordActivity(ActivityRecord(
            kind: .scan, summary: "Cleanup scan", itemCount: 500, bytes: 9_999))
        let all = try await store.activity()
        #expect(all.count == 2)
        #expect(all.first?.kind == .scan, "newest first")
        let cleanups = try await store.activity(kind: .cleanup)
        #expect(cleanups.count == 1)
        #expect(cleanups.first?.bytes == 1_234_567)
        try await store.clearActivity()
        #expect(try await store.activity().isEmpty)
    }

    @Test func exclusionsUniqueAndRemovable() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.addExclusion(path: "/tmp/a")
        try await store.addExclusion(path: "/tmp/a")
        try await store.addExclusion(path: "/tmp/b")
        #expect(try await store.exclusions() == ["/tmp/a", "/tmp/b"])
        try await store.removeExclusion(path: "/tmp/a")
        #expect(try await store.exclusions() == ["/tmp/b"])
    }

    @Test func favoritesAddRemoveAndOrder() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.addFavorite(path: "/Users/x/Downloads")
        try await store.addFavorite(path: "/Users/x/Desktop")
        try await store.addFavorite(path: "/Users/x/Downloads") // idempotent
        let favs = try await store.favorites()
        #expect(favs.map(\.path) == ["/Users/x/Desktop", "/Users/x/Downloads"])
        #expect(favs.allSatisfy { $0.isFavorite })
        try await store.removeFavorite(path: "/Users/x/Desktop")
        #expect(try await store.favorites().map(\.path) == ["/Users/x/Downloads"])
    }

    @Test func recentsOrderedByMostRecentAndRespectsLimit() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordLocationVisit(path: "/tmp/one", bytes: 100)
        try await store.recordLocationVisit(path: "/tmp/two", bytes: 200)
        try await store.recordLocationVisit(path: "/tmp/one", bytes: 150) // re-visit bumps it to newest
        let recents = try await store.recents(limit: 10)
        #expect(recents.map(\.path) == ["/tmp/one", "/tmp/two"])
        #expect(recents.first?.lastBytes == 150)
        let limited = try await store.recents(limit: 1)
        #expect(limited.map(\.path) == ["/tmp/one"])
    }

    @Test func removingRecentPrunesRowUnlessFavorited() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordLocationVisit(path: "/tmp/a", bytes: 10)
        try await store.removeRecent(path: "/tmp/a")
        #expect(try await store.recents().isEmpty)

        // A favorite that was also scanned keeps its favorite row after the
        // recent side is cleared — only a fully-empty row gets pruned.
        try await store.addFavorite(path: "/tmp/b")
        try await store.recordLocationVisit(path: "/tmp/b", bytes: 20)
        try await store.removeRecent(path: "/tmp/b")
        #expect(try await store.recents().isEmpty)
        #expect(try await store.favorites().map(\.path) == ["/tmp/b"])
    }

    @Test func favoriteAndRecentAreIndependentSignals() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.addFavorite(path: "/tmp/c")
        try await store.recordLocationVisit(path: "/tmp/c", bytes: 30)
        let favs = try await store.favorites()
        let recents = try await store.recents()
        #expect(favs.first?.path == "/tmp/c" && favs.first?.lastBytes == 30)
        #expect(recents.first?.path == "/tmp/c" && recents.first?.isFavorite == true)
        // Un-favoriting keeps the recent row alive since scan history remains.
        try await store.removeFavorite(path: "/tmp/c")
        #expect(try await store.favorites().isEmpty)
        #expect(try await store.recents().map(\.path) == ["/tmp/c"])
    }

    @Test func settingsUpsert() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        #expect(try await store.setting("theme") == nil)
        try await store.setSetting("theme", value: "system")
        try await store.setSetting("theme", value: "dark")
        #expect(try await store.setting("theme") == "dark")
    }

    @Test func unicodeSummarySurvives() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordActivity(ActivityRecord(
            kind: .error, summary: "Échec — fichier « été🙂 »", itemCount: 0, bytes: 0))
        #expect(try await store.activity().first?.summary == "Échec — fichier « été🙂 »")
    }

    // MARK: - Safety log (append-only)

    @Test func safetyLogPersistsApprovedThenExecuted() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let opID = UUID()
        await store.recordSafetyEvent(SafetyAuditEvent(
            operationID: opID, stage: .approved, path: "/Users/alice/Downloads/foo.zip",
            ruleID: "downloads.archives", risk: .low, size: 1024, result: "approved"))
        await store.recordSafetyEvent(SafetyAuditEvent(
            operationID: opID, stage: .executed, path: "/Users/alice/Downloads/foo.zip",
            ruleID: "downloads.archives", risk: .low, size: 1024, result: "moved to trash"))
        let log = try await store.safetyLog()
        #expect(log.count == 2)
        #expect(log.contains { $0.stage == .approved })
        #expect(log.contains { $0.stage == .executed })
    }

    @Test func safetyLogNeverStoresRawHomePath() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let home = NSHomeDirectory()
        await store.recordSafetyEvent(SafetyAuditEvent(
            operationID: UUID(), stage: .executed, path: "\(home)/Documents/secret-project/notes.txt",
            ruleID: "cleanup.rule", risk: .medium, size: 42, result: "moved to trash"))
        let entry = try await store.safetyLog().first
        #expect(entry != nil)
        #expect(entry?.redactedPath.hasPrefix("<home>") == true)
        #expect(entry?.redactedPath.contains(home) == false)
        #expect(entry?.redactedPath.contains("notes.txt") == true, "shape is kept, just the personal prefix is redacted")
    }

    @Test func safetyLogSurvivesRelaunch() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        do {
            let store = try Store(path: path)
            await store.recordSafetyEvent(SafetyAuditEvent(
                operationID: UUID(), stage: .executed, path: "/tmp/a", ruleID: "r", risk: .low, size: 1, result: "ok"))
        }
        // Fresh Store instance over the same file — simulates an app relaunch.
        let reopened = try Store(path: path)
        #expect(try await reopened.safetyLog().count == 1)
    }

    @Test func safetyLogPurgeIsAllOrNothing() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        for _ in 0..<3 {
            await store.recordSafetyEvent(SafetyAuditEvent(
                operationID: UUID(), stage: .skipped, path: "/tmp/x", ruleID: "r", risk: .low, size: 0, result: "fileVanished"))
        }
        #expect(try await store.safetyLog().count == 3)
        try await store.purgeSafetyLog()
        #expect(try await store.safetyLog().isEmpty)
    }
}

@Suite("Audit log durability")
struct AuditLogDurabilityTests {
    /// A failed `safety_log` insert must stop being invisible.
    ///
    /// The sink is non-throwing by protocol on purpose — an audit sink must
    /// not abort the operation it records — and that was read as licence to
    /// swallow the error with `try?`. A file could reach the Trash with no
    /// record, in the product whose thesis is that the record exists.
    ///
    /// The failure is real, not mocked: a second SQLite connection drops the
    /// table underneath the live store. Making the file read-only does not
    /// work — the database runs in WAL mode with its handles already open, so
    /// `chmod` after opening changes nothing and the write succeeds.
    @Test func aFailedWriteIsCountedInsteadOfSwallowed() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-audit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("store.sqlite").path
        let store = try Store(path: path)

        let event = SafetyAuditEvent(operationID: UUID(), stage: .approved, path: "/tmp/a",
                                     ruleID: "user.caches", risk: .low, size: 1, result: "approved")
        await store.recordSafetyEvent(event)
        #expect(await store.unrecordedEventCount == 0, "a healthy write was counted as lost")

        var other: OpaquePointer?
        #expect(sqlite3_open_v2(path, &other, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK)
        defer { sqlite3_close(other) }
        #expect(sqlite3_exec(other, "DROP TABLE safety_log", nil, nil, nil) == SQLITE_OK)

        await store.recordSafetyEvent(event)
        #expect(await store.unrecordedEventCount == 1,
                "a failed audit write left no trace — the Record cannot say it is short")
    }
}
