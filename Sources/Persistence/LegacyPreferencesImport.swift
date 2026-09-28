import Foundation
import Darwin
import CryptoKit

public enum LegacyImportError: Error, Equatable, Sendable { case unavailableSource, sourceChanged, invalidFormat, unsupportedVersion, unsafePath, tooManyPaths }

public struct LegacyPreferencesPreview: Sendable, Equatable {
    public let excludedPaths: [String]
    public let language: String?
    public let sourceDigest: String
}

public enum LegacyImportOutcome: Sendable, Equatable { case imported, alreadyImported }

/// Imports only explicitly selected `coretend-preferences-v1.json`; source remains untouched.
public struct LegacyPreferencesImporter: Sendable {
    public init() {}

    public func preview(sourceURL: URL) throws -> LegacyPreferencesPreview {
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
        guard path.hasPrefix("/"), !components.contains("."), !components.contains(".."),
              URL(fileURLWithPath: path).standardizedFileURL.path == path else { throw LegacyImportError.unsafePath }
        return path
    }

    private func readSelectedRegularFile(_ url: URL) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else { throw LegacyImportError.unavailableSource }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { throw LegacyImportError.unavailableSource }
        guard info.st_size > 0, info.st_size <= 1_000_000 else { throw LegacyImportError.invalidFormat }
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
