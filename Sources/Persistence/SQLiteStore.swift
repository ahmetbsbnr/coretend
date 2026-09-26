import Foundation
import CSQLite

public enum ActivityKind: String, Codable, CaseIterable, Sendable { case proposed, approved, refused, cancelled, movedToTrash, failed, migrationImported }

public struct ActivityEvent: Codable, Equatable, Sendable {
    public let id: UUID
    public let occurredAt: Date
    public let kind: ActivityKind
    public let detail: String
    public init(id: UUID, occurredAt: Date, kind: ActivityKind, detail: String) {
        self.id = id; self.occurredAt = occurredAt; self.kind = kind; self.detail = detail
    }
}

public struct SavedFileRecord: Equatable, Sendable {
    public let path: String
    public let firstSeenAt: Date
    public let lastSeenAt: Date
    public let logicalBytes: Int64?
    public let allocatedBytes: Int64?
    public let isFavorite: Bool
}

public struct RecentFileMeasurement: Equatable, Sendable {
    public let path: String
    public let logicalBytes: Int64?
    public let allocatedBytes: Int64?
    public let seenAt: Date

    public init(path: String, logicalBytes: Int64?, allocatedBytes: Int64?, seenAt: Date = .now) {
        self.path = path; self.logicalBytes = logicalBytes; self.allocatedBytes = allocatedBytes; self.seenAt = seenAt
    }
}

public enum StoreError: Error, Equatable { case open(String), statement(String), unsupportedSchema(Int), readOnly }

private final class SQLiteConnection: @unchecked Sendable {
    let handle: OpaquePointer
    init(_ handle: OpaquePointer) { self.handle = handle }
    deinit { sqlite3_close_v2(handle) }
}

public actor SQLiteStore {
    public static let maximumRecentFiles = 100
    private var connection: SQLiteConnection?
    private let readOnly: Bool
    public let url: URL

    public init(url: URL, readOnly: Bool = false) throws {
        self.url = url
        self.readOnly = readOnly
        var handle: OpaquePointer?
        let flags = (readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE) | SQLITE_OPEN_FULLMUTEX
        let result = url.path.withCString { sqlite3_open_v2($0, &handle, flags, nil) }
        guard result == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite open failed"
            if let handle { sqlite3_close(handle) }
            throw StoreError.open(message)
        }
        connection = SQLiteConnection(handle)
        sqlite3_busy_timeout(handle, 3000)
    }

    public func migrate() throws {
        let version = try schemaVersion()
        guard version <= 4 else { throw StoreError.unsupportedSchema(version) }
        guard version < 4 else { return }
        guard !readOnly else { throw StoreError.readOnly }
        try execute("BEGIN IMMEDIATE")
        do {
            if version == 0 {
                try execute("CREATE TABLE IF NOT EXISTS activity_events (id TEXT PRIMARY KEY NOT NULL, occurred_at REAL NOT NULL, kind TEXT NOT NULL, detail TEXT NOT NULL)")
                try execute("CREATE INDEX IF NOT EXISTS activity_events_time ON activity_events(occurred_at)")
                try execute("PRAGMA user_version = 1")
            }
            if version < 2 {
                try execute("CREATE TABLE IF NOT EXISTS preferences (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)")
                try execute("CREATE TABLE IF NOT EXISTS legacy_imports (digest TEXT PRIMARY KEY NOT NULL, imported_at REAL NOT NULL)")
            }
            if version < 3 {
                try execute("CREATE TABLE performance_samples (id TEXT PRIMARY KEY NOT NULL, measured_at REAL NOT NULL, load_average_1m REAL, available_bytes INTEGER)")
                try execute("CREATE INDEX performance_samples_time ON performance_samples(measured_at)")
            }
            try execute("CREATE TABLE saved_files (path TEXT PRIMARY KEY NOT NULL, first_seen_at REAL NOT NULL, last_seen_at REAL NOT NULL, logical_bytes INTEGER, allocated_bytes INTEGER, is_favorite INTEGER NOT NULL DEFAULT 0 CHECK(is_favorite IN (0, 1)))")
            try execute("CREATE INDEX saved_files_recency ON saved_files(last_seen_at DESC)")
            try execute("PRAGMA user_version = 4")
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    public func schemaVersion() throws -> Int {
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw failure() }
        return Int(sqlite3_column_int(statement, 0))
    }

    public func append(_ event: ActivityEvent) throws {
        guard !readOnly else { throw StoreError.readOnly }
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        let sql = "INSERT INTO activity_events(id, occurred_at, kind, detail) VALUES(?, ?, ?, ?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        bind(event.id.uuidString, to: 1, in: statement)
        sqlite3_bind_double(statement, 2, event.occurredAt.timeIntervalSince1970)
        bind(event.kind.rawValue, to: 3, in: statement)
        bind(event.detail, to: 4, in: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }

    public func events() throws -> [ActivityEvent] {
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        var statement: OpaquePointer?
        let sql = "SELECT id, occurred_at, kind, detail FROM activity_events ORDER BY occurred_at ASC, id ASC"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        var result: [ActivityEvent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idText = sqlite3_column_text(statement, 0), let id = UUID(uuidString: String(cString: idText)),
                  let kindText = sqlite3_column_text(statement, 2), let kind = ActivityKind(rawValue: String(cString: kindText)) else { continue }
            let date = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
            let detailText = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
            result.append(ActivityEvent(id: id, occurredAt: date, kind: kind, detail: detailText))
        }
        return result
    }

    public func clearHistory() throws {
        guard !readOnly else { throw StoreError.readOnly }
        try execute("DELETE FROM activity_events")
    }

    public func clearPerformanceHistory() throws {
        guard !readOnly else { throw StoreError.readOnly }
        try execute("DELETE FROM performance_samples")
    }

    public func recordRecentFile(path: String, logicalBytes: Int64?, allocatedBytes: Int64?, seenAt: Date = .now) throws {
        try recordRecentFiles([RecentFileMeasurement(path: path, logicalBytes: logicalBytes,
                                                      allocatedBytes: allocatedBytes, seenAt: seenAt)])
    }

    public func recordRecentFiles(_ files: [RecentFileMeasurement]) throws {
        guard !readOnly else { throw StoreError.readOnly }
        for file in files {
            try validateSavedFile(path: file.path, logicalBytes: file.logicalBytes, allocatedBytes: file.allocatedBytes)
        }
        guard !files.isEmpty else { return }
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        try execute("BEGIN IMMEDIATE")
        do {
            var statement: OpaquePointer?
            let sql = "INSERT INTO saved_files(path, first_seen_at, last_seen_at, logical_bytes, allocated_bytes, is_favorite) VALUES(?, ?, ?, ?, ?, 0) ON CONFLICT(path) DO UPDATE SET last_seen_at = excluded.last_seen_at, logical_bytes = excluded.logical_bytes, allocated_bytes = excluded.allocated_bytes"
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
            defer { sqlite3_finalize(statement) }
            for file in files {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                bind(file.path, to: 1, in: statement)
                sqlite3_bind_double(statement, 2, file.seenAt.timeIntervalSince1970)
                sqlite3_bind_double(statement, 3, file.seenAt.timeIntervalSince1970)
                if let logicalBytes = file.logicalBytes { sqlite3_bind_int64(statement, 4, logicalBytes) } else { sqlite3_bind_null(statement, 4) }
                if let allocatedBytes = file.allocatedBytes { sqlite3_bind_int64(statement, 5, allocatedBytes) } else { sqlite3_bind_null(statement, 5) }
                guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
            }
            try execute("DELETE FROM saved_files WHERE is_favorite = 0 AND path NOT IN (SELECT path FROM saved_files WHERE is_favorite = 0 ORDER BY last_seen_at DESC, path ASC LIMIT \(Self.maximumRecentFiles))")
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    public func setFavorite(path: String, isFavorite: Bool, at date: Date = .now) throws {
        guard !readOnly else { throw StoreError.readOnly }
        try validateSavedFile(path: path, logicalBytes: nil, allocatedBytes: nil)
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        let sql = isFavorite
            ? "INSERT INTO saved_files(path, first_seen_at, last_seen_at, is_favorite) VALUES(?, ?, ?, 1) ON CONFLICT(path) DO UPDATE SET is_favorite = 1"
            : "UPDATE saved_files SET is_favorite = 0 WHERE path = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        bind(path, to: 1, in: statement)
        if isFavorite {
            sqlite3_bind_double(statement, 2, date.timeIntervalSince1970)
            sqlite3_bind_double(statement, 3, date.timeIntervalSince1970)
        }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
        if !isFavorite {
            try execute("DELETE FROM saved_files WHERE is_favorite = 0 AND path NOT IN (SELECT path FROM saved_files WHERE is_favorite = 0 ORDER BY last_seen_at DESC, path ASC LIMIT \(Self.maximumRecentFiles))")
        }
    }

    public func savedFiles() throws -> [SavedFileRecord] {
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        var statement: OpaquePointer?
        let sql = "SELECT path, first_seen_at, last_seen_at, logical_bytes, allocated_bytes, is_favorite FROM saved_files ORDER BY is_favorite DESC, last_seen_at DESC, path ASC"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        var result: [SavedFileRecord] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else { throw failure() }
            guard let pathText = sqlite3_column_text(statement, 0) else { continue }
            result.append(SavedFileRecord(path: String(cString: pathText),
                                          firstSeenAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
                                          lastSeenAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                                          logicalBytes: sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : sqlite3_column_int64(statement, 3),
                                          allocatedBytes: sqlite3_column_type(statement, 4) == SQLITE_NULL ? nil : sqlite3_column_int64(statement, 4),
                                          isFavorite: sqlite3_column_int(statement, 5) == 1))
        }
        return result
    }

    public func removeSavedFile(path: String) throws {
        guard !readOnly else { throw StoreError.readOnly }
        try validateSavedFile(path: path, logicalBytes: nil, allocatedBytes: nil)
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "DELETE FROM saved_files WHERE path = ?", -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        bind(path, to: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }

    private func validateSavedFile(path: String, logicalBytes: Int64?, allocatedBytes: Int64?) throws {
        guard path.hasPrefix("/"), URL(fileURLWithPath: path).standardizedFileURL.path == path else {
            throw StoreError.statement("invalid saved-file path")
        }
        guard logicalBytes.map({ $0 >= 0 }) ?? true, allocatedBytes.map({ $0 >= 0 }) ?? true else {
            throw StoreError.statement("invalid saved-file measurement")
        }
    }

    public func appendPerformanceSample(_ sample: PerformanceSample, retentionNow: Date = .now) throws {
        guard !readOnly, let database = connection?.handle else { throw StoreError.readOnly }
        guard sample.loadAverage1m.map({ $0.isFinite && $0 >= 0 }) ?? true,
              sample.availableBytes.map({ $0 >= 0 }) ?? true else { throw StoreError.statement("invalid performance measurement") }
        try execute("BEGIN IMMEDIATE")
        do {
            var statement: OpaquePointer?
            let sql = "INSERT INTO performance_samples(id, measured_at, load_average_1m, available_bytes) VALUES(?, ?, ?, ?)"
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
            bind(sample.id.uuidString, to: 1, in: statement)
            sqlite3_bind_double(statement, 2, sample.measuredAt.timeIntervalSince1970)
            if let value = sample.loadAverage1m { sqlite3_bind_double(statement, 3, value) } else { sqlite3_bind_null(statement, 3) }
            if let value = sample.availableBytes { sqlite3_bind_int64(statement, 4, value) } else { sqlite3_bind_null(statement, 4) }
            let insertion = sqlite3_step(statement)
            sqlite3_finalize(statement)
            guard insertion == SQLITE_DONE else { throw failure() }

            let cutoff = retentionNow.addingTimeInterval(-Double(PerformanceHistoryPolicy.retentionDays) * 86_400)
            var prune: OpaquePointer?
            guard sqlite3_prepare_v2(database, "DELETE FROM performance_samples WHERE measured_at < ?", -1, &prune, nil) == SQLITE_OK, let prune else { throw failure() }
            sqlite3_bind_double(prune, 1, cutoff.timeIntervalSince1970)
            let deletion = sqlite3_step(prune)
            sqlite3_finalize(prune)
            guard deletion == SQLITE_DONE else { throw failure() }
            try execute("DELETE FROM performance_samples WHERE id NOT IN (SELECT id FROM performance_samples ORDER BY measured_at DESC, id DESC LIMIT \(PerformanceHistoryPolicy.maximumSamples))")
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    public func performanceSamples(limit: Int = 100) throws -> [PerformanceSample] {
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        var statement: OpaquePointer?
        let sql = "SELECT id, measured_at, load_average_1m, available_bytes FROM performance_samples ORDER BY measured_at DESC, id DESC LIMIT ?"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(min(max(1, limit), PerformanceHistoryPolicy.maximumSamples)))
        var result: [PerformanceSample] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else { throw failure() }
            guard let idText = sqlite3_column_text(statement, 0), let id = UUID(uuidString: String(cString: idText)) else { continue }
            let load = sqlite3_column_type(statement, 2) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 2)
            let bytes = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : sqlite3_column_int64(statement, 3)
            result.append(.init(id: id, measuredAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
                                loadAverage1m: load, availableBytes: bytes))
        }
        return result.reversed()
    }

    public func exclusions() throws -> [String] {
        try preferenceValue(for: "excluded_paths").flatMap { try JSONDecoder().decode([String].self, from: Data($0.utf8)) } ?? []
    }

    public func saveExclusions(_ paths: [String]) throws {
        let normalized = Array(Set(paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })).sorted()
        let data = try JSONEncoder().encode(normalized)
        try setPreference(key: "excluded_paths", value: String(decoding: data, as: UTF8.self))
    }

    public func languagePreference() throws -> String? { try preferenceValue(for: "language") }
    public func saveLanguagePreference(_ language: String) throws {
        guard ["system", "fr", "en"].contains(language) else { throw StoreError.statement("unsupported language") }
        try setPreference(key: "language", value: language)
    }

    public func recordLegacyImport(digest: String, paths: [String], language: String?) throws -> Bool {
        guard !readOnly else { throw StoreError.readOnly }
        try execute("BEGIN IMMEDIATE")
        do {
            if try legacyImportExists(digest) { try execute("ROLLBACK"); return false }
            try saveExclusions(paths)
            if let language { try setPreference(key: "language", value: language) }
            try append(ActivityEvent(id: UUID(), occurredAt: .now, kind: .migrationImported, detail: "legacy_preferences_v1:\(digest)"))
            guard let database = connection?.handle else { throw StoreError.open("closed") }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "INSERT INTO legacy_imports(digest, imported_at) VALUES(?, ?)", -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
            bind(digest, to: 1, in: statement)
            sqlite3_bind_double(statement, 2, Date.now.timeIntervalSince1970)
            let insertion = sqlite3_step(statement)
            sqlite3_finalize(statement)
            guard insertion == SQLITE_DONE else { throw failure() }
            try execute("COMMIT")
            return true
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func preferenceValue(for key: String) throws -> String? {
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT value FROM preferences WHERE key = ?", -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        bind(key, to: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return sqlite3_column_text(statement, 0).map { String(cString: $0) }
    }

    private func setPreference(key: String, value: String) throws {
        guard !readOnly, let database = connection?.handle else { throw StoreError.readOnly }
        var statement: OpaquePointer?
        let sql = "INSERT INTO preferences(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        bind(key, to: 1, in: statement); bind(value, to: 2, in: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }

    private func legacyImportExists(_ digest: String) throws -> Bool {
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT 1 FROM legacy_imports WHERE digest = ?", -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        defer { sqlite3_finalize(statement) }
        bind(digest, to: 1, in: statement)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func execute(_ sql: String) throws {
        guard let database = connection?.handle else { throw StoreError.open("closed") }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            throw StoreError.statement(message)
        }
    }

    private func bind(_ value: String, to index: Int32, in statement: OpaquePointer) {
        _ = value.withCString { pointer in sqlite3_bind_text(statement, index, pointer, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    }

    private func failure() -> StoreError {
        .statement(connection.map { String(cString: sqlite3_errmsg($0.handle)) } ?? "SQLite connection closed")
    }
}

public enum ActivityExport {
    public static func json(_ events: [ActivityEvent]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(events)
    }

    public static func csv(_ events: [ActivityEvent]) -> String {
        let rows = ["id,occurred_at,kind,detail"] + events.map { event in
            [event.id.uuidString, ISO8601DateFormatter().string(from: event.occurredAt), event.kind.rawValue, event.detail]
                .map(csvCell).joined(separator: ",")
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private static func csvCell(_ input: String) -> String {
        let formulaSafe = input.first.map { "=+-@\t\r".contains($0) } == true ? "'" + input : input
        return "\"" + formulaSafe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

public struct DiagnosticSummary: Codable, Equatable, Sendable {
    public let product: String
    public let version: String
    public let schemaVersion: Int
    public let eventCounts: [String: Int]
    public let createdAt: Date
}

public enum DiagnosticExport {
    public static func json(schemaVersion: Int, events: [ActivityEvent], createdAt: Date = .now) throws -> Data {
        let counts = Dictionary(grouping: events, by: { $0.kind.rawValue }).mapValues(\.count)
        let summary = DiagnosticSummary(product: "CoreTend Reconstruction", version: "0.1.0-local",
                                        schemaVersion: schemaVersion, eventCounts: counts, createdAt: createdAt)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(summary)
    }
}

public enum StoreLocation {
    public static func databaseURL(applicationSupportDirectory: URL) -> URL {
        applicationSupportDirectory
            .appendingPathComponent("CoreTend-Reconstruction", isDirectory: true)
            .appendingPathComponent("records.sqlite", isDirectory: false)
    }
}
