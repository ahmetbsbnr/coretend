import Foundation

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
    ]

    /// Default on-disk location: ~/Library/Application Support/MacCareLocal/store.sqlite
    public static func defaultPath() throws -> String {
        let dir = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("MacCareLocal", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite").path
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
}
