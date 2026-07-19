import Testing
import Foundation
@testable import Persistence

private func tempDBPath() -> String {
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("maccare-db-\(UUID().uuidString).sqlite").path
}

@Suite("Store")
struct StoreTests {
    @Test func migrationsApplyOnceAndAreIdempotent() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        #expect(try await store.schemaVersion() == 1)
        // Re-opening must not re-run migrations or fail.
        let store2 = try Store(path: path)
        #expect(try await store2.schemaVersion() == 1)
    }

    @Test func activityRoundTrip() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordActivity(ActivityRecord(
            kind: .cleanup, summary: "Dry run cleanup", itemCount: 12, bytes: 1_234_567, dryRun: true))
        try await store.recordActivity(ActivityRecord(
            kind: .scan, summary: "Cleanup scan", itemCount: 500, bytes: 9_999, dryRun: true))
        let all = try await store.activity()
        #expect(all.count == 2)
        #expect(all.first?.kind == .scan, "newest first")
        let cleanups = try await store.activity(kind: .cleanup)
        #expect(cleanups.count == 1)
        #expect(cleanups.first?.bytes == 1_234_567)
        #expect(cleanups.first?.dryRun == true)
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

    @Test func settingsUpsert() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        #expect(try await store.setting("dryRun") == nil)
        try await store.setSetting("dryRun", value: "true")
        try await store.setSetting("dryRun", value: "false")
        #expect(try await store.setting("dryRun") == "false")
    }

    @Test func unicodeSummarySurvives() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordActivity(ActivityRecord(
            kind: .error, summary: "Échec — fichier « été🙂 »", itemCount: 0, bytes: 0, dryRun: true))
        #expect(try await store.activity().first?.summary == "Échec — fichier « été🙂 »")
    }
}
