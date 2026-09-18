// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import CryptoKit

/// Verifies a release artifact the user downloaded themselves, against the
/// checksum published in the release manifest.
///
/// This is the half of "update verification" the app can honestly do. CoreTend
/// deliberately never downloads or installs an update — see `UpdateChecker` —
/// so the artifact arrives through the user's browser, and until now the app
/// said "verify its checksum" and left them to run `shasum` in Terminal.
///
/// What this proves and what it does not:
///
/// - It proves the bytes on disk are **exactly** the bytes the manifest
///   describes. That catches a truncated download, a corrupted transfer, and a
///   file swapped after the fact by anything that could not also rewrite the
///   manifest served over HTTPS.
/// - It does **not** prove authorship. Whoever can replace the artifact *and*
///   the manifest can make both agree. Authorship is proved by the Developer ID
///   signature and Apple's notarization, which macOS checks on open, and by the
///   Minisign signature published beside the release. This check is the cheap,
///   local, offline layer underneath those — not a replacement for them.
///
/// The file is read in bounded chunks and never held in memory: a release DMG
/// is tens of megabytes today and there is no reason for this to scale with it.
enum DownloadVerification {

    enum Outcome: Equatable, Sendable {
        /// Hash and size both match the manifest.
        case verified(artifact: String)
        /// The file is intact but is a different artifact than the one checked
        /// against — distinguished because picking the ZIP while the DMG was
        /// selected is a user mistake, not a corrupted download.
        case mismatch(expected: String, actual: String)
        /// Size differs, so hashing the rest would only waste time.
        case wrongSize(expected: Int64, actual: Int64)
        case unreadable(String)

        var isVerified: Bool { if case .verified = self { return true }; return false }
    }

    /// Chunk size for streaming. 1 MiB: large enough that syscall overhead is
    /// irrelevant, small enough that peak memory does not track file size.
    static let chunkSize = 1 << 20

    /// Streams `url` and returns its lowercase hex SHA-256.
    ///
    /// `nonisolated` and free of app state so it can run off the main actor:
    /// hashing a 60 MB DMG on the main thread would freeze the window.
    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func fileSize(of url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize else {
            throw CocoaError(.fileReadUnknown)
        }
        return Int64(size)
    }

    /// Compares one downloaded file against one manifest artifact.
    ///
    /// Size is checked first and short-circuits: a size mismatch is already a
    /// definitive answer, and hashing gigabytes to restate it is pure waste.
    static func verify(fileAt url: URL, against artifact: ReleaseArtifact) -> Outcome {
        let size: Int64
        do {
            size = try fileSize(of: url)
        } catch {
            return .unreadable(url.lastPathComponent)
        }
        guard size == artifact.size else {
            return .wrongSize(expected: artifact.size, actual: size)
        }
        do {
            let digest = try sha256(of: url)
            return digest == artifact.sha256
                ? .verified(artifact: artifact.name)
                : .mismatch(expected: artifact.sha256, actual: digest)
        } catch {
            return .unreadable(url.lastPathComponent)
        }
    }

    /// Picks the manifest artifact whose name matches the chosen file, so a
    /// user who downloaded the ZIP is checked against the ZIP.
    ///
    /// Falls back to matching on extension, then to the only artifact present.
    /// Returns nil when the release publishes nothing that could correspond —
    /// better than silently comparing against the wrong one and reporting a
    /// mismatch the user cannot explain.
    static func artifact(for url: URL, in release: ReleaseInfo) -> ReleaseArtifact? {
        let candidates = [release.dmg, release.zip].compactMap { $0 }
        let name = url.lastPathComponent
        if let exact = candidates.first(where: { $0.name == name }) { return exact }
        let ext = url.pathExtension.lowercased()
        if let byExtension = candidates.first(where: {
            URL(fileURLWithPath: $0.name).pathExtension.lowercased() == ext
        }) { return byExtension }
        return candidates.count == 1 ? candidates.first : nil
    }
}
