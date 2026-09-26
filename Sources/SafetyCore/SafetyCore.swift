import Foundation
import Darwin

public struct FileIdentity: Hashable, Sendable {
    public let standardizedPath: String
    public let device: UInt64
    public let inode: UInt64

    public init(url: URL) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) != S_IFLNK else {
            throw PathRefusal.unreadableOrSymlink
        }
        standardizedPath = url.standardizedFileURL.path
        device = UInt64(info.st_dev)
        inode = UInt64(info.st_ino)
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
                        allowedRuleIDs: Set<String>, now: Date = .now,
                        lifetime: TimeInterval = 120) throws -> ApprovedFileOperation {
        guard lifetime > 0, lifetime <= 300 else { throw PathRefusal.invalidLifetime }
        guard allowedRuleIDs.contains(ruleID) else { throw PathRefusal.ruleNotAllowed }
        let identity = try FileIdentity(url: target)
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
            let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
            var rootInfo = stat()
            guard stat(rootPath, &rootInfo) == 0, UInt64(rootInfo.st_dev) == identity.device else { return false }
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
    private let clock: @Sendable () -> Date

    public init(validator: PathValidator = .init(), allowedRoots: [URL],
                allowedRules: Set<String>, trash: any TrashClient,
                clock: @escaping @Sendable () -> Date = { .now }) {
        self.validator = validator
        self.roots = allowedRoots
        self.allowedRules = allowedRules
        self.trash = trash
        self.clock = clock
    }

    public func execute(_ operation: ApprovedFileOperation) async -> ActionOutcome {
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
