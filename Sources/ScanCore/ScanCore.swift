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
    ///
    /// Rules execute with bounded concurrency: at most `configuration.maxConcurrency`
    /// rules walk the filesystem at once. Each rule computes its own (scanned, bytes)
    /// subtotal in isolation; the parent task sums those subtotals as they arrive, so
    /// aggregation is single-threaded and cannot double-count. The finding *set* is
    /// independent of concurrency (only interleaving order differs); the AsyncStream
    /// continuation is safe to yield to from concurrent tasks. Cancellation propagates
    /// from stream termination → parent task → the child task group.
    public func run(rules: [ScanRule]) -> AsyncStream<ScanEvent> {
        let config = configuration
        return AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                continuation.yield(.started)
                let cutoffCache = Date()
                var scanned = 0
                var totalBytes: Int64 = 0

                await withTaskGroup(of: (Int, Int64).self) { group in
                    var index = 0
                    var inFlight = 0
                    let limit = config.maxConcurrency

                    func addRule(_ rule: ScanRule) {
                        let cutoff = cutoffCache.addingTimeInterval(-Double(rule.minimumAgeDays) * 86_400)
                        group.addTask(priority: .utility) {
                            if Task.isCancelled { return (0, 0) }
                            var localScanned = 0
                            var localBytes: Int64 = 0
                            let fm = FileManager.default
                            for root in rule.roots(config.home) {
                                if Task.isCancelled { break }
                                guard fm.fileExists(atPath: root.path) else { continue }
                                Self.scanRoot(root, rule: rule, cutoff: cutoff,
                                              excludedPaths: config.excludedPaths,
                                              scanned: &localScanned, totalBytes: &localBytes,
                                              continuation: continuation)
                            }
                            return (localScanned, localBytes)
                        }
                    }

                    // Prime the pool up to the concurrency limit, then refill as
                    // each rule finishes — bounded in-flight count, no unbounded
                    // task accumulation regardless of rule count.
                    while index < rules.count && inFlight < limit {
                        addRule(rules[index]); index += 1; inFlight += 1
                    }
                    while inFlight > 0 {
                        guard let (s, b) = await group.next() else { break }
                        scanned += s; totalBytes += b; inFlight -= 1
                        if index < rules.count && !Task.isCancelled {
                            addRule(rules[index]); index += 1; inFlight += 1
                        }
                    }
                }

                continuation.yield(Task.isCancelled ? .cancelled : .finished(scanned: scanned, totalBytes: totalBytes))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Synchronous directory walk; called from a rule's scan task.
    /// Kept out of the async context because FileManager.DirectoryEnumerator
    /// iteration is unavailable in async functions. Writes only to the caller's
    /// local counters, so concurrent rules never share mutable state.
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
