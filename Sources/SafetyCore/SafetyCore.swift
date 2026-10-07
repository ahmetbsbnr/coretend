import Foundation
import Darwin

public struct FileIdentity: Hashable, Sendable {
    public let standardizedPath: String
    public let device: UInt64
    public let inode: UInt64
    // Content metadata is checked for regular files; directory child mutations must not
    // invalidate the selected root's identity during a batch.
    public let size: Int64?
    public let modifiedSeconds: Int64?
    public let modifiedNanoseconds: Int64?
    public let changedSeconds: Int64?
    public let changedNanoseconds: Int64?

    public init(url: URL) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) != S_IFLNK else {
            throw PathRefusal.unreadableOrSymlink
        }
        standardizedPath = url.standardizedFileURL.path
        device = UInt64(info.st_dev)
        inode = UInt64(info.st_ino)
        let regular = (info.st_mode & S_IFMT) == S_IFREG
        size = regular ? Int64(info.st_size) : nil
        modifiedSeconds = regular ? Int64(info.st_mtimespec.tv_sec) : nil
        modifiedNanoseconds = regular ? Int64(info.st_mtimespec.tv_nsec) : nil
        changedSeconds = regular ? Int64(info.st_ctimespec.tv_sec) : nil
        changedNanoseconds = regular ? Int64(info.st_ctimespec.tv_nsec) : nil
    }
}

public enum PathRefusal: Error, Equatable, Sendable {
    case unreadableOrSymlink
    case outsideAllowedRoot
    case ruleNotAllowed
    case missingTarget
    case identityChanged
    case expiredApproval
    case invalidLifetime
}

public struct ApprovedFileOperation: Sendable {
    public let id: UUID
    public let target: FileIdentity
    public let ruleID: String
    public let approvedAt: Date
    public let expiresAt: Date

    fileprivate init(target: FileIdentity, ruleID: String, approvedAt: Date, expiresAt: Date) {
        id = UUID()
        self.target = target
        self.ruleID = ruleID
        self.approvedAt = approvedAt
        self.expiresAt = expiresAt
    }
}

public struct PathValidator: Sendable {
    public init() {}

    public func approve(target: URL, allowedRoots: [URL], ruleID: String,
                        allowedRuleIDs: Set<String>, expectedIdentity: FileIdentity? = nil, now: Date = .now,
                        lifetime: TimeInterval = 120) throws -> ApprovedFileOperation {
        guard lifetime > 0, lifetime <= 300 else { throw PathRefusal.invalidLifetime }
        guard allowedRuleIDs.contains(ruleID) else { throw PathRefusal.ruleNotAllowed }
        let identity = try FileIdentity(url: target)
        if let expectedIdentity, identity != expectedIdentity { throw PathRefusal.identityChanged }
        guard Self.isWithin(identity, roots: allowedRoots) else {
            throw PathRefusal.outsideAllowedRoot
        }
        return ApprovedFileOperation(target: identity, ruleID: ruleID,
                                     approvedAt: now, expiresAt: now.addingTimeInterval(lifetime))
    }

    fileprivate func revalidate(_ operation: ApprovedFileOperation, allowedRoots: [URL],
                                allowedRuleIDs: Set<String>, now: Date) throws -> URL {
        guard now <= operation.expiresAt else { throw PathRefusal.expiredApproval }
        guard allowedRuleIDs.contains(operation.ruleID) else { throw PathRefusal.ruleNotAllowed }
        let url = URL(fileURLWithPath: operation.target.standardizedPath)
        let current = try FileIdentity(url: url)
        guard current == operation.target else { throw PathRefusal.identityChanged }
        guard Self.isWithin(current, roots: allowedRoots) else {
            throw PathRefusal.outsideAllowedRoot
        }
        return url
    }

    private static func isWithin(_ identity: FileIdentity, roots: [URL]) -> Bool {
        roots.contains { root in
            let standardizedRoot = root.standardizedFileURL
            var rootInfo = stat()
            guard lstat(standardizedRoot.path, &rootInfo) == 0, (rootInfo.st_mode & S_IFMT) == S_IFDIR else { return false }
            let rootPath = standardizedRoot.resolvingSymlinksInPath().path
            var resolvedRootInfo = stat()
            guard stat(rootPath, &resolvedRootInfo) == 0, UInt64(resolvedRootInfo.st_dev) == identity.device else { return false }
            let candidate = URL(fileURLWithPath: identity.standardizedPath).resolvingSymlinksInPath().path
            return candidate == rootPath || candidate.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
        }
    }
}

public enum ActionFailure: Error, Equatable, Sendable {
    case revalidation(PathRefusal)
    case trashFailed(String)
    case auditUnavailable
}

public enum RefusalReason: Equatable, Sendable { case userDeclined }
public enum ActionOutcome: Equatable, Sendable {
    case movedToTrash(original: String, trashURL: String)
    case refused(RefusalReason)
    case failed(ActionFailure)
    case cancelled
}

public protocol TrashClient: Sendable {
    func moveToTrash(_ url: URL) async throws -> URL
}

public protocol FileOperationExecutor: Sendable {
    func execute(_ operation: ApprovedFileOperation) async -> ActionOutcome
}

public struct ActionEvent: Sendable, Equatable {
    public let operationID: UUID
    public let occurredAt: Date
    public let outcome: ActionOutcome
}

public struct SafeActionExecutor: FileOperationExecutor {
    private let validator: PathValidator
    private let roots: [URL]
    private let allowedRules: Set<String>
    private let trash: any TrashClient
    private let expectedRootIdentities: [URL: FileIdentity]
    private let clock: @Sendable () -> Date

    public init(validator: PathValidator = .init(), allowedRoots: [URL],
                allowedRules: Set<String>, trash: any TrashClient,
                expectedRootIdentities: [URL: FileIdentity] = [:],
                clock: @escaping @Sendable () -> Date = { .now }) {
        self.validator = validator
        self.roots = allowedRoots
        self.allowedRules = allowedRules
        self.trash = trash
        self.expectedRootIdentities = expectedRootIdentities
        self.clock = clock
    }

    public func execute(_ operation: ApprovedFileOperation) async -> ActionOutcome {
        for (root, expectedIdentity) in expectedRootIdentities {
            guard let currentIdentity = try? FileIdentity(url: root), currentIdentity == expectedIdentity else {
                return .failed(.revalidation(.identityChanged))
            }
            var info = stat()
            guard lstat(root.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR else {
                return .failed(.revalidation(.identityChanged))
            }
        }
        let url: URL
        do { url = try validator.revalidate(operation, allowedRoots: roots, allowedRuleIDs: allowedRules, now: clock()) }
        catch let refusal as PathRefusal { return .failed(.revalidation(refusal)) }
        catch { return .failed(.revalidation(.missingTarget)) }
        do {
            let moved = try await trash.moveToTrash(url)
            return .movedToTrash(original: url.path, trashURL: moved.path)
        } catch {
            return .failed(.trashFailed(String(describing: error)))
        }
    }
}

public struct MacOSTrashClient: TrashClient {
    public init() {}
    public func moveToTrash(_ url: URL) async throws -> URL {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        guard let resultingURL else { throw CocoaError(.fileWriteUnknown) }
        return resultingURL as URL
    }
}

public enum RestoreRefusal: Error, Equatable, Sendable {
    /// The item is no longer in a Trash folder.
    case notInTrash
    /// Something already stands at the original place.
    case originalOccupied
    /// The folder that held it is gone.
    case originalFolderMissing
}

/// Undo for a move to the Trash: puts an item CoreTend moved back where it was. It only takes an
/// item from a Trash folder, and only to a place that is free and whose folder still exists, so it
/// can never overwrite or erase anything.
public struct TrashRestorer: Sendable {
    public init() {}

    public func restore(_ trashURL: URL, to original: URL) throws {
        let trashPath = trashURL.standardizedFileURL.path
        guard trashPath.contains("/.Trash/") || trashPath.contains("/.Trashes/") else { throw RestoreRefusal.notInTrash }
        var info = stat()
        guard lstat(trashPath, &info) == 0 else { throw PathRefusal.missingTarget }
        guard lstat(original.standardizedFileURL.path, &info) != 0 else { throw RestoreRefusal.originalOccupied }
        var folder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: original.deletingLastPathComponent().path, isDirectory: &folder), folder.boolValue else {
            throw RestoreRefusal.originalFolderMissing
        }
        try FileManager.default.moveItem(at: trashURL, to: original)
    }
}

public enum SystemCacheRefusal: Error, Equatable, Sendable {
    /// Not a direct child of the system caches folder, an Apple cache, or a symbolic link.
    case notASystemCache
    /// The destination is not the person's own Trash folder.
    case notATrashFolder
    /// The system refused the rename (errno).
    case moveFailed(Int32)
}

/// For the system helper only (it runs as root): moves one direct child of /Library/Caches into
/// the Trash folder of the person who asked, under a free name. One rename between two folders
/// held open without following links, so a link swapped in by anyone cannot redirect it; the item
/// is never copied, never overwritten, never erased, and Undo (`TrashRestorer`) can put it back.
public struct SystemCacheTrasher: Sendable {
    public let cachesRoot: URL

    public init(cachesRoot: URL = URL(fileURLWithPath: "/Library/Caches", isDirectory: true)) {
        self.cachesRoot = cachesRoot.standardizedFileURL
    }

    /// Whether `item` is something this type may move: a direct child of the caches folder, not an
    /// Apple cache, not a symbolic link.
    public func accepts(_ item: URL) -> Bool {
        let item = item.standardizedFileURL
        guard item.deletingLastPathComponent().path == cachesRoot.path else { return false }
        let name = item.lastPathComponent
        guard !name.isEmpty, !name.hasPrefix("."), !name.lowercased().hasPrefix("com.apple.") else { return false }
        var info = stat()
        guard lstat(item.path, &info) == 0 else { return false }
        return (info.st_mode & S_IFMT) != S_IFLNK
    }

    /// `trashFolder` must be a real folder named `.Trash` owned by `owner`.
    public func trash(_ item: URL, into trashFolder: URL, owner: uid_t) throws -> URL {
        let item = item.standardizedFileURL
        guard accepts(item) else { throw SystemCacheRefusal.notASystemCache }
        let trash = trashFolder.standardizedFileURL
        guard trash.lastPathComponent == ".Trash" else { throw SystemCacheRefusal.notATrashFolder }
        let source = Darwin.open(cachesRoot.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard source >= 0 else { throw SystemCacheRefusal.notASystemCache }
        defer { close(source) }
        let destination = Darwin.open(trash.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard destination >= 0 else { throw SystemCacheRefusal.notATrashFolder }
        defer { close(destination) }
        var info = stat()
        guard fstat(destination, &info) == 0, info.st_uid == owner else { throw SystemCacheRefusal.notATrashFolder }
        let name = item.lastPathComponent
        var attempt = 1
        while true {
            let target = attempt == 1 ? name : "\(name) \(attempt)"
            // RENAME_EXCL: an existing item in the Trash is never replaced.
            if renameatx_np(source, name, destination, target, UInt32(RENAME_EXCL)) == 0 {
                return trash.appendingPathComponent(target)
            }
            guard errno == EEXIST, attempt < 1000 else { throw SystemCacheRefusal.moveFailed(errno) }
            attempt += 1
        }
    }
}
