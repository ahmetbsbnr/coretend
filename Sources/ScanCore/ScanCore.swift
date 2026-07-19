import Foundation
import SafetyCore

/// A single file found by a scan, with the evidence behind its selection.
public struct ScanFinding: Sendable, Identifiable {
    public let id: UUID
    public let url: URL
    public let logicalSize: Int64
    public let allocatedSize: Int64?
    public let modificationDate: Date?
    public let ruleID: String
    public let category: String
    public let explanation: String
    public let confidence: Double
    public let risk: RiskLevel
    public let preselected: Bool

    public init(url: URL, logicalSize: Int64, allocatedSize: Int64?, modificationDate: Date?,
                ruleID: String, category: String, explanation: String,
                confidence: Double, risk: RiskLevel, preselected: Bool) {
        self.id = UUID()
        self.url = url
        self.logicalSize = logicalSize
        self.allocatedSize = allocatedSize
        self.modificationDate = modificationDate
        self.ruleID = ruleID
        self.category = category
        self.explanation = explanation
        self.confidence = confidence
        self.risk = risk
        self.preselected = preselected
    }
}

/// Events streamed by a running scan.
public enum ScanEvent: Sendable {
    case started
    case progress(scanned: Int, currentPath: String)
    case finding(ScanFinding)
    case error(path: String, message: String)
    case finished(scanned: Int, totalBytes: Int64)
    case cancelled
}

/// Declarative description of one scan rule. Rules only *find*; they never delete.
public struct ScanRule: Sendable {
    public let id: String
    public let name: String
    public let category: String
    public let explanation: String
    public let roots: @Sendable (URL) -> [URL]   // home -> candidate roots
    public let minimumAgeDays: Int
    public let risk: RiskLevel
    public let preselect: Bool
    /// Optional per-file filter (e.g. only partial-download extensions). nil = match all.
    public let matches: (@Sendable (URL) -> Bool)?
    /// Files smaller than this are ignored. 0 = no size filter.
    public let minimumSizeBytes: Int64

    public init(id: String, name: String, category: String, explanation: String,
                minimumAgeDays: Int = 0, risk: RiskLevel, preselect: Bool,
                matches: (@Sendable (URL) -> Bool)? = nil, minimumSizeBytes: Int64 = 0,
                roots: @escaping @Sendable (URL) -> [URL]) {
        self.id = id
        self.name = name
        self.category = category
        self.explanation = explanation
        self.roots = roots
        self.minimumAgeDays = minimumAgeDays
        self.risk = risk
        self.preselect = preselect
        self.matches = matches
        self.minimumSizeBytes = minimumSizeBytes
    }
}

public struct ScanConfiguration: Sendable {
    public var home: URL
    public var maxConcurrency: Int
    public var followSymlinks: Bool
    /// Absolute paths (and their subtrees) excluded from every scan.
    public var excludedPaths: [String]

    /// Strips the "/private" prefix Foundation adds/removes inconsistently for
    /// /var, /tmp and /etc, so path comparisons are stable.
    static func canonical(_ path: String) -> String {
        path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
    }

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                maxConcurrency: Int = 3, followSymlinks: Bool = false,
                excludedPaths: [String] = []) {
        self.home = home
        self.maxConcurrency = min(max(maxConcurrency, 1), 4)
        self.followSymlinks = followSymlinks
        self.excludedPaths = excludedPaths.map {
            Self.canonical(URL(fileURLWithPath: $0).standardizedFileURL.path)
        }
    }
}

/// Streaming, cancellable scan engine. Never deletes anything.
public struct ScanEngine: Sendable {
    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey,
        .totalFileAllocatedSizeKey, .contentModificationDateKey, .isPackageKey,
    ]

    public let configuration: ScanConfiguration

    public init(configuration: ScanConfiguration = ScanConfiguration()) {
        self.configuration = configuration
    }

    /// Runs the given rules and streams events. Consumers drive backpressure
    /// through the AsyncStream buffer; results are never accumulated in memory here.
    public func run(rules: [ScanRule]) -> AsyncStream<ScanEvent> {
        let config = configuration
        return AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                continuation.yield(.started)
                var scanned = 0
                var totalBytes: Int64 = 0
                let fm = FileManager.default
                let cutoffCache = Date()

                for rule in rules {
                    if Task.isCancelled { break }
                    let cutoff = cutoffCache.addingTimeInterval(-Double(rule.minimumAgeDays) * 86_400)
                    for root in rule.roots(config.home) {
                        if Task.isCancelled { break }
                        guard fm.fileExists(atPath: root.path) else { continue }
                        Self.scanRoot(root, rule: rule, cutoff: cutoff,
                                      excludedPaths: config.excludedPaths,
                                      scanned: &scanned, totalBytes: &totalBytes,
                                      continuation: continuation)
                    }
                }
                continuation.yield(Task.isCancelled ? .cancelled : .finished(scanned: scanned, totalBytes: totalBytes))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Synchronous directory walk; called from the detached scan task.
    /// Kept out of the async context because FileManager.DirectoryEnumerator
    /// iteration is unavailable in async functions.
    private static func scanRoot(_ root: URL, rule: ScanRule, cutoff: Date,
                                 excludedPaths: [String],
                                 scanned: inout Int, totalBytes: inout Int64,
                                 continuation: AsyncStream<ScanEvent>.Continuation) {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants]
        ) else { return }

        for case let url as URL in enumerator {
            if Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: Set(resourceKeys)) else {
                continuation.yield(.error(path: url.path, message: "unreadable"))
                continue
            }
            let canonicalPath = ScanConfiguration.canonical(url.path)
            if excludedPaths.contains(where: { canonicalPath == $0 || canonicalPath.hasPrefix($0 + "/") }) {
                enumerator.skipDescendants()
                continue
            }
            // ponytail: symlinks skipped entirely for now; follow-with-loop-guard later.
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            scanned += 1
            if scanned % 512 == 0 {
                continuation.yield(.progress(scanned: scanned, currentPath: url.path))
            }
            guard values.isDirectory != true else { continue }
            let size = Int64(values.fileSize ?? 0)
            if let modified = values.contentModificationDate, modified > cutoff { continue }
            if size < rule.minimumSizeBytes { continue }
            if let matches = rule.matches, !matches(url) { continue }
            totalBytes += size
            continuation.yield(.finding(ScanFinding(
                url: url,
                logicalSize: size,
                allocatedSize: values.totalFileAllocatedSize.map(Int64.init),
                modificationDate: values.contentModificationDate,
                ruleID: rule.id,
                category: rule.category,
                explanation: rule.explanation,
                confidence: 0.9,
                risk: rule.risk,
                preselected: rule.preselect
            )))
        }
    }
}
