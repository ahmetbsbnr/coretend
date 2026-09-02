// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SQLite3

/// Typed errors for the persistence layer.
public enum DatabaseError: Error, Sendable {
    case openFailed(String)
    case prepareFailed(String, sql: String)
    case stepFailed(String)
    case migrationFailed(version: Int, message: String)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Minimal SQLite wrapper owned exclusively by the `Store` actor.
/// Not thread-safe on its own; the actor provides isolation.
final class Database {
    private var handle: OpaquePointer?

    init(path: String) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            throw DatabaseError.openFailed(message)
        }
        handle = db
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA foreign_keys=ON")
    }

    deinit {
        sqlite3_close(handle)
    }

    func exec(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(handle)))
        }
    }

    /// Binds values positionally: Int64, Double, String, Data, or nil.
    func run(_ sql: String, _ bindings: [Any?] = []) throws {
        let statement = try prepare(sql, bindings)
        defer { sqlite3_finalize(statement) }
        let rc = sqlite3_step(statement)
        guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
            throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(handle)))
        }
    }

    /// Returns all rows; each row is a dictionary keyed by column name.
    func query(_ sql: String, _ bindings: [Any?] = []) throws -> [[String: Any]] {
        let statement = try prepare(sql, bindings)
        defer { sqlite3_finalize(statement) }
        var rows: [[String: Any]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, i))
                switch sqlite3_column_type(statement, i) {
                case SQLITE_INTEGER: row[name] = sqlite3_column_int64(statement, i)
                case SQLITE_FLOAT: row[name] = sqlite3_column_double(statement, i)
                case SQLITE_TEXT: row[name] = String(cString: sqlite3_column_text(statement, i))
                case SQLITE_BLOB:
                    if let bytes = sqlite3_column_blob(statement, i) {
                        row[name] = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, i)))
                    }
                default: break
                }
            }
            rows.append(row)
        }
        return rows
    }

    var lastInsertRowID: Int64 { sqlite3_last_insert_rowid(handle) }

    func transaction(_ body: () throws -> Void) throws {
        try exec("BEGIN IMMEDIATE")
        do {
            try body()
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    private func prepare(_ sql: String, _ bindings: [Any?]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(handle)), sql: sql)
        }
        for (index, value) in bindings.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case let v as Int64: sqlite3_bind_int64(statement, position, v)
            case let v as Int: sqlite3_bind_int64(statement, position, Int64(v))
            case let v as Double: sqlite3_bind_double(statement, position, v)
            case let v as String: sqlite3_bind_text(statement, position, v, -1, SQLITE_TRANSIENT)
            case let v as Data:
                _ = v.withUnsafeBytes {
                    sqlite3_bind_blob(statement, position, $0.baseAddress, Int32(v.count), SQLITE_TRANSIENT)
                }
            case nil: sqlite3_bind_null(statement, position)
            default:
                sqlite3_finalize(statement)
                throw DatabaseError.prepareFailed("unsupported binding type", sql: sql)
            }
        }
        return statement
    }
}
