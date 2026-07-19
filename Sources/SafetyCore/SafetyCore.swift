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
    case notRegularFileOrDirectory
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

/// Central approval + execution actor. Re-validates just before acting and
/// supports a global dry-run mode.
public actor SafetyCenter {
    private let validator: PathValidator
    private let fileManager = FileManager.default
    public private(set) var dryRun: Bool
    public private(set) var auditLog: [String] = []

    public init(validator: PathValidator, dryRun: Bool = true) {
        self.validator = validator
        self.dryRun = dryRun
    }

    public func setDryRun(_ value: Bool) { dryRun = value }

    /// Produces an approved operation, or throws if the path fails validation.
    public func approve(url: URL, logicalSize: Int64, ruleID: String, risk: RiskLevel) throws(SafetyError) -> ApprovedFileOperation {
        let validated = try validator.validate(url)
        return ApprovedFileOperation(kind: .moveToTrash, url: validated, logicalSize: logicalSize, ruleID: ruleID, risk: risk)
    }

    public struct ExecutionResult: Sendable {
        public let executed: [ApprovedFileOperation]
        public let skipped: [(ApprovedFileOperation, SafetyError)]
        public let wasDryRun: Bool
    }

    /// Moves approved items to the Trash. Every path is re-validated at
    /// execution time; anything that changed since approval is skipped.
    public func execute(_ operations: [ApprovedFileOperation]) -> ExecutionResult {
        var executed: [ApprovedFileOperation] = []
        var skipped: [(ApprovedFileOperation, SafetyError)] = []
        for op in operations {
            do throws(SafetyError) {
                let url = try validator.validate(op.url)
                guard fileManager.fileExists(atPath: url.path) else { throw .fileVanished }
                if !dryRun {
                    do {
                        try fileManager.trashItem(at: url, resultingItemURL: nil)
                    } catch {
                        skipped.append((op, .fileVanished))
                        continue
                    }
                }
                auditLog.append("\(dryRun ? "DRY-RUN" : "TRASH") \(url.path) rule=\(op.ruleID)")
                executed.append(op)
            } catch {
                skipped.append((op, error))
            }
        }
        return ExecutionResult(executed: executed, skipped: skipped, wasDryRun: dryRun)
    }
}
