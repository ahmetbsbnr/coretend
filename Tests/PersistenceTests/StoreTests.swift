// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import Persistence
import SafetyCore

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
        #expect(try await store.schemaVersion() == 7)
        // Re-opening must not re-run migrations or fail.
        let store2 = try Store(path: path)
        #expect(try await store2.schemaVersion() == 7)
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

    // MARK: - Timeline

    @Test func timelineSnapshotRoundTripSortsCategoriesByBytesDescending() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let id = try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "downloads", engine: "cleanup", logicalBytes: 100, fileCount: 2, risk: "low"),
            TimelineCategorySample(category: "xcodeDerivedData", engine: "cleanup", logicalBytes: 900,
                                    physicalBytes: 850, fileCount: 40, risk: "low"),
        ])
        let latest = try #require(try await store.latestTimelineSnapshot())
        #expect(latest.id == id)
        #expect(latest.totalBytes == 1_000)
        #expect(latest.trigger == "manual")
        #expect(latest.scope == "cleanup")
        let categories = try await store.timelineCategories(snapshotID: id)
        #expect(categories.map(\.category) == ["xcodeDerivedData", "downloads"], "largest first")
        #expect(categories.first?.physicalBytes == 850)
        #expect(categories.last?.physicalBytes == nil, "physical size is optional and survives as nil")
    }

    @Test func emptyScanStillRecordsAValidZeroByteSnapshot() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let id = try await store.recordTimelineSnapshot(scope: "privacy", samples: [])
        let latest = try #require(try await store.latestTimelineSnapshot(scope: "privacy"))
        #expect(latest.id == id)
        #expect(latest.totalBytes == 0)
        #expect(try await store.timelineCategories(snapshotID: id).isEmpty)
    }

    @Test func comparisonSincePreviousSnapshotNeedsAtLeastTwoSnapshotsOfTheSameScope() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        #expect(try await store.timelineComparisonSincePreviousSnapshot(scope: "cleanup") == nil)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "downloads", engine: "cleanup", logicalBytes: 100, fileCount: 1, risk: "low"),
        ])
        #expect(try await store.timelineComparisonSincePreviousSnapshot(scope: "cleanup") == nil,
                "only one snapshot exists in this scope")
    }

    @Test func comparisonSincePreviousSnapshotComputesPerCategoryDeltas() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "xcodeDerivedData", engine: "cleanup", logicalBytes: 1_000, fileCount: 3, risk: "low"),
        ])
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "xcodeDerivedData", engine: "cleanup", logicalBytes: 5_000, fileCount: 10, risk: "low"),
            TimelineCategorySample(category: "downloads", engine: "cleanup", logicalBytes: 2_000, fileCount: 1, risk: "low"),
        ])
        let comparison = try #require(try await store.timelineComparisonSincePreviousSnapshot(scope: "cleanup"))
        #expect(comparison.totalDeltaBytes == 6_000)
        let derived = comparison.categoryDeltas.first { $0.category == "xcodeDerivedData" }
        #expect(derived?.deltaBytes == 4_000)
        #expect(comparison.increases.map(\.category) == ["xcodeDerivedData", "downloads"], "largest increase first")
        let downloads = comparison.categoryDeltas.first { $0.category == "downloads" }
        #expect(downloads?.previousBytes == 0, "new category since baseline")
        #expect(downloads?.currentBytes == 2_000)
    }

    @Test func vanishedCategoryShowsAsAFullDecreaseNotOmitted() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "a", engine: "cleanup", logicalBytes: 500, fileCount: 1, risk: "low"),
            TimelineCategorySample(category: "b", engine: "cleanup", logicalBytes: 300, fileCount: 1, risk: "low"),
        ])
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "a", engine: "cleanup", logicalBytes: 500, fileCount: 1, risk: "low"),
            // "b" is gone entirely in this scan.
        ])
        let comparison = try #require(try await store.timelineComparisonSincePreviousSnapshot(scope: "cleanup"))
        let vanished = try #require(comparison.categoryDeltas.first { $0.category == "b" })
        #expect(vanished.currentBytes == 0)
        #expect(vanished.previousBytes == 300)
        #expect(vanished.deltaBytes == -300)
        #expect(comparison.decreases.map(\.category) == ["b"])
        let unchanged = try #require(comparison.categoryDeltas.first { $0.category == "a" })
        #expect(unchanged.deltaBytes == 0, "an unchanged category is reported, not dropped")
        #expect(comparison.increases.isEmpty)
        #expect(!comparison.decreases.contains { $0.category == "a" }, "zero delta is neither an increase nor a decrease")
    }

    @Test func decreaseIsReportedAsNegativeDelta() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "userCaches", engine: "cleanup", logicalBytes: 9_000, fileCount: 50, risk: "low"),
        ])
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "userCaches", engine: "cleanup", logicalBytes: 2_000, fileCount: 10, risk: "low"),
        ])
        let comparison = try #require(try await store.timelineComparisonSincePreviousSnapshot(scope: "cleanup"))
        #expect(comparison.totalDeltaBytes == -7_000)
        #expect(comparison.decreases.first?.category == "userCaches")
        #expect(comparison.decreases.first?.deltaBytes == -7_000)
        #expect(comparison.increases.isEmpty)
    }

    @Test func comparisonSinceReferenceDateFindsThePriorBaselineNotTheLatestSnapshot() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "downloads", engine: "cleanup", logicalBytes: 1_000, fileCount: 1, risk: "low"),
        ])
        let mark = Date()
        try await Task.sleep(nanoseconds: 10_000_000)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "downloads", engine: "cleanup", logicalBytes: 4_000, fileCount: 4, risk: "low"),
        ])
        let comparison = try #require(try await store.timelineComparison(scope: "cleanup", since: mark))
        #expect(comparison.baseline.totalBytes == 1_000)
        #expect(comparison.current.totalBytes == 4_000)
        #expect(comparison.totalDeltaBytes == 3_000)
        // "since right now" has no baseline old enough — the latest snapshot IS the candidate baseline.
        #expect(try await store.timelineComparison(scope: "cleanup", since: Date()) == nil)
    }

    @Test func comparisonsNeverMixDifferentScopes() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "a", engine: "cleanup", logicalBytes: 1_000, fileCount: 1, risk: "low"),
        ])
        // A different scope's scan happens in between — it must never become
        // the baseline for a "since previous cleanup scan" comparison.
        try await store.recordTimelineSnapshot(scope: "duplicates", samples: [
            TimelineCategorySample(category: "wastedSpace", engine: "duplicates", logicalBytes: 50, fileCount: 1, risk: "medium"),
        ])
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "a", engine: "cleanup", logicalBytes: 4_000, fileCount: 1, risk: "low"),
        ])
        let cleanupComparison = try #require(try await store.timelineComparisonSincePreviousSnapshot(scope: "cleanup"))
        #expect(cleanupComparison.baseline.totalBytes == 1_000)
        #expect(cleanupComparison.current.totalBytes == 4_000)
        #expect(cleanupComparison.baseline.scope == "cleanup")
        // Duplicates has exactly one snapshot ever — no baseline of its own yet.
        #expect(try await store.timelineComparisonSincePreviousSnapshot(scope: "duplicates") == nil)
    }

    @Test func latestComparisonAcrossScopesUsesTheMostRecentScansOwnScopeAsBaseline() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "a", engine: "cleanup", logicalBytes: 1_000, fileCount: 1, risk: "low"),
        ])
        try await store.recordTimelineSnapshot(scope: "duplicates", samples: [
            TimelineCategorySample(category: "wastedSpace", engine: "duplicates", logicalBytes: 50, fileCount: 1, risk: "medium"),
        ])
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "a", engine: "cleanup", logicalBytes: 4_000, fileCount: 1, risk: "low"),
        ])
        // Most recent overall is the second cleanup snapshot — its baseline
        // must be the first cleanup snapshot (1,000), never duplicates' 50.
        let comparison = try #require(try await store.latestTimelineComparisonAcrossScopes())
        #expect(comparison.current.totalBytes == 4_000)
        #expect(comparison.current.scope == "cleanup")
        #expect(comparison.baseline.totalBytes == 1_000)
        #expect(comparison.baseline.scope == "cleanup")
    }

    @Test func latestComparisonAcrossScopesIsNilWhenTheMostRecentScopeHasNoEarlierSnapshot() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "a", engine: "cleanup", logicalBytes: 1_000, fileCount: 1, risk: "low"),
        ])
        // Most recent overall is this "duplicates" scan, but it's the first
        // one ever in that scope — no baseline exists for it yet.
        try await store.recordTimelineSnapshot(scope: "duplicates", samples: [
            TimelineCategorySample(category: "wastedSpace", engine: "duplicates", logicalBytes: 50, fileCount: 1, risk: "medium"),
        ])
        #expect(try await store.latestTimelineComparisonAcrossScopes() == nil)
    }

    @Test func latestComparisonAcrossScopesIsNilWithNoHistoryAtAll() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        #expect(try await store.latestTimelineComparisonAcrossScopes() == nil)
    }

    @Test func clearTimelineHistoryRemovesSnapshotsAndCategoriesAcrossAllScopes() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let id = try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "downloads", engine: "cleanup", logicalBytes: 100, fileCount: 1, risk: "low"),
        ])
        try await store.recordTimelineSnapshot(scope: "privacy", samples: [
            TimelineCategorySample(category: "Chrome", engine: "privacy", logicalBytes: 50, fileCount: 1, risk: "low"),
        ])
        try await store.clearTimelineHistory()
        #expect(try await store.timelineSnapshots().isEmpty)
        #expect(try await store.timelineSnapshots(scope: "privacy").isEmpty)
        #expect(try await store.timelineCategories(snapshotID: id).isEmpty)
    }

    @Test func veryLargeByteValuesSurviveRoundTripWithoutOverflow() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let huge: Int64 = 5_000_000_000_000 // 5 TB — plausible for a whole-disk figure
        let id = try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "big", engine: "cleanup", logicalBytes: huge, physicalBytes: huge,
                                    fileCount: 1, risk: "low"),
        ])
        let latest = try #require(try await store.latestTimelineSnapshot(scope: "cleanup"))
        #expect(latest.id == id)
        #expect(latest.totalBytes == huge)
        let category = try #require(try await store.timelineCategories(snapshotID: id).first)
        #expect(category.logicalBytes == huge)
        #expect(category.physicalBytes == huge)
    }

    @Test func recordingManySnapshotsKeepsAllWithinRetentionWindow() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        for i in 0..<10 {
            try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
                TimelineCategorySample(category: "c", engine: "cleanup", logicalBytes: Int64(i), fileCount: 1, risk: "low"),
            ])
        }
        #expect(try await store.timelineSnapshots(scope: "cleanup", limit: 100).count == 10, "all recent, none pruned")
    }

    @Test func retentionPrunesSnapshotsOlderThanNinetyDaysButKeepsTheFiveMostRecent() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let now = Date()
        // 10 snapshots, all 100 days old (past the 90-day cutoff), oldest
        // first, one second apart so ordering is unambiguous.
        for i in 0..<10 {
            let date = now.addingTimeInterval(-100 * 24 * 3600 + Double(i))
            try await store.recordTimelineSnapshot(
                scope: "cleanup", date: date,
                samples: [TimelineCategorySample(category: "c", engine: "cleanup", logicalBytes: Int64(i),
                                                  fileCount: 1, risk: "low")])
        }
        let remaining = try await store.timelineSnapshots(scope: "cleanup", limit: 100)
        #expect(remaining.count == 5, "past the cutoff, only the minimum-keep count survives")
        // The 5 kept must be the 5 most recent of the 10 (the last-inserted,
        // i.e. logicalBytes 5...9) — not an arbitrary 5.
        let keptCategoryBytes = try await withThrowingTaskGroup(of: Int64?.self) { group in
            for snapshot in remaining {
                group.addTask { try await store.timelineCategories(snapshotID: snapshot.id).first?.logicalBytes }
            }
            var values: [Int64] = []
            for try await value in group { if let value { values.append(value) } }
            return values.sorted()
        }
        #expect(keptCategoryBytes == [5, 6, 7, 8, 9])
    }

    @Test func retentionKeepsRecentSnapshotsEvenBeyondTheMinimumCount() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        // 8 snapshots, all within the last few days — none should be pruned
        // even though there are more than the "keep at least 5" minimum.
        for i in 0..<8 {
            try await store.recordTimelineSnapshot(scope: "cleanup", date: Date(), samples: [
                TimelineCategorySample(category: "c", engine: "cleanup", logicalBytes: Int64(i), fileCount: 1, risk: "low"),
            ])
        }
        #expect(try await store.timelineSnapshots(scope: "cleanup", limit: 100).count == 8)
    }

    @Test func retentionAppliesIndependentlyPerScope() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let old = Date().addingTimeInterval(-100 * 24 * 3600)
        // 6 old "cleanup" snapshots: past the min-keep-5, so pruning trims one.
        for i in 0..<6 {
            try await store.recordTimelineSnapshot(
                scope: "cleanup", date: old.addingTimeInterval(Double(i)),
                samples: [TimelineCategorySample(category: "c", engine: "cleanup", logicalBytes: Int64(i),
                                                  fileCount: 1, risk: "low")])
        }
        // One old "duplicates" snapshot: below its own scope's min-keep-5,
        // so cleanup's pruning must not touch it.
        try await store.recordTimelineSnapshot(scope: "duplicates", date: old, samples: [
            TimelineCategorySample(category: "wastedSpace", engine: "duplicates", logicalBytes: 1, fileCount: 1, risk: "medium"),
        ])
        #expect(try await store.timelineSnapshots(scope: "cleanup", limit: 100).count == 5)
        #expect(try await store.timelineSnapshots(scope: "duplicates", limit: 100).count == 1,
                "a different, rarely-scanned scope is not pruned away by another scope's activity")
    }
}
