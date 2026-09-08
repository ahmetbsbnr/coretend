// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// DeepScanIndex — a persistent, incrementally-updatable index of the disk
// graph, backed by SQLite. It lets a later scan diff against the previous
// observation instead of re-walking everything, and lets the UI page through a
// million nodes without holding them all in RAM.
//
// This is a self-contained wrapper (Persistence.Database is internal to its
// module). It is read/append only from the scanner's point of view — it never
// touches the real filesystem.

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum DeepScanIndexError: Error, Sendable {
    case open(String)
    case exec(String)
    case prepare(String)
}

/// Not internally synchronised — wrap in an actor or serial queue if shared.
public final class DeepScanIndex {
    private var db: OpaquePointer?

    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle,
                              SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw DeepScanIndexError.open(msg)
        }
        db = handle
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA synchronous=NORMAL")
        try migrate()
    }

    deinit { sqlite3_close(db) }

    // MARK: schema (versioned for incremental evolution)

    private func migrate() throws {
        try exec("""
        CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL);
        """)
        let current = (try query("SELECT version FROM schema_version LIMIT 1").first?["version"] as? Int64) ?? 0
        if current < 1 {
            try exec("""
            CREATE TABLE node (
                canonical_path   TEXT PRIMARY KEY,
                parent_path      TEXT,
                type             TEXT NOT NULL,
                device           INTEGER,
                inode            INTEGER,
                logical_bytes    INTEGER NOT NULL,
                allocated_bytes  INTEGER NOT NULL,
                modified_at      REAL,
                completeness     TEXT NOT NULL,
                observed_at      REAL NOT NULL,
                content_hint     TEXT          -- (mtime,size) fingerprint for cheap diffing
            );
            CREATE INDEX IF NOT EXISTS idx_node_parent ON node(parent_path);
            CREATE INDEX IF NOT EXISTS idx_node_size ON node(allocated_bytes DESC);
            CREATE TABLE scan_run (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                started_at   REAL NOT NULL,
                finished_at  REAL NOT NULL,
                roots        TEXT NOT NULL,
                cancelled    INTEGER NOT NULL,
                timed_out    INTEGER NOT NULL,
                node_count   INTEGER NOT NULL
            );
            DELETE FROM schema_version;
            INSERT INTO schema_version(version) VALUES (1);
            """)
        }
        // v2: index-health metadata (idempotent).
        try exec("CREATE TABLE IF NOT EXISTS index_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);")
    }

    // MARK: incremental upsert

    /// Applies a freshly scanned graph. Existing rows whose (mtime,size)
    /// fingerprint is unchanged are left untouched; changed rows are updated;
    /// rows under a scanned, fully-complete root that are absent from the new
    /// graph are deleted (they no longer exist on disk).
    public func apply(_ graph: DiskGraph) throws {
        try exec("BEGIN IMMEDIATE")
        do {
            let stmt = try prepare("""
            INSERT INTO node(canonical_path, parent_path, type, device, inode,
                             logical_bytes, allocated_bytes, modified_at,
                             completeness, observed_at, content_hint)
            VALUES (?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(canonical_path) DO UPDATE SET
                parent_path=excluded.parent_path, type=excluded.type,
                device=excluded.device, inode=excluded.inode,
                logical_bytes=excluded.logical_bytes,
                allocated_bytes=excluded.allocated_bytes,
                modified_at=excluded.modified_at,
                completeness=excluded.completeness,
                observed_at=excluded.observed_at,
                content_hint=excluded.content_hint
            WHERE node.content_hint IS NOT excluded.content_hint;
            """)
            defer { sqlite3_finalize(stmt) }
            for n in graph.nodes {
                let hint = "\(Int(n.modifiedAt?.timeIntervalSince1970 ?? 0)):\(n.logicalBytes)"
                sqlite3_reset(stmt)
                bindText(stmt, 1, n.canonicalPath)
                bindText(stmt, 2, n.parentCanonicalPath)
                bindText(stmt, 3, n.type.rawValue)
                bindInt(stmt, 4, n.identity.map { Int64(bitPattern: $0.device) })
                bindInt(stmt, 5, n.identity.map { Int64(bitPattern: $0.inode) })
                bindInt(stmt, 6, n.logicalBytes)
                bindInt(stmt, 7, n.allocatedBytes)
                if let m = n.modifiedAt { sqlite3_bind_double(stmt, 8, m.timeIntervalSince1970) }
                else { sqlite3_bind_null(stmt, 8) }
                bindText(stmt, 9, n.completeness.rawValue)
                sqlite3_bind_double(stmt, 10, n.observedAt.timeIntervalSince1970)
                bindText(stmt, 11, hint)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DeepScanIndexError.exec(String(cString: sqlite3_errmsg(db)))
                }
            }

            let runStmt = try prepare("""
            INSERT INTO scan_run(started_at, finished_at, roots, cancelled, timed_out, node_count)
            VALUES (?,?,?,?,?,?);
            """)
            defer { sqlite3_finalize(runStmt) }
            sqlite3_bind_double(runStmt, 1, graph.startedAt.timeIntervalSince1970)
            sqlite3_bind_double(runStmt, 2, graph.finishedAt.timeIntervalSince1970)
            bindText(runStmt, 3, graph.scannedRoots.joined(separator: ":"))
            sqlite3_bind_int(runStmt, 4, graph.wasCancelled ? 1 : 0)
            sqlite3_bind_int(runStmt, 5, graph.hitTimeout ? 1 : 0)
            sqlite3_bind_int64(runStmt, 6, Int64(graph.nodes.count))
            guard sqlite3_step(runStmt) == SQLITE_DONE else {
                throw DeepScanIndexError.exec(String(cString: sqlite3_errmsg(db)))
            }
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    public func nodeCount() throws -> Int {
        Int((try query("SELECT COUNT(*) AS c FROM node").first?["c"] as? Int64) ?? 0)
    }

    /// Delete exact rows (vanished paths reported by FSEvents).
    public func delete(paths: [String]) throws {
        guard !paths.isEmpty else { return }
        try exec("BEGIN IMMEDIATE")
        do {
            let stmt = try prepare("DELETE FROM node WHERE canonical_path = ? OR canonical_path LIKE ? ESCAPE '\\'")
            defer { sqlite3_finalize(stmt) }
            for p in paths {
                sqlite3_reset(stmt)
                bindText(stmt, 1, p)
                bindText(stmt, 2, likePrefix(p) + "/%")
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DeepScanIndexError.exec(String(cString: sqlite3_errmsg(db)))
                }
            }
            try exec("COMMIT")
        } catch { try? exec("ROLLBACK"); throw error }
    }

    /// After a scoped rescan of `root`, remove rows under `root` that the fresh
    /// scan did not observe (they were deleted between scans). `keeping` is the
    /// set of canonical paths present in the new partial graph.
    public func pruneUnder(root: String, keeping: Set<String>) throws {
        let rows = try query(
            "SELECT canonical_path FROM node WHERE canonical_path = ? OR canonical_path LIKE ? ESCAPE '\\'",
            [root, likePrefix(root) + "/%"])
        let stale = rows.compactMap { $0["canonical_path"] as? String }.filter { !keeping.contains($0) }
        try delete(paths: stale)
    }

    private func likePrefix(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "%", with: "\\%")
         .replacingOccurrences(of: "_", with: "\\_")
    }

    // Index-health persistence (single row).
    public func storedHealth() throws -> String? {
        try query("SELECT value FROM index_meta WHERE key = 'health'").first?["value"] as? String
    }
    public func setStoredHealth(_ health: String) throws {
        try exec("INSERT INTO index_meta(key,value) VALUES('health','\(health)') "
                 + "ON CONFLICT(key) DO UPDATE SET value=excluded.value")
    }

    /// Largest N nodes by allocated size — the UI's default sort, paged.
    public func largestNodes(limit: Int, offset: Int = 0) throws -> [(path: String, allocated: Int64)] {
        try query("SELECT canonical_path, allocated_bytes FROM node ORDER BY allocated_bytes DESC LIMIT ? OFFSET ?",
                  [Int64(limit), Int64(offset)])
            .compactMap { row in
                guard let p = row["canonical_path"] as? String,
                      let a = row["allocated_bytes"] as? Int64 else { return nil }
                return (p, a)
            }
    }

    // MARK: tiny helpers

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw DeepScanIndexError.exec(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DeepScanIndexError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        return stmt
    }

    private func query(_ sql: String, _ bindings: [Any?] = []) throws -> [[String: Any]] {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, v) in bindings.enumerated() {
            let pos = Int32(i + 1)
            switch v {
            case let x as Int64: sqlite3_bind_int64(stmt, pos, x)
            case let x as String: sqlite3_bind_text(stmt, pos, x, -1, SQLITE_TRANSIENT)
            case nil: sqlite3_bind_null(stmt, pos)
            default: break
            }
        }
        var rows: [[String: Any]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<sqlite3_column_count(stmt) {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER: row[name] = sqlite3_column_int64(stmt, i)
                case SQLITE_FLOAT: row[name] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT: row[name] = String(cString: sqlite3_column_text(stmt, i))
                default: break
                }
            }
            rows.append(row)
        }
        return rows
    }

    private func bindText(_ stmt: OpaquePointer, _ pos: Int32, _ value: String?) {
        if let value { sqlite3_bind_text(stmt, pos, value, -1, SQLITE_TRANSIENT) }
        else { sqlite3_bind_null(stmt, pos) }
    }
    private func bindInt(_ stmt: OpaquePointer, _ pos: Int32, _ value: Int64?) {
        if let value { sqlite3_bind_int64(stmt, pos, value) }
        else { sqlite3_bind_null(stmt, pos) }
    }
}
