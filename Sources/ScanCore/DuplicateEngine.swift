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
}

private struct FileSnapshot: Equatable {
    let device: UInt64
    let inode: UInt64
    let size: Int64
    let modifiedSeconds: Int64
    let modifiedNanoseconds: Int64

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
    }
    var identity: InodeIdentity { InodeIdentity(device: device, inode: inode) }
}

public struct DuplicateEngine: Sendable {
    public init() {}

    public func findGroups(in candidates: [ScanResult]) async throws -> DuplicateScanReport {
        var sizeBuckets: [Int64: [URL]] = [:]
        for candidate in candidates {
            guard case .known(let size) = candidate.logicalBytes, size >= 0 else { continue }
            sizeBuckets[size, default: []].append(candidate.url)
        }
        var digestBuckets: [String: [URL]] = [:]
        var issues: [DuplicateScanIssue] = []
        for (expectedSize, urls) in sizeBuckets where urls.count > 1 {
            var seenIdentities: Set<InodeIdentity> = []
            for url in urls.sorted(by: { $0.path < $1.path }) {
                try Task.checkCancellation()
                do {
                    let before = try FileSnapshot(url: url)
                    guard before.size == expectedSize else {
                        issues.append(DuplicateScanIssue(path: url.path, reason: "file_size_changed_since_scan")); continue
                    }
                    guard seenIdentities.insert(before.identity).inserted else { continue }
                    let digest = try hash(url, expected: before)
                    let after = try FileSnapshot(url: url)
                    guard before == after else {
                        issues.append(DuplicateScanIssue(path: url.path, reason: "file_changed_during_hash")); continue
                    }
                    digestBuckets[digest, default: []].append(url)
                } catch is CancellationError { throw CancellationError() }
                catch { issues.append(DuplicateScanIssue(path: url.path, reason: "hash_failed_or_file_changed")) }
            }
        }
        let groups = digestBuckets.compactMap { digest, urls -> DuplicateGroup? in
            let sorted = urls.sorted { $0.path < $1.path }
            guard sorted.count > 1, let keeper = sorted.first else { return nil }
            return DuplicateGroup(digest: digest, files: sorted, suggestedKeeper: keeper)
        }.sorted { $0.suggestedKeeper.path < $1.suggestedKeeper.path }
        return DuplicateScanReport(groups: groups, issues: issues)
    }

    private func hash(_ url: URL, expected: FileSnapshot) throws -> String {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoSuchFile) }
        defer { _ = close(descriptor) }
        guard try FileSnapshot(fileDescriptor: descriptor) == expected else { throw CocoaError(.fileReadCorruptFile) }
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 1_048_576)
        while true {
            try Task.checkCancellation()
            let count = buffer.withUnsafeMutableBytes { bytes in read(descriptor, bytes.baseAddress, bytes.count) }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw CocoaError(.fileReadUnknown)
            }
            hasher.update(data: Data(buffer.prefix(count)))
        }
        guard try FileSnapshot(fileDescriptor: descriptor) == expected else { throw CocoaError(.fileReadCorruptFile) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
