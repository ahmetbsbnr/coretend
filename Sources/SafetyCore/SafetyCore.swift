import Foundation

/// Risk level attached to every candidate file operation.
public enum RiskLevel: String, Sendable, Codable, Comparable {
    case low, medium, high

    private var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Typed errors produced by path validation.
public enum SafetyError: Error, Equatable, Sendable {
    case emptyPath
    case relativePath
    case protectedRoot(String)
    case outsideAllowedRoots
    case symlinkTraversal(String)
    case fileVanished
}

/// Validates paths against protected roots and per-operation allowlists.
/// All destructive engines must go through this type; they never accept raw URLs.
public struct PathValidator: Sendable {
    /// Roots that must never be touched, regardless of allowlists.
    public static let protectedRoots: [String] = [
        "/System", "/bin", "/sbin", "/usr/bin", "/usr/sbin", "/usr/lib",
        "/usr/libexec", "/usr/share", "/private/var/db", "/Library/Apple",
        "/Volumes/Recovery",
    ]

    /// User-content roots that must never be auto-selected for deletion.
    public static func userContentRoots(home: URL) -> [String] {
        ["Documents", "Desktop", "Pictures", "Music", "Movies"].map {
            home.appendingPathComponent($0).path
        }
    }

    public let allowedRoots: [URL]

    public init(allowedRoots: [URL]) {
        self.allowedRoots = allowedRoots.map { $0.standardizedFileURL }
    }

    /// Canonicalizes and validates a candidate path. Rejects protected roots,
    /// paths outside the allowlist, and symlinks whose target escapes the allowlist.
    public func validate(_ url: URL) throws(SafetyError) -> URL {
        let raw = url.path
        guard !raw.isEmpty else { throw .emptyPath }
        guard raw.hasPrefix("/") else { throw .relativePath }

        // Standardize removes "..", "." and trailing slashes without touching disk.
        let standardized = url.standardizedFileURL
        guard standardized.path != "/" else { throw .protectedRoot("/") }

        for root in Self.protectedRoots where Self.isPath(standardized.path, under: root) {
            throw .protectedRoot(root)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        guard standardized.path != home.path else { throw .protectedRoot(home.path) }

        guard allowedRoots.contains(where: { Self.isPath(standardized.path, under: $0.path) }) else {
            throw .outsideAllowedRoots
        }

        // Resolve symlinks on the real filesystem; the resolved target must also
        // stay inside the allowlist (defends against symlink swaps).
        let resolved = standardized.resolvingSymlinksInPath()
        if resolved.path != standardized.path {
            guard allowedRoots.contains(where: { Self.isPath(resolved.path, under: $0.path) }) else {
                throw .symlinkTraversal(resolved.path)
            }
        }
        return standardized
    }

    /// Prefix check that respects path-component boundaries ("/a/bc" is not under "/a/b").
    public static func isPath(_ path: String, under root: String) -> Bool {
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
}

/// One lifecycle event for a single file operation, emitted to an optional
/// `SafetyAuditSink` so callers can persist a durable log. Carries the raw
/// path — sinks that persist to disk must redact it themselves (see
/// `Persistence.Store`'s conformance); SafetyCore never writes to disk
/// itself and never includes file content, only path/rule/risk/size/result.
public struct SafetyAuditEvent: Sendable {
    public enum Stage: String, Sendable {
        case approved   // path validated, operation queued
        case executed   // real trash/restore action performed after confirmation
        case skipped    // re-validation failed at execute time, nothing touched
        case error      // the underlying file-system call itself failed
    }

    public let operationID: UUID
    public let stage: Stage
    public let path: String
    public let ruleID: String
    public let risk: RiskLevel
    public let size: Int64
    public let date: Date
    /// Short, non-sensitive result description (e.g. a SafetyError case name).
    /// Never a full error message that could embed file content or a stack trace.
    public let result: String

    public init(operationID: UUID, stage: Stage, path: String, ruleID: String,
                risk: RiskLevel, size: Int64, date: Date = Date(), result: String) {
        self.operationID = operationID
        self.stage = stage
        self.path = path
        self.ruleID = ruleID
        self.risk = risk
        self.size = size
        self.date = date
        self.result = result
    }
}

/// Durable sink for `SafetyAuditEvent`s. SafetyCore stays storage-agnostic;
/// `Persistence.Store` is the shipped implementation (append-only SQLite).
public protocol SafetyAuditSink: Sendable {
    func recordSafetyEvent(_ event: SafetyAuditEvent) async
}

/// A file operation that passed SafetyCore validation. Deletion engines accept
/// only this type — never a raw URL from the UI layer.
public struct ApprovedFileOperation: Sendable, Identifiable {
    public enum Kind: String, Sendable, Codable {
        case moveToTrash
    }

    public let id: UUID
    public let kind: Kind
    public let url: URL
    public let logicalSize: Int64
    public let ruleID: String
    public let risk: RiskLevel
    public let approvedAt: Date

    fileprivate init(kind: Kind, url: URL, logicalSize: Int64, ruleID: String, risk: RiskLevel) {
        self.id = UUID()
        self.kind = kind
        self.url = url
        self.logicalSize = logicalSize
        self.ruleID = ruleID
        self.risk = risk
        self.approvedAt = Date()
    }
}

/// Central approval + execution actor. Re-validates every approved path just
/// before moving it to the Trash.
public actor SafetyCenter {
    private let validator: PathValidator
    private let fileManager = FileManager.default
    private let sink: SafetyAuditSink?

    public init(validator: PathValidator, sink: SafetyAuditSink? = nil) {
        self.validator = validator
        self.sink = sink
    }

    /// Produces an approved operation, or throws if the path fails validation.
    public func approve(url: URL, logicalSize: Int64, ruleID: String, risk: RiskLevel) async throws(SafetyError) -> ApprovedFileOperation {
        do throws(SafetyError) {
            let validated = try validator.validate(url)
            let op = ApprovedFileOperation(kind: .moveToTrash, url: validated, logicalSize: logicalSize, ruleID: ruleID, risk: risk)
            await emit(.approved, operationID: op.id, path: validated.path, ruleID: ruleID, risk: risk, size: logicalSize, result: "approved")
            return op
        } catch {
            await emit(.error, operationID: UUID(), path: url.path, ruleID: ruleID, risk: risk, size: logicalSize, result: "\(error)")
            throw error
        }
    }

    private func emit(_ stage: SafetyAuditEvent.Stage, operationID: UUID, path: String,
                       ruleID: String, risk: RiskLevel, size: Int64, result: String) async {
        guard let sink else { return }
        let event = SafetyAuditEvent(operationID: operationID, stage: stage, path: path,
                                      ruleID: ruleID, risk: risk, size: size, result: result)
        await sink.recordSafetyEvent(event)
    }

    public struct ExecutionResult: Sendable {
        public let executed: [ApprovedFileOperation]
        public let skipped: [(ApprovedFileOperation, SafetyError)]
    }

    /// Moves approved items to the Trash. Every path is re-validated at
    /// execution time; anything that changed since approval is skipped.
    public func execute(_ operations: [ApprovedFileOperation]) async -> ExecutionResult {
        var executed: [ApprovedFileOperation] = []
        var skipped: [(ApprovedFileOperation, SafetyError)] = []
        for op in operations {
            do throws(SafetyError) {
                let url = try validator.validate(op.url)
                guard fileManager.fileExists(atPath: url.path) else { throw .fileVanished }
                do {
                    try fileManager.trashItem(at: url, resultingItemURL: nil)
                } catch {
                    if Self.isTemporaryPath(url) {
                        do {
                            try fileManager.removeItem(at: url)
                        } catch {
                            skipped.append((op, .fileVanished))
                            await emit(.error, operationID: op.id, path: url.path, ruleID: op.ruleID, risk: op.risk,
                                       size: op.logicalSize, result: "temporary remove failed")
                            continue
                        }
                    } else {
                        skipped.append((op, .fileVanished))
                        await emit(.error, operationID: op.id, path: url.path, ruleID: op.ruleID, risk: op.risk,
                                   size: op.logicalSize, result: "trashItem failed")
                        continue
                    }
                }
                await emit(.executed, operationID: op.id, path: url.path, ruleID: op.ruleID,
                           risk: op.risk, size: op.logicalSize, result: "moved to trash")
                executed.append(op)
            } catch {
                skipped.append((op, error))
                await emit(.skipped, operationID: op.id, path: op.url.path, ruleID: op.ruleID, risk: op.risk,
                           size: op.logicalSize, result: "\(error)")
            }
        }
        return ExecutionResult(executed: executed, skipped: skipped)
    }

    private static func isTemporaryPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let temporaryRoots = [
            URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path,
            "/private/tmp",
            "/tmp",
        ]
        return temporaryRoots.contains { PathValidator.isPath(path, under: $0) }
    }
}
