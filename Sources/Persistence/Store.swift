import Foundation
import SafetyCore

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
    public let dryRun: Bool

    public init(id: Int64 = 0, kind: Kind, date: Date = Date(), summary: String,
                itemCount: Int, bytes: Int64, dryRun: Bool) {
        self.id = id
        self.kind = kind
        self.date = date
        self.summary = summary
        self.itemCount = itemCount
        self.bytes = bytes
        self.dryRun = dryRun
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
    ]

    /// Default on-disk location: ~/Library/Application Support/CoreTend/store.sqlite
    ///
    /// Honours ``TestStoreOverride`` first, so a distribution smoke test can
    /// launch the real Release binary against a throwaway directory instead of
    /// the user's data. The override demands two agreeing environment variables
    /// and a path under a real temporary root, so a normal launch — and any
    /// launch with only one variable set — always lands on the real path below.
    public static func defaultPath() throws -> String {
        if let override = TestStoreOverride.current.directory {
            try FileManager.default.createDirectory(at: override, withIntermediateDirectories: true)
            return override.appendingPathComponent("store.sqlite").path
        }
        return try userPath()
    }

    /// The real per-user location, never overridable. Kept separate so a test can
    /// assert what the override is being measured against.
    public static func userPath() throws -> String {
        let dir = try userDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite").path
    }

    /// `~/Library/Application Support/CoreTend`, without creating it.
    public static func userDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
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
                  record.itemCount, record.bytes, record.dryRun ? 1 : 0])
        return db.lastInsertRowID
    }

    public func activity(limit: Int = 200, kind: ActivityRecord.Kind? = nil) throws -> [ActivityRecord] {
        let rows: [[String: Any]]
        if let kind {
            rows = try db.query(
                "SELECT * FROM activity WHERE kind = ? ORDER BY date DESC LIMIT ?",
                [kind.rawValue, limit])
        } else {
            rows = try db.query("SELECT * FROM activity ORDER BY date DESC LIMIT ?", [limit])
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
                bytes: row["bytes"] as? Int64 ?? 0,
                dryRun: (row["dry_run"] as? Int64 ?? 1) != 0)
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

    // MARK: - Safety log (append-only)

    public func safetyLog(limit: Int = 500) throws -> [SafetyLogRecord] {
        try db.query("SELECT * FROM safety_log ORDER BY date DESC LIMIT ?", [limit])
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

/// One durable, redacted-path row of the SafetyCore audit trail. `stage`
/// distinguishes a dry-run simulation from a real executed action — callers
/// (e.g. My Activity) must never merge the two into a single count.
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
