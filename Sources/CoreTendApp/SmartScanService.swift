// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

// MARK: - Domain vocabulary

/// The read-only analysis surfaces Smart Scan coordinates. It never adds a
/// new scanner — each maps onto an engine CoreTend already ships.
public enum SmartScanModuleID: String, CaseIterable, Sendable, Comparable {
    case storage        // Cleanup rules + Leftovers (disk-heavy)
    case developer      // developer caches (disk-heavy)
    case duplicates     // DuplicateEngine (disk-heavy)
    case privacy        // browser cache detection (disk-heavy)
    case applications   // inventory + update source (cheap metadata)
    case integrity      // provenance / signature / launch items (cheap metadata)

    /// Disk-heavy modules run under a bounded concurrency cap; cheap
    /// metadata modules may all run at once.
    public var isDiskHeavy: Bool {
        switch self {
        case .storage, .developer, .duplicates, .privacy: return true
        case .applications, .integrity: return false
        }
    }

    public static func < (a: SmartScanModuleID, b: SmartScanModuleID) -> Bool {
        a.rawValue < b.rawValue
    }
}

/// The four *kinds* of thing Smart Scan reports. They never collapse into one
/// number and never into a "health score". Bytes only ever describe cleanup;
/// integrity signals are counts, not bytes; app updates and APFS facts are
/// informational counts.
public struct SmartScanTotals: Equatable, Sendable {
    /// Cleanup bytes that are safe to plan automatically.
    public var potentiallyRecoverableBytes: Int64
    /// Cleanup bytes that need an individual human decision.
    public var needsReviewBytes: Int64
    /// Integrity / security observations worth a look. A COUNT, not bytes.
    public var attentionCount: Int
    /// App updates, APFS capacity facts, etc. A COUNT, not bytes.
    public var informationalCount: Int

    public init(potentiallyRecoverableBytes: Int64 = 0, needsReviewBytes: Int64 = 0,
                attentionCount: Int = 0, informationalCount: Int = 0) {
        self.potentiallyRecoverableBytes = potentiallyRecoverableBytes
        self.needsReviewBytes = needsReviewBytes
        self.attentionCount = attentionCount
        self.informationalCount = informationalCount
    }
}

public struct SmartScanModuleResult: Equatable, Sendable {
    public let module: SmartScanModuleID
    /// A short, already-localised sentence for the module row.
    public let headline: String
    public let totals: SmartScanTotals
    /// True when this module's recoverable bytes overlap the Storage module
    /// on disk (e.g. Privacy browser caches also live under ~/Library/Caches,
    /// which Cleanup's `user.caches` rule reads). Used so the GLOBAL
    /// recoverable figure never counts one byte twice.
    public let overlapsStorage: Bool

    public init(module: SmartScanModuleID, headline: String, totals: SmartScanTotals,
                overlapsStorage: Bool = false) {
        self.module = module
        self.headline = headline
        self.totals = totals
        self.overlapsStorage = overlapsStorage
    }
}

public enum SmartScanModuleState: Equatable, Sendable {
    case queued
    case scanning(detail: String)
    case completed(SmartScanModuleResult)
    case unavailable(reason: String)   // permission-limited, engine says nothing to do
    case failed(reason: String)
    case cancelled
}

/// A snapshot of the whole run. Aggregation is deliberately conservative.
public struct SmartScanReport: Equatable, Sendable {
    public var modules: [SmartScanModuleID: SmartScanModuleState]
    /// Sum of the modules' recoverable bytes that could be proven non-
    /// overlapping (Storage itself + every module with `overlapsStorage ==
    /// false`). `isGlobalRecoverableExact` is false whenever an overlapping
    /// module also had recoverable bytes we could not subtract — the UI then
    /// shows category totals separately instead of one headline number.
    public var globalRecoverableBytes: Int64
    public var isGlobalRecoverableExact: Bool
    public var needsReviewBytes: Int64
    public var attentionCount: Int
    public var informationalCount: Int
    public var wasCancelled: Bool

    public init() {
        modules = Dictionary(uniqueKeysWithValues: SmartScanModuleID.allCases.map { ($0, .queued) })
        globalRecoverableBytes = 0
        isGlobalRecoverableExact = true
        needsReviewBytes = 0
        attentionCount = 0
        informationalCount = 0
        wasCancelled = false
    }

    /// Recompute the aggregate buckets from the current module states.
    mutating func recomputeAggregate() {
        var recoverable: Int64 = 0
        var exact = true
        var review: Int64 = 0
        var attention = 0
        var info = 0
        for state in modules.values {
            guard case let .completed(result) = state else { continue }
            review += result.totals.needsReviewBytes
            attention += result.totals.attentionCount
            info += result.totals.informationalCount
            if result.overlapsStorage {
                if result.totals.potentiallyRecoverableBytes > 0 { exact = false }
            } else {
                recoverable += result.totals.potentiallyRecoverableBytes
            }
        }
        globalRecoverableBytes = recoverable
        isGlobalRecoverableExact = exact
        needsReviewBytes = review
        attentionCount = attention
        informationalCount = info
    }
}

// MARK: - Provider protocol (the seam engines / tests plug into)

/// One module's contribution. `progress` is a callback for the "1.8 GB
/// recoverable so far" live line. Implementations MUST honour
/// `Task.isCancelled` and must not perform any destructive work.
public protocol SmartScanProvider: Sendable {
    var module: SmartScanModuleID { get }
    func scan(progress: @Sendable (String) -> Void) async throws -> SmartScanModuleResult
}

public enum SmartScanError: Error, Equatable, Sendable {
    case unavailable(String)
}

// MARK: - Coordinator

/// Coordinates the providers. Owns the run; there is exactly one at a time.
///
/// - Cheap metadata providers run concurrently.
/// - Disk-heavy providers run through a bounded `TaskGroup` (default cap 2).
/// - Cancellation propagates to every provider and yields a `.cancelled`
///   report — a cancelled run NEVER produces a "completed" module and the
///   caller must not write a Timeline snapshot from it.
/// - A provider throwing is isolated: its module becomes `.failed`, the rest
///   still complete.
/// - `start()` while a run is in progress is a no-op (no duplicate scan).
public actor SmartScanCoordinator {
    public private(set) var report = SmartScanReport()
    public private(set) var isRunning = false

    private let providers: [SmartScanProvider]
    private let diskConcurrency: Int
    private var run: Task<SmartScanReport, Never>?

    public init(providers: [SmartScanProvider], diskConcurrency: Int = 2) {
        self.providers = providers
        self.diskConcurrency = max(1, diskConcurrency)
    }

    /// Highest simultaneous disk-heavy provider count observed (test seam).
    public private(set) var peakDiskConcurrency = 0

    @discardableResult
    public func start() -> Task<SmartScanReport, Never> {
        if let run { return run }
        isRunning = true
        report = SmartScanReport()
        // Modules with no provider are simply unavailable.
        let present = Set(providers.map(\.module))
        for m in SmartScanModuleID.allCases where !present.contains(m) {
            report.modules[m] = .unavailable(reason: "not-connected")
        }
        let task = Task<SmartScanReport, Never> { [self] in
            await self.execute()
            return await self.finish()
        }
        run = task
        return task
    }

    public func cancel() {
        run?.cancel()
    }

    private var liveDisk = 0

    private func setState(_ m: SmartScanModuleID, _ s: SmartScanModuleState) {
        report.modules[m] = s
        report.recomputeAggregate()
    }

    /// A progress ping only ever refines the *live* scanning detail. If the
    /// module has already left `.scanning` (completed / failed / cancelled),
    /// a late-arriving ping — e.g. a provider that reports progress on its
    /// last line before returning — must not resurrect it into `.scanning`.
    private func setScanningDetail(_ m: SmartScanModuleID, _ detail: String) {
        guard case .scanning = report.modules[m] else { return }
        report.modules[m] = .scanning(detail: detail)
    }

    private func execute() async {
        let cheap = providers.filter { !$0.module.isDiskHeavy }
        let heavy = providers.filter { $0.module.isDiskHeavy }

        await withTaskGroup(of: Void.self) { group in
            for p in cheap {
                group.addTask { await self.runProvider(p, disk: false) }
            }
            group.addTask { await self.runHeavy(heavy) }
        }
    }

    /// Runs `heavy` with at most `diskConcurrency` in flight at once. A
    /// TaskGroup that never holds more than `cap` child tasks: seed `cap`,
    /// then add one more each time one finishes.
    private func runHeavy(_ heavy: [SmartScanProvider]) async {
        await withTaskGroup(of: Void.self) { group in
            var iterator = heavy.makeIterator()
            var pending = 0
            func addNext() -> Bool {
                guard let p = iterator.next() else { return false }
                pending += 1
                group.addTask { await self.runProvider(p, disk: true) }
                return true
            }
            for _ in 0..<diskConcurrency where addNext() {}
            while pending > 0 {
                await group.next()
                pending -= 1
                _ = addNext()
            }
        }
    }

    private func enterDisk() { liveDisk += 1; peakDiskConcurrency = max(peakDiskConcurrency, liveDisk) }
    private func leaveDisk() { liveDisk -= 1 }

    private func runProvider(_ p: SmartScanProvider, disk: Bool) async {
        if disk { enterDisk() }
        defer { if disk { leaveDisk() } }

        if Task.isCancelled { setState(p.module, .cancelled); return }
        setState(p.module, .scanning(detail: ""))
        do {
            let result = try await p.scan(progress: { detail in
                Task { await self.setScanningDetail(p.module, detail) }
            })
            if Task.isCancelled { setState(p.module, .cancelled) }
            else { setState(p.module, .completed(result)) }
        } catch is CancellationError {
            setState(p.module, .cancelled)
        } catch let SmartScanError.unavailable(reason) {
            setState(p.module, .unavailable(reason: reason))
        } catch {
            setState(p.module, .failed(reason: "engine-error"))
        }
    }

    private func finish() async -> SmartScanReport {
        isRunning = false
        run = nil
        let cancelled = report.modules.values.contains { if case .cancelled = $0 { return true } else { return false } }
        if cancelled {
            // A cancelled run shows a Partial state and must not be treated
            // as a finished scan by anything downstream.
            report.wasCancelled = true
            for (m, s) in report.modules {
                if case .scanning = s { report.modules[m] = .cancelled }
                if case .queued = s { report.modules[m] = .cancelled }
            }
        }
        report.recomputeAggregate()
        return report
    }
}
