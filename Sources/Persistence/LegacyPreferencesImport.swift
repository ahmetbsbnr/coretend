import Foundation
import Darwin
import CryptoKit
import CSQLite

public enum LegacyImportError: Error, Equatable, Sendable { case unavailableSource, sourceChanged, invalidFormat, unsupportedVersion, unsafePath, tooManyPaths }

public struct LegacyPreferencesPreview: Sendable, Equatable {
    public let excludedPaths: [String]
    public let language: String?
    public let sourceDigest: String
}

public enum LegacyImportOutcome: Sendable, Equatable { case imported, alreadyImported }

/// Imports an explicitly selected JSON v1 or standalone SQLite 1.x copy; source remains untouched.
public struct LegacyPreferencesImporter: Sendable {
    public init() {}

    public func preview(sourceURL: URL) throws -> LegacyPreferencesPreview {
        if sourceURL.pathExtension.lowercased() == "sqlite" {
            // A live WAL/hot-journal database is not a standalone backup. Do not discover,
            // open or checkpoint sidecars; require the user to provide a consistent copy.
            guard !FileManager.default.fileExists(atPath: sourceURL.path + "-wal"),
                  !FileManager.default.fileExists(atPath: sourceURL.path + "-journal") else {
                throw LegacyImportError.invalidFormat
            }
            return try previewSQLite(readSelectedRegularFile(sourceURL, maximumSize: 64 * 1_024 * 1_024))
        }
        guard sourceURL.lastPathComponent == "coretend-preferences-v1.json" else { throw LegacyImportError.invalidFormat }
        let data = try readSelectedRegularFile(sourceURL)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: Set(["version", "excludedPaths", "language"])),
              let version = object["version"] as? Int else { throw LegacyImportError.invalidFormat }
        guard version == 1 else { throw LegacyImportError.unsupportedVersion }
        if let paths = object["excludedPaths"], !(paths is [String]) { throw LegacyImportError.invalidFormat }
        if let language = object["language"], !(language is String) { throw LegacyImportError.invalidFormat }
        let rawPaths = object["excludedPaths"] as? [String] ?? []
        guard rawPaths.count <= 1_000 else { throw LegacyImportError.tooManyPaths }
        let paths = try rawPaths.map(validatePath)
        let language = object["language"] as? String
        if let language, !["system", "fr", "en"].contains(language) { throw LegacyImportError.invalidFormat }
        return LegacyPreferencesPreview(excludedPaths: Array(Set(paths)).sorted(), language: language,
                                        sourceDigest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }

    public func importCopy(_ preview: LegacyPreferencesPreview, into store: SQLiteStore) async throws -> LegacyImportOutcome {
        try await store.recordLegacyImport(digest: preview.sourceDigest, paths: preview.excludedPaths, language: preview.language)
            ? .imported : .alreadyImported
    }

    private func validatePath(_ path: String) throws -> String {
        let components = path.split(separator: "/")
        guard !path.utf8.contains(0), path.hasPrefix("/"), !components.contains("."), !components.contains(".."),
              URL(fileURLWithPath: path).standardizedFileURL.path == path else { throw LegacyImportError.unsafePath }
        return path
    }

    private func readSelectedRegularFile(_ url: URL, maximumSize: Int = 1_000_000) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else { throw LegacyImportError.unavailableSource }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { throw LegacyImportError.unavailableSource }
        guard info.st_size > 0, info.st_size <= maximumSize else { throw LegacyImportError.invalidFormat }
        var bytes = [UInt8](repeating: 0, count: Int(info.st_size))
        var offset = 0
        while offset < bytes.count {
            let amount = read(descriptor, &bytes[offset], bytes.count - offset)
            guard amount > 0 else { throw LegacyImportError.unavailableSource }
            offset += amount
        }
        var finalInfo = stat()
        guard fstat(descriptor, &finalInfo) == 0,
              finalInfo.st_dev == info.st_dev, finalInfo.st_ino == info.st_ino,
              finalInfo.st_mode == info.st_mode, finalInfo.st_size == info.st_size,
              finalInfo.st_mtimespec.tv_sec == info.st_mtimespec.tv_sec,
              finalInfo.st_mtimespec.tv_nsec == info.st_mtimespec.tv_nsec,
              finalInfo.st_ctimespec.tv_sec == info.st_ctimespec.tv_sec,
              finalInfo.st_ctimespec.tv_nsec == info.st_ctimespec.tv_nsec else {
            throw LegacyImportError.sourceChanged
        }
        return Data(bytes)
    }
}

private extension LegacyPreferencesImporter {
    /// Reads a private immutable snapshot, never opens the selected legacy file with SQLite.
    /// Only the shipped 1.x exclusions table is allowlisted; other tables are not imported.
    func previewSQLite(_ data: Data) throws -> LegacyPreferencesPreview {
        guard data.starts(with: Data("SQLite format 3\0".utf8)) else { throw LegacyImportError.invalidFormat }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-legacy-snapshot-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshot = root.appendingPathComponent("source.sqlite")
        try data.write(to: snapshot, options: .withoutOverwriting)
        var connection: OpaquePointer?
        let uri = snapshot.absoluteString + "?immutable=1"
        let status = sqlite3_open_v2(uri, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil)
        guard status == SQLITE_OK, let connection else {
            if let connection { sqlite3_close(connection) }
            throw LegacyImportError.invalidFormat
        }
        defer { sqlite3_close(connection) }
        guard sqlite3_exec(connection, "PRAGMA trusted_schema = OFF", nil, nil, nil) == SQLITE_OK else {
            throw LegacyImportError.invalidFormat
        }
        func rows(_ sql: String, integer: Bool = false) throws -> [[String]] {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
                throw LegacyImportError.invalidFormat
            }
            defer { sqlite3_finalize(statement) }
            var result: [[String]] = []
            while true {
                let step = sqlite3_step(statement)
                if step == SQLITE_DONE { return result }
                guard step == SQLITE_ROW, result.count < 1_001 else { throw LegacyImportError.invalidFormat }
                var row: [String] = []
                for index in 0..<sqlite3_column_count(statement) {
                    guard sqlite3_column_type(statement, index) == (integer ? SQLITE_INTEGER : SQLITE_TEXT),
                          let text = sqlite3_column_text(statement, index),
                          let value = String(data: Data(bytes: text, count: Int(sqlite3_column_bytes(statement, index))), encoding: .utf8) else {
                        throw LegacyImportError.invalidFormat
                    }
                    row.append(value)
                }
                result.append(row)
            }
        }
        guard try rows("PRAGMA quick_check") == [["ok"]] else { throw LegacyImportError.invalidFormat }
        let tables = try rows("SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name IN ('schema_migrations', 'exclusions', 'settings') ORDER BY name")
        guard tables.map({ $0[0] }) == ["exclusions", "schema_migrations", "settings"],
              tables.allSatisfy({ $0[1].uppercased().hasPrefix("CREATE TABLE") }) else {
            throw LegacyImportError.invalidFormat
        }
        let history = try rows("SELECT version FROM schema_migrations ORDER BY version", integer: true)
        let versions = history.compactMap { Int($0[0]) }
        guard let version = versions.last, (1...4).contains(version) else { throw LegacyImportError.unsupportedVersion }
        guard versions == Array(1...version) else { throw LegacyImportError.invalidFormat }
        // These required columns are the published Store.swift contract, not inferred from data.
        _ = try rows("SELECT key, value FROM settings WHERE 0")
        _ = try rows("SELECT id, path, created FROM exclusions WHERE 0")
        let selected = try rows("SELECT path FROM exclusions ORDER BY path LIMIT 1001")
        guard selected.count <= 1_000 else { throw LegacyImportError.tooManyPaths }
        let paths = try selected.map { try validatePath($0[0]) }
        return LegacyPreferencesPreview(excludedPaths: Array(Set(paths)).sorted(), language: nil,
                                        sourceDigest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }
}
