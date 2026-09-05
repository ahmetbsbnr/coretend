// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SafetyCore

/// A favorite folder, a recently-scanned one, or both — path is the identity.
public struct LocationRecord: Sendable, Identifiable, Equatable {
    public var id: String { path }
    public let path: String
    public let isFavorite: Bool
    public let lastScanned: Date?
    public let lastBytes: Int64?

    public init(path: String, isFavorite: Bool, lastScanned: Date?, lastBytes: Int64?) {
        self.path = path
        self.isFavorite = isFavorite
        self.lastScanned = lastScanned
        self.lastBytes = lastBytes
    }
}

/// One recorded activity entry (scan, cleanup, restore, error…).
public struct ActivityRecord: Sendable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case scan, cleanup, restore, error
    }

    public let id: Int64
    public let kind: Kind
    public let date: Date
    public let summary: String
    public let itemCount: Int
    public let bytes: Int64

    public init(id: Int64 = 0, kind: Kind, date: Date = Date(), summary: String,
                itemCount: Int, bytes: Int64) {
        self.id = id
        self.kind = kind
        self.date = date
        self.summary = summary
        self.itemCount = itemCount
        self.bytes = bytes
    }
}

/// One category's aggregated footprint as observed by one scan, ready to be
/// recorded as part of a Timeline snapshot. No file paths — only a category
/// identifier (a rule ID or engine-defined bucket name) and aggregated
/// numbers.
public struct TimelineCategorySample: Sendable {
    public let category: String
    public let engine: String
    public let logicalBytes: Int64
    public let physicalBytes: Int64?
    public let fileCount: Int
    public let risk: String

    public init(category: String, engine: String, logicalBytes: Int64,
                physicalBytes: Int64? = nil, fileCount: Int, risk: String) {
        self.category = category
        self.engine = engine
        self.logicalBytes = logicalBytes
        self.physicalBytes = physicalBytes
        self.fileCount = fileCount
        self.risk = risk
    }
}

/// One recorded Timeline snapshot — the point-in-time total one scan
/// methodology (`scope`) produced. Only ever comparable to another snapshot
/// with the same `scope`.
public struct TimelineSnapshotRecord: Sendable, Identifiable, Equatable {
    public let id: Int64
    public let date: Date
    public let trigger: String
    public let scope: String
    public let totalBytes: Int64
}

/// One category row belonging to a `TimelineSnapshotRecord`.
public struct TimelineCategoryRecord: Sendable, Identifiable, Equatable {
    public let id: Int64
    public let snapshotID: Int64
    public let category: String
    public let engine: String
    public let logicalBytes: Int64
    public let physicalBytes: Int64?
    public let fileCount: Int
    public let risk: String
}

/// One category's change between two snapshots. `previousBytes`/`currentBytes`
/// is 0 on whichever side the category wasn't observed (new since baseline,
/// or gone by the current snapshot).
public struct TimelineCategoryDelta: Sendable, Identifiable, Equatable {
    public let category: String
    public let engine: String
    public let currentBytes: Int64
    public let previousBytes: Int64
    public var id: String { engine + "." + category }
    public var deltaBytes: Int64 { currentBytes - previousBytes }
}

/// The result of comparing two Timeline snapshots of the same scope.
public struct TimelineComparison: Sendable, Equatable {
    public let current: TimelineSnapshotRecord
    public let baseline: TimelineSnapshotRecord
    /// Sorted largest increase first, largest decrease last.
    public let categoryDeltas: [TimelineCategoryDelta]
    public var totalDeltaBytes: Int64 { current.totalBytes - baseline.totalBytes }

    /// Categories that grew, largest increase first.
    public var increases: [TimelineCategoryDelta] {
        categoryDeltas.filter { $0.deltaBytes > 0 }
    }

    /// Categories that shrank, largest decrease first.
    public var decreases: [TimelineCategoryDelta] {
        categoryDeltas.filter { $0.deltaBytes < 0 }.sorted { $0.deltaBytes < $1.deltaBytes }
    }
}

/// Application-wide persistent store. All access is actor-isolated.
public actor Store {
    private let db: Database

    /// Ordered, append-only migrations. Never edit a shipped entry; append a new one.
    private static let migrations: [String] = [
        // v1
        """
        CREATE TABLE activity (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            date REAL NOT NULL,
            summary TEXT NOT NULL,
            item_count INTEGER NOT NULL DEFAULT 0,
            bytes INTEGER NOT NULL DEFAULT 0,
            dry_run INTEGER NOT NULL DEFAULT 1
        );
        CREATE TABLE exclusions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT NOT NULL UNIQUE,
            created REAL NOT NULL
        );
        CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """,
        // v2 — append-only SafetyCore audit log. Rows are never updated;
        // purgeSafetyLog() is the only deletion path, and it's an explicit
        // all-or-nothing user action, never automatic.
        """
        CREATE TABLE safety_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_id TEXT NOT NULL,
            stage TEXT NOT NULL,
            redacted_path TEXT NOT NULL,
            rule_id TEXT NOT NULL,
            risk TEXT NOT NULL,
            size INTEGER NOT NULL DEFAULT 0,
            date REAL NOT NULL,
            result TEXT NOT NULL
        );
        CREATE INDEX idx_safety_log_date ON safety_log(date);
        """,
        // v3 — favorites and recently-scanned locations (Favorites & Recents).
        // One table for both: a favorite with no scan history and a recent with
        // no favorite flag are both real, distinct rows; a row with neither is
        // pruned rather than kept as a zeroed-out ghost.
        """
        CREATE TABLE locations (
            path TEXT PRIMARY KEY,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            last_scanned REAL,
            last_bytes INTEGER,
            created REAL NOT NULL
        );
        CREATE INDEX idx_locations_last_scanned ON locations(last_scanned);
        """,
        // v4 — remove the retired product preview setting. The original
        // activity column and audit rows remain on disk for downgrade/data
        // compatibility, but current APIs neither expose nor create them.
        """
        DELETE FROM settings WHERE key = 'dryRunDefault';
        """,
        // v5 — Storage Timeline: category-level snapshots of scan results, so
        // "what changed since my last scan?" can be answered from history
        // instead of a single point-in-time total. Deliberately no file paths
        // anywhere in this schema — only a category identifier (a rule ID or
        // engine-defined bucket name) and aggregated numbers, so Timeline
        // history can never become a sensitive per-file audit trail. No
        // FOREIGN KEY, to match this file's existing style; child rows are
        // deleted explicitly alongside their snapshot (pruneTimelineSnapshots,
        // clearTimelineHistory).
        """
        CREATE TABLE IF NOT EXISTS timeline_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date REAL NOT NULL,
            trigger TEXT NOT NULL,
            total_bytes INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_timeline_snapshots_date ON timeline_snapshots(date);
        CREATE TABLE IF NOT EXISTS timeline_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            snapshot_id INTEGER NOT NULL,
            category TEXT NOT NULL,
            engine TEXT NOT NULL,
            logical_bytes INTEGER NOT NULL,
            physical_bytes INTEGER,
            file_count INTEGER NOT NULL DEFAULT 0,
            risk TEXT NOT NULL DEFAULT 'unknown'
        );
        CREATE INDEX IF NOT EXISTS idx_timeline_categories_snapshot ON timeline_categories(snapshot_id);
        CREATE INDEX IF NOT EXISTS idx_timeline_categories_category ON timeline_categories(category);
        """,
        // v6 — Timeline scope: which scan methodology produced a snapshot
        // ("cleanup", "duplicates", "leftovers", "privacy", …). Two snapshots
        // are only ever comparable within the same scope — a Cleanup scan
        // covers a fixed set of system-cache rules, a Duplicates scan covers
        // wasted-space-from-copies in a different fixed root set, and neither
        // represents "total storage"; summing or diffing across scopes would
        // silently misrepresent disk usage. Every row written before this
        // column existed came only from Cleanup (the only engine wired to
        // Timeline at v5), so the backfill is exact, not a guess.
        """
        ALTER TABLE timeline_snapshots ADD COLUMN scope TEXT NOT NULL DEFAULT '';
        UPDATE timeline_snapshots SET scope = 'cleanup' WHERE scope = '';
        CREATE INDEX IF NOT EXISTS idx_timeline_snapshots_scope ON timeline_snapshots(scope, date);
        """,
    ]

    /// Default on-disk location: ~/Library/Application Support/CoreTend/store.sqlite
    ///
    /// Honours ``TestStoreOverride`` first, so a distribution smoke test can
    /// launch the real Release binary against a throwaway directory instead of
    /// the user's data. The override demands two agreeing environment variables
    /// and a path under a real temporary root, so a normal launch — and any
    /// launch with only one variable set — always lands on the real path below.
    public static func defaultPath() throws -> String {
        let dir: URL
        if let override = TestStoreOverride.current.directory {
            dir = override
        } else {
            dir = try userDirectory()
        }
        // Directory creation is a side effect of *opening* the store, so it
        // lives here — not in userPath()/userDirectory(), which several tests
        // call only to assert a path string and must not touch the real
        // ~/Library location.
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite").path
    }

    /// The real per-user store path, never overridable. Kept separate so a test
    /// can assert what the override is measured against. Pure — creates nothing.
    public static func userPath() throws -> String {
        try userDirectory().appendingPathComponent("store.sqlite").path
    }

    /// `~/Library/Application Support/CoreTend`, without creating it.
    public static func userDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ).appendingPathComponent("CoreTend", isDirectory: true)
    }

    public init(path: String) throws {
        db = try Database(path: path)
        try Self.migrate(db)
    }

    private static func migrate(_ db: Database) throws {
        try db.exec("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied REAL NOT NULL
            )
            """)
        let rows = try db.query("SELECT COALESCE(MAX(version), 0) AS v FROM schema_migrations")
        let current = (rows.first?["v"] as? Int64).map(Int.init) ?? 0
        for (index, sql) in migrations.enumerated() where index + 1 > current {
            let version = index + 1
            do {
                try db.transaction {
                    try db.exec(sql)
                    try db.run("INSERT INTO schema_migrations (version, applied) VALUES (?, ?)",
                               [version, Date().timeIntervalSince1970])
                }
            } catch {
                throw DatabaseError.migrationFailed(version: version, message: "\(error)")
            }
        }
    }

    public func schemaVersion() throws -> Int {
        let rows = try db.query("SELECT COALESCE(MAX(version), 0) AS v FROM schema_migrations")
        return (rows.first?["v"] as? Int64).map(Int.init) ?? 0
    }

    // MARK: - Activity

    @discardableResult
    public func recordActivity(_ record: ActivityRecord) throws -> Int64 {
        try db.run("""
            INSERT INTO activity (kind, date, summary, item_count, bytes, dry_run)
            VALUES (?, ?, ?, ?, ?, ?)
            """, [record.kind.rawValue, record.date.timeIntervalSince1970, record.summary,
                  record.itemCount, record.bytes, 0])
        return db.lastInsertRowID
    }

    public func activity(limit: Int = 200, kind: ActivityRecord.Kind? = nil) throws -> [ActivityRecord] {
        let rows: [[String: Any]]
        if let kind {
            rows = try db.query(
                "SELECT * FROM activity WHERE kind = ? AND (kind <> 'cleanup' OR dry_run = 0) ORDER BY date DESC LIMIT ?",
                [kind.rawValue, limit])
        } else {
            rows = try db.query(
                "SELECT * FROM activity WHERE kind <> 'cleanup' OR dry_run = 0 ORDER BY date DESC LIMIT ?",
                [limit])
        }
        return rows.compactMap { row in
            guard let id = row["id"] as? Int64,
                  let kindRaw = row["kind"] as? String,
                  let kind = ActivityRecord.Kind(rawValue: kindRaw),
                  let date = row["date"] as? Double,
                  let summary = row["summary"] as? String else { return nil }
            return ActivityRecord(
                id: id, kind: kind, date: Date(timeIntervalSince1970: date), summary: summary,
                itemCount: (row["item_count"] as? Int64).map(Int.init) ?? 0,
                bytes: row["bytes"] as? Int64 ?? 0)
        }
    }

    public func clearActivity() throws {
        try db.run("DELETE FROM activity")
    }

    // MARK: - Exclusions

    public func addExclusion(path: String) throws {
        try db.run("INSERT OR IGNORE INTO exclusions (path, created) VALUES (?, ?)",
                   [path, Date().timeIntervalSince1970])
    }

    public func removeExclusion(path: String) throws {
        try db.run("DELETE FROM exclusions WHERE path = ?", [path])
    }

    public func exclusions() throws -> [String] {
        try db.query("SELECT path FROM exclusions ORDER BY path").compactMap { $0["path"] as? String }
    }

    // MARK: - Settings

    public func setSetting(_ key: String, value: String) throws {
        try db.run("INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                   [key, value])
    }

    public func setting(_ key: String) throws -> String? {
        try db.query("SELECT value FROM settings WHERE key = ?", [key]).first?["value"] as? String
    }

    // MARK: - Locations (favorites & recents)

    public func addFavorite(path: String) throws {
        try db.run("""
            INSERT INTO locations (path, is_favorite, created) VALUES (?, 1, ?)
            ON CONFLICT(path) DO UPDATE SET is_favorite = 1
            """, [path, Date().timeIntervalSince1970])
    }

    public func removeFavorite(path: String) throws {
        try db.run("UPDATE locations SET is_favorite = 0 WHERE path = ?", [path])
        try pruneLocationIfEmpty(path: path)
    }

    /// Called after a location finishes scanning (Space Lens, a custom-folder
    /// analysis, …) so Recents reflects real scan history rather than intent.
    public func recordLocationVisit(path: String, bytes: Int64) throws {
        let now = Date().timeIntervalSince1970
        try db.run("""
            INSERT INTO locations (path, is_favorite, last_scanned, last_bytes, created)
            VALUES (?, 0, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET last_scanned = excluded.last_scanned, last_bytes = excluded.last_bytes
            """, [path, now, bytes, now])
    }

    public func removeRecent(path: String) throws {
        try db.run("UPDATE locations SET last_scanned = NULL, last_bytes = NULL WHERE path = ?", [path])
        try pruneLocationIfEmpty(path: path)
    }

    /// A location that is neither a favorite nor has scan history carries no
    /// information; keeping it around would just be a leaked row.
    private func pruneLocationIfEmpty(path: String) throws {
        try db.run("DELETE FROM locations WHERE path = ? AND is_favorite = 0 AND last_scanned IS NULL", [path])
    }

    public func favorites() throws -> [LocationRecord] {
        try db.query("SELECT * FROM locations WHERE is_favorite = 1 ORDER BY path").compactMap(Self.locationRecord)
    }

    public func recents(limit: Int = 10) throws -> [LocationRecord] {
        try db.query(
            "SELECT * FROM locations WHERE last_scanned IS NOT NULL ORDER BY last_scanned DESC LIMIT ?",
            [limit]
        ).compactMap(Self.locationRecord)
    }

    private static func locationRecord(_ row: [String: Any]) -> LocationRecord? {
        guard let path = row["path"] as? String else { return nil }
        return LocationRecord(
            path: path,
            isFavorite: (row["is_favorite"] as? Int64 ?? 0) != 0,
            lastScanned: (row["last_scanned"] as? Double).map(Date.init(timeIntervalSince1970:)),
            lastBytes: row["last_bytes"] as? Int64)
    }

    // MARK: - Timeline (storage snapshots for "what changed since my last scan")
    //
    // A snapshot belongs to exactly one `scope` — the scan methodology that
    // produced it ("cleanup", "duplicates", "leftovers", "privacy", …).
    // Snapshots are only ever compared within the same scope: a Cleanup scan
    // covers a fixed set of system-cache rules, a Duplicates scan covers
    // wasted space from copies in a different fixed root set, neither is
    // "total storage", and summing or diffing across scopes would silently
    // misrepresent disk usage. Every comparison method below takes an
    // explicit `scope` (or derives one from a snapshot that already carries
    // it) rather than ever comparing "the two most recent snapshots"
    // regardless of what produced them.

    /// Records one scan's category-level footprint as a new snapshot, then
    /// prunes that scope's history per the retention policy
    /// (`pruneTimelineSnapshots`). Safe to call with an empty `samples` array
    /// — an empty scan is still a real data point (it can show a category
    /// shrank to zero). Only call this for a scan that actually completed —
    /// a cancelled or failed scan must not produce a snapshot, since a
    /// partial result would be a false data point for every future
    /// comparison against it.
    @discardableResult
    public func recordTimelineSnapshot(scope: String, trigger: String = "manual",
                                        samples: [TimelineCategorySample]) throws -> Int64 {
        try recordTimelineSnapshot(scope: scope, date: Date(), trigger: trigger, samples: samples)
    }

    /// Test seam: records a snapshot at an explicit `date` instead of `Date()`,
    /// so retention (`pruneTimelineSnapshots`, a 90-day window) can be
    /// exercised deterministically without waiting 90 real days. `internal`,
    /// not `public` — reachable only via `@testable import Persistence`; the
    /// real app always goes through the `Date()`-only overload above.
    @discardableResult
    func recordTimelineSnapshot(scope: String, date: Date, trigger: String = "manual",
                                 samples: [TimelineCategorySample]) throws -> Int64 {
        let total = samples.reduce(Int64(0)) { $0 + $1.logicalBytes }
        var snapshotID: Int64 = 0
        try db.transaction {
            try db.run("INSERT INTO timeline_snapshots (date, trigger, total_bytes, scope) VALUES (?, ?, ?, ?)",
                       [date.timeIntervalSince1970, trigger, total, scope])
            snapshotID = db.lastInsertRowID
            for sample in samples {
                try db.run("""
                    INSERT INTO timeline_categories
                        (snapshot_id, category, engine, logical_bytes, physical_bytes, file_count, risk)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, [snapshotID, sample.category, sample.engine, sample.logicalBytes,
                          sample.physicalBytes, sample.fileCount, sample.risk])
            }
        }
        try pruneTimelineSnapshots(scope: scope)
        return snapshotID
    }

    /// Snapshots newest first. `scope` narrows to one scan methodology;
    /// `nil` returns the cross-scope history (for a "recent activity across
    /// every scan kind" list — never for building a comparison).
    public func timelineSnapshots(scope: String? = nil, limit: Int = 60) throws -> [TimelineSnapshotRecord] {
        if let scope {
            return try db.query("SELECT * FROM timeline_snapshots WHERE scope = ? ORDER BY date DESC LIMIT ?",
                                 [scope, limit]).compactMap(Self.timelineSnapshotRecord)
        }
        return try db.query("SELECT * FROM timeline_snapshots ORDER BY date DESC LIMIT ?", [limit])
            .compactMap(Self.timelineSnapshotRecord)
    }

    /// The most recent snapshot. `scope` narrows to one scan methodology;
    /// `nil` returns the single most recent snapshot regardless of scope
    /// (used only to discover "what scan last ran at all", never to build a
    /// comparison against a snapshot of a different scope).
    public func latestTimelineSnapshot(scope: String? = nil) throws -> TimelineSnapshotRecord? {
        try timelineSnapshots(scope: scope, limit: 1).first
    }

    /// The most recent `scope` snapshot at or before `date` — the baseline
    /// for "since X ago" comparisons.
    public func timelineSnapshot(scope: String, atOrBefore date: Date) throws -> TimelineSnapshotRecord? {
        try db.query("SELECT * FROM timeline_snapshots WHERE scope = ? AND date <= ? ORDER BY date DESC LIMIT 1",
                     [scope, date.timeIntervalSince1970]).compactMap(Self.timelineSnapshotRecord).first
    }

    /// The most recent `scope` snapshot strictly before `date` — used to find
    /// "the previous snapshot of this same scope" when the starting point is
    /// an arbitrary snapshot (e.g. the single most recent one across every
    /// scope), rather than "now".
    public func previousTimelineSnapshot(scope: String, before date: Date) throws -> TimelineSnapshotRecord? {
        try db.query("SELECT * FROM timeline_snapshots WHERE scope = ? AND date < ? ORDER BY date DESC LIMIT 1",
                     [scope, date.timeIntervalSince1970]).compactMap(Self.timelineSnapshotRecord).first
    }

    public func timelineCategories(snapshotID: Int64) throws -> [TimelineCategoryRecord] {
        try db.query("SELECT * FROM timeline_categories WHERE snapshot_id = ? ORDER BY logical_bytes DESC",
                     [snapshotID]).compactMap(Self.timelineCategoryRecord)
    }

    /// Compares the latest `scope` snapshot against the most recent `scope`
    /// snapshot at or before `referenceDate` (e.g. "24 hours ago", "7 days
    /// ago"). Returns nil when there is no current snapshot in this scope, or
    /// no snapshot of this scope old enough to serve as a baseline — never a
    /// comparison against a snapshot that doesn't exist, and never against a
    /// different scope's snapshot.
    public func timelineComparison(scope: String, since referenceDate: Date) throws -> TimelineComparison? {
        guard let current = try latestTimelineSnapshot(scope: scope) else { return nil }
        guard let baseline = try timelineSnapshot(scope: scope, atOrBefore: referenceDate), baseline.id != current.id
        else { return nil }
        return try buildTimelineComparison(current: current, baseline: baseline)
    }

    /// Compares the two most recent snapshots of one scope directly — "since
    /// my last Cleanup scan" — independent of any fixed time window. Returns
    /// nil with fewer than two recorded snapshots in this scope.
    public func timelineComparisonSincePreviousSnapshot(scope: String) throws -> TimelineComparison? {
        let recent = try timelineSnapshots(scope: scope, limit: 2)
        guard recent.count == 2 else { return nil }
        return try buildTimelineComparison(current: recent[0], baseline: recent[1])
    }

    /// "Since last scan" across every scope: finds the single most recent
    /// snapshot regardless of what produced it, then compares it against the
    /// previous snapshot **of that same scope** — never against whatever
    /// scope happens to be second-most-recent overall, which could be a
    /// different, non-comparable methodology. This is what a Dashboard-level
    /// "since last scan" card should call; a Timeline screen focused on one
    /// scope should call `timelineComparisonSincePreviousSnapshot(scope:)`
    /// directly instead. Returns nil when no scan has ever completed, or
    /// when the most recent scan's own scope has no earlier snapshot yet.
    public func latestTimelineComparisonAcrossScopes() throws -> TimelineComparison? {
        guard let current = try latestTimelineSnapshot() else { return nil }
        guard let baseline = try previousTimelineSnapshot(scope: current.scope, before: current.date) else { return nil }
        return try buildTimelineComparison(current: current, baseline: baseline)
    }

    private func buildTimelineComparison(current: TimelineSnapshotRecord,
                                          baseline: TimelineSnapshotRecord) throws -> TimelineComparison {
        let currentCategories = try timelineCategories(snapshotID: current.id)
        let baselineCategories = try timelineCategories(snapshotID: baseline.id)
        var byKey: [String: (engine: String, category: String, current: Int64, previous: Int64)] = [:]
        for c in currentCategories {
            byKey[c.engine + "." + c.category] = (c.engine, c.category, c.logicalBytes, 0)
        }
        for b in baselineCategories {
            let key = b.engine + "." + b.category
            if var existing = byKey[key] {
                existing.previous = b.logicalBytes
                byKey[key] = existing
            } else {
                byKey[key] = (b.engine, b.category, 0, b.logicalBytes)
            }
        }
        let deltas = byKey.values
            .map { TimelineCategoryDelta(category: $0.category, engine: $0.engine,
                                          currentBytes: $0.current, previousBytes: $0.previous) }
            .sorted { $0.deltaBytes > $1.deltaBytes }
        return TimelineComparison(current: current, baseline: baseline, categoryDeltas: deltas)
    }

    /// Explicit, user-initiated, all-or-nothing deletion of every scope's
    /// history — mirrors `purgeSafetyLog()`. There is deliberately no
    /// per-scope clear: this is a privacy action ("forget my local scan
    /// history"), not a per-feature reset.
    public func clearTimelineHistory() throws {
        try db.run("DELETE FROM timeline_categories")
        try db.run("DELETE FROM timeline_snapshots")
    }

    /// Retention, applied per scope so a rarely-used scan kind (e.g.
    /// Duplicates) can't be pruned away just because another scope (e.g.
    /// Cleanup) is scanned often: keep a scope's snapshots from the last 90
    /// days, but always keep at least its 5 most recent regardless of age, so
    /// a lightly-used install still has a baseline for "since last scan".
    private func pruneTimelineSnapshots(scope: String) throws {
        let cutoff = Date().addingTimeInterval(-90 * 24 * 3600).timeIntervalSince1970
        try db.transaction {
            try db.run("""
                DELETE FROM timeline_categories WHERE snapshot_id IN (
                    SELECT id FROM timeline_snapshots WHERE scope = ? AND date < ?
                    AND id NOT IN (SELECT id FROM timeline_snapshots WHERE scope = ? ORDER BY date DESC LIMIT 5)
                )
                """, [scope, cutoff, scope])
            try db.run("""
                DELETE FROM timeline_snapshots WHERE scope = ? AND date < ?
                AND id NOT IN (SELECT id FROM timeline_snapshots WHERE scope = ? ORDER BY date DESC LIMIT 5)
                """, [scope, cutoff, scope])
        }
    }

    private static func timelineSnapshotRecord(_ row: [String: Any]) -> TimelineSnapshotRecord? {
        guard let id = row["id"] as? Int64, let date = row["date"] as? Double,
              let trigger = row["trigger"] as? String, let scope = row["scope"] as? String else { return nil }
        return TimelineSnapshotRecord(id: id, date: Date(timeIntervalSince1970: date), trigger: trigger,
                                       scope: scope, totalBytes: row["total_bytes"] as? Int64 ?? 0)
    }

    private static func timelineCategoryRecord(_ row: [String: Any]) -> TimelineCategoryRecord? {
        guard let id = row["id"] as? Int64, let snapshotID = row["snapshot_id"] as? Int64,
              let category = row["category"] as? String, let engine = row["engine"] as? String,
              let risk = row["risk"] as? String else { return nil }
        return TimelineCategoryRecord(
            id: id, snapshotID: snapshotID, category: category, engine: engine,
            logicalBytes: row["logical_bytes"] as? Int64 ?? 0,
            physicalBytes: row["physical_bytes"] as? Int64,
            fileCount: (row["file_count"] as? Int64).map(Int.init) ?? 0,
            risk: risk)
    }

    // MARK: - Safety log (append-only)

    public func safetyLog(limit: Int = 500) throws -> [SafetyLogRecord] {
        // Rows written by the retired preview mode remain in the database for
        // downgrade compatibility, but are intentionally absent from the
        // current product surface.
        try db.query("SELECT * FROM safety_log WHERE stage <> 'dryRun' ORDER BY date DESC LIMIT ?", [limit])
            .compactMap { row in
                guard let id = row["id"] as? Int64,
                      let operationID = row["operation_id"] as? String,
                      let stageRaw = row["stage"] as? String,
                      let stage = SafetyAuditEvent.Stage(rawValue: stageRaw),
                      let path = row["redacted_path"] as? String,
                      let ruleID = row["rule_id"] as? String,
                      let risk = row["risk"] as? String,
                      let date = row["date"] as? Double,
                      let result = row["result"] as? String else { return nil }
                return SafetyLogRecord(
                    id: id, operationID: operationID, stage: stage, redactedPath: path,
                    ruleID: ruleID, risk: risk, size: row["size"] as? Int64 ?? 0,
                    date: Date(timeIntervalSince1970: date), result: result)
            }
    }

    /// Explicit, user-initiated, all-or-nothing deletion. The only way rows
    /// ever leave safety_log — normal operation never mutates or deletes rows.
    public func purgeSafetyLog() throws {
        try db.run("DELETE FROM safety_log")
    }
}

/// One durable, redacted-path row of the SafetyCore audit trail.
public struct SafetyLogRecord: Sendable, Identifiable {
    public let id: Int64
    public let operationID: String
    public let stage: SafetyAuditEvent.Stage
    public let redactedPath: String
    public let ruleID: String
    public let risk: String
    public let size: Int64
    public let date: Date
    public let result: String
}

extension Store: SafetyAuditSink {
    /// Redacts a filesystem path to a shape that carries no personal
    /// information ("<home>/…/name" or "/Users/<redacted>/…") before it
    /// ever reaches disk. Mirrors CoreTendApp's DiagnosticReport.redactPath —
    /// this is the canonical copy; safety_log never stores a raw path.
    public static func redactPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        var p = path
        if p.hasPrefix(home) { p = "<home>" + p.dropFirst(home.count) }
        if p.hasPrefix("/Users/") {
            let comps = p.split(separator: "/", omittingEmptySubsequences: true)
            if comps.count >= 2 { p = "/Users/<redacted>/" + comps.dropFirst(2).joined(separator: "/") }
        }
        return p
    }

    public func recordSafetyEvent(_ event: SafetyAuditEvent) async {
        let redacted = Store.redactPath(event.path)
        try? db.run("""
            INSERT INTO safety_log (operation_id, stage, redacted_path, rule_id, risk, size, date, result)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, [event.operationID.uuidString, event.stage.rawValue, redacted, event.ruleID,
                  event.risk.rawValue, event.size, event.date.timeIntervalSince1970, event.result])
    }
}
