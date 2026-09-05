// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

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

public extension Array where Element == ScanFinding {
    /// Sums `allocatedSize` (physical/allocated bytes, from
    /// `totalFileAllocatedSizeKey`) across every finding — or `nil` if even
    /// one finding lacks a measurement. A partial sum presented as if it
    /// covered the whole set would be a silently misleading physical figure,
    /// worse than reporting none at all — see
    /// `Documentation/APFS_INTELLIGENCE.md` "Pairing rule": a physical total
    /// is only ever paired with a logical total describing the exact same
    /// file set, never a partial one dressed up as complete.
    var totalAllocatedSizeIfFullyKnown: Int64? {
        var total: Int64 = 0
        for finding in self {
            guard let allocated = finding.allocatedSize else { return nil }
            total += allocated
        }
        return total
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
    /// Rule-owned subtrees skipped before traversal, also used at execution.
    public let excludedRoots: @Sendable (URL) -> [URL]

    public init(id: String, name: String, category: String, explanation: String,
                minimumAgeDays: Int = 0, risk: RiskLevel, preselect: Bool,
                matches: (@Sendable (URL) -> Bool)? = nil, minimumSizeBytes: Int64 = 0,
                excludedRoots: @escaping @Sendable (URL) -> [URL] = { _ in [] },
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
        self.excludedRoots = excludedRoots
    }
}

public struct ScanConfiguration: Sendable {
    public var home: URL
    public var maxConcurrency: Int
    /// Absolute paths (and their subtrees) excluded from every scan.
    public var excludedPaths: [String]

    /// Strips the "/private" prefix Foundation adds/removes inconsistently for
    /// /var, /tmp and /etc, so path comparisons are stable.
    static func canonical(_ path: String) -> String {
        path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
    }

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                maxConcurrency: Int = 3,
                excludedPaths: [String] = []) {
        self.home = home
        self.maxConcurrency = min(max(maxConcurrency, 1), 4)
        self.excludedPaths = excludedPaths.map {
            Self.canonical(URL(fileURLWithPath: $0).standardizedFileURL.path)
        }
    }
}

/// Streaming, cancellable scan engine. Never deletes anything.
public struct ScanEngine: Sendable {
    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
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
    public func run(rules: [ScanRule], pauseController: ScanPauseController? = nil) -> AsyncStream<ScanEvent> {
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
                            let excluded = config.excludedPaths + rule.excludedRoots(config.home).map {
                                ScanConfiguration.canonical($0.standardizedFileURL.path)
                            }
                            for root in rule.roots(config.home) {
                                if Task.isCancelled { break }
                                let canonical = ScanConfiguration.canonical(root.standardizedFileURL.path)
                                if excluded.contains(where: { PathValidator.isPath(canonical, under: $0) }) { continue }
                                // A symlink in an ancestor of a rule root must not
                                // turn a known cache location into a project scan.
                                guard ScanConfiguration.canonical(root.resolvingSymlinksInPath().path) == canonical else {
                                    continuation.yield(.error(path: root.path, message: "symlink root"))
                                    continue
                                }
                                do {
                                    let values = try root.resourceValues(forKeys: [.isDirectoryKey])
                                    guard values.isDirectory == true, fm.isReadableFile(atPath: root.path) else {
                                        continuation.yield(.error(path: root.path, message: "unreadable directory"))
                                        continue
                                    }
                                } catch {
                                    let code = (error as NSError).code
                                    if code != NSFileReadNoSuchFileError && code != NSFileNoSuchFileError {
                                        continuation.yield(.error(path: root.path, message: "unreadable directory"))
                                    }
                                    continue
                                }
                                await Self.scanRoot(root, rule: rule, cutoff: cutoff,
                                                    excludedPaths: excluded,
                                                    scanned: &localScanned, totalBytes: &localBytes,
                                                    continuation: continuation, pauseController: pauseController)
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

    /// Directory walk; called from a rule's scan task. `async` solely so a
    /// pause can `await` a suspension (`ScanPauseController`) instead of
    /// blocking the thread — the enumerator loop itself is still
    /// synchronous `FileManager.DirectoryEnumerator` iteration. Writes only to
    /// the caller's local counters, so concurrent rules never share mutable state.
    private static func scanRoot(_ root: URL, rule: ScanRule, cutoff: Date,
                                 excludedPaths: [String],
                                 scanned: inout Int, totalBytes: inout Int64,
                                 continuation: AsyncStream<ScanEvent>.Continuation,
                                 pauseController: ScanPauseController? = nil) async {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants],
            errorHandler: { url, _ in
                continuation.yield(.error(path: url.path, message: "unreadable directory"))
                return true
            }
        ) else { return }

        // Manual nextObject() rather than `for case ... in enumerator`: the
        // Sequence/IteratorProtocol conformance's makeIterator() is marked
        // unavailable from async contexts, but the plain Objective-C-style
        // nextObject() method isn't — this is the shape that lets the loop
        // `await` a pause between files without giving up the enumerator's
        // own traversal state (skipDescendants() below still needs it live).
        while let url = enumerator.nextObject() as? URL {
            await pauseController?.waitWhilePaused()
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
            // Symlinks are never traversed by the scanner: the target may sit
            // outside `home`, and a cycle would stall the walk. Following them
            // safely would need a resolved-target allowlist check plus a
            // visited-inode loop guard — deliberately out of scope.
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            scanned += 1
            if scanned % 512 == 0 {
                continuation.yield(.progress(scanned: scanned, currentPath: url.path))
            }
            guard values.isRegularFile == true else { continue }
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
