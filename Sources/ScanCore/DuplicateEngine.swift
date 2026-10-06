import Foundation
import CryptoKit
import Darwin

private struct InodeIdentity: Hashable { let device: UInt64; let inode: UInt64 }

public struct DuplicateGroup: Sendable, Equatable {
    public let digest: String
    public let files: [URL]
    public let suggestedKeeper: URL
}

public struct DuplicateScanIssue: Sendable, Equatable {
    public let path: String
    public let reason: String
}

public struct DuplicateScanReport: Sendable, Equatable {
    public let groups: [DuplicateGroup]
    public let issues: [DuplicateScanIssue]
    public let snapshots: [URL: DuplicateFileSnapshot]
}

public enum DuplicateScanProgress: Sendable, Equatable {
    case duplicateHashing(completedCandidates: Int, totalCandidates: Int)
    case imageCandidates(completedCandidates: Int, totalCandidates: Int)
    case imageComparisons(completedPairs: Int, totalPairs: Int)
}

public struct DuplicateFileSnapshot: Equatable, Sendable {
    public let device: UInt64
    public let inode: UInt64
    public let size: Int64
    public let modifiedSeconds: Int64
    public let modifiedNanoseconds: Int64
    public let changedSeconds: Int64
    public let changedNanoseconds: Int64

    init(url: URL) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        self.init(info: info)
    }

    init(fileDescriptor: Int32) throws {
        var info = stat()
        guard fstat(fileDescriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        self.init(info: info)
    }

    private init(info: stat) {
        device = UInt64(info.st_dev)
        inode = UInt64(info.st_ino)
        size = Int64(info.st_size)
        modifiedSeconds = Int64(info.st_mtimespec.tv_sec)
        modifiedNanoseconds = Int64(info.st_mtimespec.tv_nsec)
        changedSeconds = Int64(info.st_ctimespec.tv_sec)
        changedNanoseconds = Int64(info.st_ctimespec.tv_nsec)
    }
    fileprivate var identity: InodeIdentity { InodeIdentity(device: device, inode: inode) }
}

public struct DuplicateEngine: Sendable {
    public init() {}

    public func findGroups(
        in candidates: [ScanResult],
        progress: @escaping @Sendable (DuplicateScanProgress) -> Void = { _ in }
    ) async throws -> DuplicateScanReport {
        var sizeBuckets: [Int64: [URL]] = [:]
        for candidate in candidates {
            guard case .known(let size) = candidate.logicalBytes, size >= 0 else { continue }
            sizeBuckets[size, default: []].append(candidate.url)
        }
        let totalCandidates = sizeBuckets.values.filter { $0.count > 1 }.reduce(0) { $0 + $1.count }
        progress(.duplicateHashing(completedCandidates: 0, totalCandidates: totalCandidates))
        var digestBuckets: [String: [URL]] = [:]
        var issues: [DuplicateScanIssue] = []
        var snapshots: [URL: DuplicateFileSnapshot] = [:]
        var completedCandidates = 0
        func advance() {
            completedCandidates += 1
            progress(.duplicateHashing(completedCandidates: completedCandidates, totalCandidates: totalCandidates))
        }
        for (expectedSize, urls) in sizeBuckets where urls.count > 1 {
            var seenIdentities: Set<InodeIdentity> = []
            var ready: [(url: URL, before: DuplicateFileSnapshot)] = []
            for url in urls.sorted(by: { $0.path < $1.path }) {
                try Task.checkCancellation()
                do {
                    let before = try DuplicateFileSnapshot(url: url)
                    guard before.size == expectedSize else {
                        issues.append(DuplicateScanIssue(path: url.path, reason: "file_size_changed_since_scan")); advance(); continue
                    }
                    guard seenIdentities.insert(before.identity).inserted else { advance(); continue }
                    ready.append((url, before))
                } catch { issues.append(DuplicateScanIssue(path: url.path, reason: "hash_failed_or_file_changed")); advance() }
            }
            // Large files of the same size are first compared by their beginning: a file whose
            // first bytes match no other cannot be a copy, and is not read in full.
            if ready.count > 1, expectedSize > Self.headLength * 4 {
                var heads: [String: [(url: URL, before: DuplicateFileSnapshot)]] = [:]
                for item in ready {
                    try Task.checkCancellation()
                    do { heads[try hash(item.url, expected: item.before, limit: Self.headLength), default: []].append(item) }
                    catch is CancellationError { throw CancellationError() }
                    catch { issues.append(DuplicateScanIssue(path: item.url.path, reason: "hash_failed_or_file_changed")); advance() }
                }
                ready = []
                for members in heads.values {
                    if members.count > 1 { ready += members } else { advance() }
                }
                ready.sort { $0.url.path < $1.url.path }
            }
            for (url, before) in ready {
                defer { advance() }
                try Task.checkCancellation()
                do {
                    let digest = try hash(url, expected: before)
                    let after = try DuplicateFileSnapshot(url: url)
                    guard before == after else {
                        issues.append(DuplicateScanIssue(path: url.path, reason: "file_changed_during_hash")); continue
                    }
                    digestBuckets[digest, default: []].append(url)
                    snapshots[url] = after
                } catch is CancellationError { throw CancellationError() }
                catch { issues.append(DuplicateScanIssue(path: url.path, reason: "hash_failed_or_file_changed")) }
            }
        }
        let groups = digestBuckets.compactMap { digest, urls -> DuplicateGroup? in
            let sorted = urls.sorted { $0.path < $1.path }
            guard sorted.count > 1, let keeper = sorted.first else { return nil }
            return DuplicateGroup(digest: digest, files: sorted, suggestedKeeper: keeper)
        }.sorted { $0.suggestedKeeper.path < $1.suggestedKeeper.path }
        return DuplicateScanReport(groups: groups, issues: issues, snapshots: snapshots)
    }

    private static let headLength: Int64 = 65_536

    /// SHA-256 of the file's content, or of its first `limit` bytes.
    private func hash(_ url: URL, expected: DuplicateFileSnapshot, limit: Int64? = nil) throws -> String {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoSuchFile) }
        defer { _ = close(descriptor) }
        guard try DuplicateFileSnapshot(fileDescriptor: descriptor) == expected else { throw CocoaError(.fileReadCorruptFile) }
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 1_048_576)
        var remaining = limit ?? Int64.max
        while remaining > 0 {
            try Task.checkCancellation()
            let wanted = Int(min(Int64(buffer.count), remaining))
            let count = buffer.withUnsafeMutableBytes { bytes in read(descriptor, bytes.baseAddress, wanted) }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw CocoaError(.fileReadUnknown)
            }
            buffer.withUnsafeBytes { bytes in hasher.update(bufferPointer: UnsafeRawBufferPointer(rebasing: bytes.prefix(count))) }
            remaining -= Int64(count)
        }
        guard try DuplicateFileSnapshot(fileDescriptor: descriptor) == expected else { throw CocoaError(.fileReadCorruptFile) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
