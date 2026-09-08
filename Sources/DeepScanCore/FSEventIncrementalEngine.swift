// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// FSEventIncrementalEngine — keeps a persisted DeepScanIndex roughly in sync
// with the filesystem after the initial full scan, WITHOUT re-walking
// everything.
//
//   full scan  ->  DeepScanIndex (scanVersion N)
//   FSEvents   ->  coalesce  ->  scoped rescan of changed dirs  ->  index.apply
//
// Safety / honesty rules:
//   * If FSEvents reports dropped events (user or kernel) or "must scan
//     subdirs", the affected scope is marked STALE and a scoped/full rescan is
//     scheduled. The index is never presented as authoritative while STALE.
//   * A root that disappears or is replaced -> health ERROR, full rebuild.
//   * If the SQLite file is unreadable/corrupt, it is discarded and rebuilt.
//
// The pure decision logic (`EventCoalescer`) is unit-tested. The
// `FSEventStream` wiring is thin glue and is exercised by an integration test
// that touches real files; interactive behaviour is HUMAN VERIFICATION.

import Foundation
#if canImport(CoreServices)
import CoreServices
#endif

// MARK: - Index health

public enum IndexHealth: String, Sendable, Codable {
    case fresh        // fully reflects the last completed scan
    case stale        // known-behind: events dropped or coalescing pending
    case partial      // last scan itself was partial (cancel/timeout/denied)
    case rebuilding   // a (re)scan is running now
    case error        // root vanished / index corrupt — do not trust
}

// MARK: - Pure coalescing / decision logic

public struct FSChange: Sendable, Hashable {
    public let path: String
    public let isDir: Bool
    public let created: Bool
    public let removed: Bool
    public let renamed: Bool
    public let mustScanSubdirs: Bool
    public let dropped: Bool           // user or kernel event drop
    public let rootChanged: Bool
    public init(path: String, isDir: Bool = false, created: Bool = false, removed: Bool = false,
                renamed: Bool = false, mustScanSubdirs: Bool = false, dropped: Bool = false,
                rootChanged: Bool = false) {
        self.path = path; self.isDir = isDir; self.created = created; self.removed = removed
        self.renamed = renamed; self.mustScanSubdirs = mustScanSubdirs; self.dropped = dropped
        self.rootChanged = rootChanged
    }
}

public struct CoalescedPlan: Sendable, Equatable {
    /// Directories to re-enumerate (scoped rescan). Canonical, de-duplicated,
    /// with descendants of an already-included dir removed.
    public let rescanRoots: [String]
    /// Paths known to be gone — delete their rows outright.
    public let deletedPaths: [String]
    /// True ⇒ the scoped plan is not trustworthy; do a full rescan.
    public let requiresFullRescan: Bool
    /// Health to publish until the plan is executed.
    public let health: IndexHealth
}

public struct EventCoalescer: Sendable {
    public init() {}

    /// Collapse a batch of raw changes into a minimal rescan plan.
    public func coalesce(_ changes: [FSChange], watchedRoots: [String]) -> CoalescedPlan {
        if changes.contains(where: { $0.rootChanged }) {
            return CoalescedPlan(rescanRoots: watchedRoots, deletedPaths: [],
                                 requiresFullRescan: true, health: .error)
        }
        let dropped = changes.contains { $0.dropped }
        let mustSubdirs = changes.contains { $0.mustScanSubdirs }
        if dropped {
            // We cannot know what we missed — full rescan, publish STALE now.
            return CoalescedPlan(rescanRoots: watchedRoots, deletedPaths: [],
                                 requiresFullRescan: true, health: .stale)
        }

        var dirs = Set<String>()
        var deleted = Set<String>()
        for c in changes {
            let dir = c.isDir ? c.path : (c.path as NSString).deletingLastPathComponent
            dirs.insert(dir)
            if c.mustScanSubdirs { dirs.insert(c.path) }
            if c.removed {
                deleted.insert(c.path)
                // The removed path itself no longer exists, so a scoped rescan
                // *of it* observes nothing and can't prune it. Rescan the
                // PARENT so `pruneUnder(parent, keeping:)` drops the whole gone
                // subtree. (Covers `rm -rf node_modules`, `git checkout`
                // deleting a dir, generated-output dir replacement.)
                dirs.insert((c.path as NSString).deletingLastPathComponent)
            }
            if c.renamed {
                // A rename touches both names; we only get one path per event,
                // so rescan the containing dir (already added) and let the
                // scoped walk reconcile.
            }
        }
        // Drop any dir that is a descendant of another included dir.
        let sorted = dirs.sorted { $0.count < $1.count }
        var minimal: [String] = []
        for d in sorted where !minimal.contains(where: { PathPrefix.isUnder(d, $0) }) {
            minimal.append(d)
        }
        return CoalescedPlan(rescanRoots: minimal.sorted(),
                             deletedPaths: deleted.sorted(),
                             requiresFullRescan: mustSubdirs && minimal.isEmpty,
                             health: minimal.isEmpty && deleted.isEmpty ? .fresh : .stale)
    }
}

// MARK: - Live engine (thin FSEvents glue)

public final class FSEventIncrementalEngine: @unchecked Sendable {
    public private(set) var health: IndexHealth = .rebuilding
    public private(set) var scanVersion: Int = 0

    private let index: DeepScanIndex
    private let roots: [URL]
    private let baseConfig: DeepScanConfiguration
    private let coalescer = EventCoalescer()
    private let queue = DispatchQueue(label: "coretend.deepscan.fsevents")
    private let lock = NSLock()

    private var stream: FSEventStreamRef?
    private var pending: [FSChange] = []
    private var debounceWorkItem: DispatchWorkItem?
    private let debounce: DispatchTimeInterval
    private let onHealthChange: (@Sendable (IndexHealth) -> Void)?

    /// `debounceMillis` batches bursts (editor save storms, `npm install`).
    public init(index: DeepScanIndex, roots: [URL], baseConfig: DeepScanConfiguration,
                debounceMillis: Int = 800,
                onHealthChange: (@Sendable (IndexHealth) -> Void)? = nil) {
        self.index = index
        self.roots = roots
        self.baseConfig = baseConfig
        self.debounce = .milliseconds(debounceMillis)
        self.onHealthChange = onHealthChange
    }

    // MARK: lifecycle

    /// Does the initial full scan, persists it, then starts watching.
    public func start() async {
        setHealth(.rebuilding)
        let graph = await DeepScanEngine().scan(baseConfig, volumeResolver: VolumeResolver())
        try? index.apply(graph)
        bumpVersion()
        setHealth(graph.wasCancelled || graph.hitTimeout || !graph.deniedRoots.isEmpty ? .partial : .fresh)
        startStream()
    }

    public func stop() {
        queue.sync {
            guard let s = stream else { return }
            FSEventStreamStop(s)
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
            stream = nil
        }
    }

    // MARK: event intake (also called directly by tests)

    /// Feed raw changes as if from FSEvents. Public for testing and for callers
    /// that have their own change source.
    public func ingest(_ changes: [FSChange]) {
        lock.lock(); pending.append(contentsOf: changes); lock.unlock()
        scheduleFlush()
    }

    private func scheduleFlush() {
        queue.async { [weak self] in
            guard let self else { return }
            self.debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.flush() }
            self.debounceWorkItem = work
            self.queue.asyncAfter(deadline: .now() + self.debounce, execute: work)
        }
    }

    private func flush() {
        lock.lock(); let batch = pending; pending.removeAll(); lock.unlock()
        guard !batch.isEmpty else { return }
        let plan = coalescer.coalesce(batch, watchedRoots: roots.map { $0.standardizedFileURL.path })
        setHealth(plan.health == .fresh ? .rebuilding : plan.health)

        Task { [weak self] in
            guard let self else { return }
            // Delete rows for vanished paths first (cheap, exact + subtree).
            try? self.index.delete(paths: plan.deletedPaths)

            let scanRoots: [URL] = plan.requiresFullRescan
                ? self.roots
                : plan.rescanRoots.map { URL(fileURLWithPath: $0) }
            guard !scanRoots.isEmpty else {
                self.bumpVersion(); self.setHealth(.fresh); return
            }

            var cfg = self.baseConfig
            cfg.roots = scanRoots
            let graph = await DeepScanEngine().scan(cfg, volumeResolver: VolumeResolver())
            do {
                try self.index.apply(graph)
                // Reconcile deletions inside each rescanned scope.
                let present = Set(graph.nodes.map { $0.canonicalPath })
                for r in scanRoots {
                    try self.index.pruneUnder(root: r.standardizedFileURL.path, keeping: present)
                }
                self.bumpVersion()
                self.setHealth(graph.wasCancelled || graph.hitTimeout ? .partial : .fresh)
            } catch {
                self.setHealth(.error)
            }
        }
    }

    // MARK: version / health

    private func bumpVersion() { lock.lock(); scanVersion += 1; lock.unlock() }
    private func setHealth(_ h: IndexHealth) {
        lock.lock(); health = h; lock.unlock()
        onHealthChange?(h)
    }

    // MARK: FSEventStream glue

    private func startStream() {
        queue.sync {
            let paths = roots.map { $0.standardizedFileURL.path } as CFArray
            var ctx = FSEventStreamContext(version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil, release: nil, copyDescription: nil)
            let flags = UInt32(kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagWatchRoot
                | kFSEventStreamCreateFlagUseCFTypes)
            guard let s = FSEventStreamCreate(kCFAllocatorDefault, Self.callback, &ctx,
                paths, FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.5, flags) else {
                setHealth(.error); return
            }
            FSEventStreamSetDispatchQueue(s, queue)
            if FSEventStreamStart(s) { stream = s } else { setHealth(.error) }
        }
    }

    private static let callback: FSEventStreamCallback = { _, info, count, paths, flagsPtr, _ in
        guard let info else { return }
        let engine = Unmanaged<FSEventIncrementalEngine>.fromOpaque(info).takeUnretainedValue()
        let cfPaths = unsafeBitCast(paths, to: NSArray.self)
        var changes: [FSChange] = []
        for i in 0..<count {
            let path = (cfPaths[i] as? String) ?? ""
            let f = Int(flagsPtr[i])
            changes.append(FSChange(
                path: path,
                isDir: f & kFSEventStreamEventFlagItemIsDir != 0,
                created: f & kFSEventStreamEventFlagItemCreated != 0,
                removed: f & kFSEventStreamEventFlagItemRemoved != 0,
                renamed: f & kFSEventStreamEventFlagItemRenamed != 0,
                mustScanSubdirs: f & kFSEventStreamEventFlagMustScanSubDirs != 0,
                dropped: f & (kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped) != 0,
                rootChanged: f & kFSEventStreamEventFlagRootChanged != 0))
        }
        engine.ingest(changes)
    }

    // MARK: corruption recovery

    /// Opens an index, discarding and recreating the file if it is unreadable.
    public static func openIndexRecovering(path: String) throws -> DeepScanIndex {
        do {
            return try DeepScanIndex(path: path)
        } catch {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: path + "-wal")
            try? FileManager.default.removeItem(atPath: path + "-shm")
            return try DeepScanIndex(path: path)
        }
    }
}
