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

public enum StoreError: Error, Equatable { case open(String), statement(String), unsupportedSchema(Int), readOnly }

private final class SQLiteConnection: @unchecked Sendable {
    let handle: OpaquePointer
    init(_ handle: OpaquePointer) { self.handle = handle }
    deinit { sqlite3_close_v2(handle) }
}

public actor SQLiteStore {
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
        guard version <= 2 else { throw StoreError.unsupportedSchema(version) }
        guard version < 2 else { return }
        guard !readOnly else { throw StoreError.readOnly }
        try execute("BEGIN IMMEDIATE")
        do {
            if version == 0 {
                try execute("CREATE TABLE IF NOT EXISTS activity_events (id TEXT PRIMARY KEY NOT NULL, occurred_at REAL NOT NULL, kind TEXT NOT NULL, detail TEXT NOT NULL)")
                try execute("CREATE INDEX IF NOT EXISTS activity_events_time ON activity_events(occurred_at)")
                try execute("PRAGMA user_version = 1")
            }
            try execute("CREATE TABLE IF NOT EXISTS preferences (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS legacy_imports (digest TEXT PRIMARY KEY NOT NULL, imported_at REAL NOT NULL)")
            try execute("PRAGMA user_version = 2")
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
