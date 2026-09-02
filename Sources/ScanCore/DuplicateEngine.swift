// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import CryptoKit

/// A group of files with identical content.
public struct DuplicateGroup: Sendable, Identifiable {
    public let id: String          // full content hash
    public let fileSize: Int64
    public let urls: [URL]
    /// Modification date captured at scan time, per url. Used to detect a file
    /// that changed between the scan and the moment the user confirms deletion —
    /// such a file is no longer known to be a duplicate and must not be trashed.
    public let modificationDates: [URL: Date]

    public init(id: String, fileSize: Int64, urls: [URL], modificationDates: [URL: Date] = [:]) {
        self.id = id
        self.fileSize = fileSize
        self.urls = urls
        self.modificationDates = modificationDates
    }

    /// Suggested file to keep: shallowest path wins, lexicographic path as the
    /// tiebreak. Deliberately not modification-date-based — a duplicate's
    /// mtime often reflects when a *copy* operation happened, not which one
    /// is the "original," so path shape is the more honest signal here.
    public var keeper: URL { urls.min { ($0.pathComponents.count, $0.path) < ($1.pathComponents.count, $1.path) }! }
    /// Bytes reclaimable if all but the keeper are removed.
    public var wastedBytes: Int64 { fileSize * Int64(urls.count - 1) }

    /// True when the file on disk no longer matches its scan-time modification
    /// date (changed, or vanished). Callers must skip such a url before deleting:
    /// its duplicate status is stale.
    public func hasChangedOnDisk(_ url: URL) -> Bool {
        guard let scanned = modificationDates[url] else { return true }
        // Read through a fresh URL: URL instances cache resource values, so the
        // scan-time date would otherwise be returned instead of the disk truth.
        let fresh = URL(fileURLWithPath: url.path)
        let current = (try? fresh.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard let current else { return true }   // unreadable/missing → treat as changed
        // Tolerance absorbs sub-second timestamp precision drift between the
        // enumerator's cached values and a fresh read; a real edit moves the
        // mtime by far more than a second.
        return abs(current.timeIntervalSince(scanned)) > 1
    }
}

public enum DuplicateEvent: Sendable {
    case progress(stage: String, processed: Int, total: Int)
    case group(DuplicateGroup)
    case finished(groups: Int, wastedBytes: Int64)
    case cancelled
}

/// Staged duplicate detector: size grouping → 64 KB partial hash → full SHA-256.
/// Hard links to the same inode are collapsed to one entry (not duplicates).
public struct DuplicateEngine: Sendable {
    public let roots: [URL]
    public let minimumSize: Int64

    public init(roots: [URL], minimumSize: Int64 = 1_000_000) {
        self.roots = roots
        self.minimumSize = minimumSize
    }

    public func run(pauseController: ScanPauseController? = nil) -> AsyncStream<DuplicateEvent> {
        let roots = roots
        let minimumSize = minimumSize
        return AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                // Stage 1: inventory by size, collapsing hard links per (device, inode).
                var bySize: [Int64: [URL]] = [:]
                var seenInodes = Set<String>()
                var modDates: [URL: Date] = [:]
                let baseKeys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey,
                                                     .fileSizeKey, .fileResourceIdentifierKey,
                                                     .contentModificationDateKey]
                let keys = baseKeys.union(CloudFile.inventoryKeys)
                for root in roots {
                    guard let enumerator = FileManager.default.enumerator(
                        at: root, includingPropertiesForKeys: Array(keys),
                        options: [.skipsPackageDescendants]) else { continue }
                    await Self.inventory(enumerator, keys: keys, minimumSize: minimumSize,
                                         bySize: &bySize, seenInodes: &seenInodes, modDates: &modDates,
                                         pauseController: pauseController)
                    if Task.isCancelled { break }
                }

                let candidates = bySize.filter { $0.value.count > 1 }
                let totalFiles = candidates.values.reduce(0) { $0 + $1.count }
                var processed = 0
                var groupCount = 0
                var wasted: Int64 = 0

                // Stages 2+3 per size bucket.
                for (size, urls) in candidates {
                    if Task.isCancelled { break }
                    var byPartial: [Data: [URL]] = [:]
                    for url in urls {
                        await pauseController?.waitWhilePaused()
                        if Task.isCancelled { break }
                        processed += 1
                        if processed % 32 == 0 {
                            continuation.yield(.progress(stage: "hashing", processed: processed, total: totalFiles))
                        }
                        guard let partial = Self.hash(url: url, limit: 65_536) else { continue }
                        byPartial[partial, default: []].append(url)
                    }
                    for sameStart in byPartial.values where sameStart.count > 1 {
                        var byFull: [Data: [URL]] = [:]
                        for url in sameStart {
                            await pauseController?.waitWhilePaused()
                            if Task.isCancelled { break }
                            guard let full = Self.hash(url: url, limit: nil) else { continue }
                            byFull[full, default: []].append(url)
                        }
                        for (hash, dupes) in byFull where dupes.count > 1 {
                            let sortedDupes = dupes.sorted { $0.path < $1.path }
                            let group = DuplicateGroup(
                                id: hash.map { String(format: "%02x", $0) }.joined(),
                                fileSize: size,
                                urls: sortedDupes,
                                modificationDates: Dictionary(uniqueKeysWithValues:
                                    sortedDupes.map { ($0, modDates[$0] ?? .distantPast) }))
                            groupCount += 1
                            wasted += group.wastedBytes
                            continuation.yield(.group(group))
                        }
                    }
                }
                continuation.yield(Task.isCancelled ? .cancelled : .finished(groups: groupCount, wastedBytes: wasted))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func inventory(_ enumerator: FileManager.DirectoryEnumerator,
                                  keys: Set<URLResourceKey>, minimumSize: Int64,
                                  bySize: inout [Int64: [URL]], seenInodes: inout Set<String>,
                                  modDates: inout [URL: Date],
                                  pauseController: ScanPauseController? = nil) async {
        while let url = enumerator.nextObject() as? URL {
            await pauseController?.waitWhilePaused()
            if Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard values.isDirectory != true else { continue }
            // Never hydrate a remote-only iCloud placeholder just to hash it.
            if CloudFile.isRemoteOnly(values) { continue }
            let size = Int64(values.fileSize ?? 0)
            guard size >= minimumSize else { continue }
            if let identifier = values.fileResourceIdentifier {
                let key = "\(identifier)"
                guard !seenInodes.contains(key) else { continue }   // hard link duplicate
                seenInodes.insert(key)
            }
            bySize[size, default: []].append(url)
            modDates[url] = values.contentModificationDate ?? .distantPast
        }
    }

    /// Streaming SHA-256; `limit` nil = whole file.
    private static func hash(url: URL, limit: Int?) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var remaining = limit ?? Int.max
        while remaining > 0 {
            let chunkSize = min(remaining, 1_048_576)
            guard let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
            remaining -= chunk.count
        }
        return Data(hasher.finalize())
    }
}
