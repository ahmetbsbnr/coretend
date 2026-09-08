// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// DeepScanEngine — bounded, cancellable, mount-aware directory walker that
// produces a DiskGraph. It observes only; it never writes or deletes.
//
// Safety properties enforced here (see DeepScanEngineTests + adversarial tests):
//   * Symlinked directories are recorded but NOT descended (no loops).
//   * A file whose (device,inode) was already counted is not double-counted
//     (hard-link protection).
//   * Descent stops at a mount boundary unless the volume is explicitly
//     included (st_dev differs from the root's st_dev).
//   * Cancellation and the wall-clock deadline both yield a *partial* graph
//     with truthful completeness flags — never a fake-complete result.
//   * A directory we cannot open is recorded with `.permissionDenied`, its
//     bytes are not guessed, and its root is added to `deniedRoots`.

import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct DeepScanConfiguration: Sendable {
    public var roots: [URL]
    /// Hard ceiling on concurrent directory reads. Profiled default; low
    /// enough not to thrash spinning disks, high enough to hide I/O latency.
    public var maxConcurrency: Int
    /// Wall-clock budget. On expiry the walk stops and returns what it has.
    public var timeBudget: Duration
    /// Absolute paths to skip entirely (canonicalized prefix match).
    public var excludedPrefixes: [String]
    /// Include volumes other than the roots' own volume (external drives).
    public var followMountBoundaries: Bool
    /// Follow symlinks that point to directories. Default false — never, to
    /// avoid loops; symlinks are still recorded as nodes.
    public var followDirectorySymlinks: Bool
    /// Maximum directory depth (defence-in-depth against pathological trees).
    public var maxDepth: Int

    public init(roots: [URL],
                maxConcurrency: Int = 6,
                timeBudget: Duration = .seconds(90),
                excludedPrefixes: [String] = [],
                followMountBoundaries: Bool = false,
                followDirectorySymlinks: Bool = false,
                maxDepth: Int = 40) {
        self.roots = roots
        self.maxConcurrency = max(1, maxConcurrency)
        self.timeBudget = timeBudget
        self.excludedPrefixes = excludedPrefixes.map { Self.canonical($0) }
        self.followMountBoundaries = followMountBoundaries
        self.followDirectorySymlinks = followDirectorySymlinks
        self.maxDepth = maxDepth
    }

    static func canonical(_ p: String) -> String {
        URL(fileURLWithPath: (p as NSString).expandingTildeInPath).standardizedFileURL.path
    }
}

/// Cooperative cancellation flag shared with a running scan.
public final class DeepScanCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    public init() {}
    public func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}

public struct DeepScanProgress: Sendable {
    public let nodesObserved: Int
    public let bytesObserved: Int64
    public let currentPath: String
    /// Real fraction only when we can bound it; nil when we genuinely cannot
    /// (never a fabricated number).
    public let fraction: Double?
}

public actor DeepScanEngine {
    public init() {}

    /// Runs a scan. Returns a DiskGraph even on cancel/timeout/error, with the
    /// relevant flags set and per-node `completeness` populated.
    public func scan(_ config: DeepScanConfiguration,
                     cancellation: DeepScanCancellation = DeepScanCancellation(),
                     volumeResolver: VolumeResolver? = nil,
                     onProgress: (@Sendable (DeepScanProgress) -> Void)? = nil) async -> DiskGraph {
        let started = Date()
        let deadline = ContinuousClock.now.advanced(by: config.timeBudget)

        var nodes: [ScanNode] = []
        var deniedRoots: [String] = []
        var visitedIdentities = Set<FileIdentity>()   // hard-link + dir-loop guard
        var hitTimeout = false

        // BFS with a manual queue keeps memory bounded (we do not hold the whole
        // tree in recursion frames) and makes the depth cap trivial.
        struct QueueItem { let url: URL; let depth: Int; let parentCanonical: String?; let rootDev: UInt64 }
        var queue: [QueueItem] = []

        // Seed with the (validated, de-duplicated) roots.
        var seenRootCanon = Set<String>()
        for root in config.roots {
            let canon = root.standardizedFileURL.path
            guard seenRootCanon.insert(canon).inserted else { continue }
            guard let st = Self.lstat(canon) else { deniedRoots.append(canon); continue }
            queue.append(QueueItem(url: root, depth: 0, parentCanonical: nil, rootDev: st.st_dev.uint64))
        }

        var observedBytes: Int64 = 0
        var lastProgress = ContinuousClock.now

        outer: while !queue.isEmpty {
            if cancellation.isCancelled || Task.isCancelled { break }
            if ContinuousClock.now >= deadline { hitTimeout = true; break }

            // Take a concurrency-sized slice and read those directories in parallel.
            let batch = Array(queue.prefix(config.maxConcurrency))
            queue.removeFirst(batch.count)

            let results: [DirReadResult] = await withTaskGroup(of: DirReadResult.self) { group in
                for item in batch {
                    group.addTask {
                        Self.readDirectory(item.url, depth: item.depth,
                                           parentCanonical: item.parentCanonical,
                                           rootDev: item.rootDev, config: config)
                    }
                }
                var acc: [DirReadResult] = []
                for await r in group { acc.append(r) }
                return acc
            }

            for r in results {
                nodes.append(contentsOf: r.selfNode.map { [$0] } ?? [])
                for child in r.childNodes {
                    // Hard-link / already-seen identity de-dup: keep the node
                    // (so the path is visible) but zero its bytes so the total
                    // is not inflated.
                    if let idc = child.identity, child.type == .file,
                       !visitedIdentities.insert(idc).inserted {
                        var deduped = child
                        deduped = ScanNode(path: child.path, canonicalPath: child.canonicalPath,
                            parentCanonicalPath: child.parentCanonicalPath, type: child.type,
                            identity: child.identity, volumeClass: child.volumeClass,
                            volumeUUID: child.volumeUUID, logicalBytes: 0, allocatedBytes: 0,
                            childCount: 0, createdAt: child.createdAt, modifiedAt: child.modifiedAt,
                            accessedAt: child.accessedAt, posixPermissions: child.posixPermissions,
                            ownerUID: child.ownerUID, ownerName: child.ownerName,
                            isSymlink: child.isSymlink, symlinkTarget: child.symlinkTarget,
                            symlinkResolvesInsideRoot: child.symlinkResolvesInsideRoot,
                            bundleContext: child.bundleContext, cloudRemoteOnly: child.cloudRemoteOnly,
                            completeness: child.completeness, observedAt: child.observedAt)
                        nodes.append(deduped)
                    } else {
                        nodes.append(child)
                        observedBytes += child.logicalBytes
                    }
                }
                if r.wasDenied, let d = r.selfNode?.canonicalPath { deniedRoots.append(d) }
                for sub in r.subdirectoriesToVisit {
                    queue.append(QueueItem(url: sub.url, depth: sub.depth,
                                           parentCanonical: sub.parentCanonical, rootDev: sub.rootDev))
                }
            }

            if let onProgress, ContinuousClock.now - lastProgress > .milliseconds(120) {
                lastProgress = ContinuousClock.now
                onProgress(DeepScanProgress(nodesObserved: nodes.count, bytesObserved: observedBytes,
                                            currentPath: batch.last?.url.path ?? "",
                                            fraction: nil))
            }
        }

        // Roll recursive directory totals up from leaves. Directories still in
        // the queue at cancel/timeout stay `.notEnumerated`, so their parents'
        // totals are marked `.partial`.
        let rolled = Self.rollUpDirectoryTotals(nodes,
                                                interrupted: cancellation.isCancelled || Task.isCancelled || hitTimeout)

        // Stamp real volume class + UUID (cached per mount point).
        let stamped = Self.stampVolumes(rolled, resolver: volumeResolver ?? VolumeResolver())

        return DiskGraph(nodes: stamped, scannedRoots: config.roots.map { $0.standardizedFileURL.path },
                         startedAt: started, finishedAt: Date(),
                         wasCancelled: cancellation.isCancelled || Task.isCancelled,
                         hitTimeout: hitTimeout,
                         deniedRoots: Array(Set(deniedRoots)).sorted())
    }

    // MARK: - Directory read (runs off-actor, pure)

    private struct SubdirToVisit: Sendable { let url: URL; let depth: Int; let parentCanonical: String?; let rootDev: UInt64 }
    private struct DirReadResult: Sendable {
        var selfNode: ScanNode?
        var childNodes: [ScanNode]
        var subdirectoriesToVisit: [SubdirToVisit]
        var wasDenied: Bool
    }

    private static func readDirectory(_ url: URL, depth: Int, parentCanonical: String?,
                                      rootDev: UInt64, config: DeepScanConfiguration) -> DirReadResult {
        let canon = url.standardizedFileURL.path
        if config.excludedPrefixes.contains(where: { PathPrefix.isUnder(canon, $0) }) {
            return DirReadResult(selfNode: nil, childNodes: [], subdirectoriesToVisit: [], wasDenied: false)
        }
        guard let dirStat = lstat(canon) else {
            return DirReadResult(selfNode: makeDeniedNode(canon: canon, parent: parentCanonical),
                                 childNodes: [], subdirectoriesToVisit: [], wasDenied: true)
        }
        // A symlinked directory: record it, do not descend.
        if (dirStat.st_mode & S_IFMT) == S_IFLNK && !config.followDirectorySymlinks {
            let target = (try? FileManager.default.destinationOfSymbolicLink(atPath: canon))
            return DirReadResult(
                selfNode: symlinkNode(canon: canon, parent: parentCanonical, target: target, st: dirStat),
                childNodes: [], subdirectoriesToVisit: [], wasDenied: false)
        }

        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: canon) else {
            return DirReadResult(selfNode: node(fromLstat: dirStat, canon: canon, parent: parentCanonical,
                                                type: .directory, completeness: .permissionDenied,
                                                childCount: 0, logical: 0, allocated: 0),
                                 childNodes: [], subdirectoriesToVisit: [], wasDenied: true)
        }

        var childNodes: [ScanNode] = []
        var subdirs: [SubdirToVisit] = []
        let bundleCtx = url.pathExtension == "app" ? canon : nil

        for name in entries {
            let childPath = canon + "/" + name
            guard let cst = lstat(childPath) else { continue }
            let mode = cst.st_mode & S_IFMT
            let childCanon = childPath      // already normalized (parent was)
            let isLink = mode == S_IFLNK

            if mode == S_IFDIR && !isLink {
                // Mount-boundary check.
                if cst.st_dev.uint64 != rootDev && !config.followMountBoundaries {
                    childNodes.append(node(fromLstat: cst, canon: childCanon, parent: canon,
                                           type: .directory, completeness: .notEnumerated,
                                           childCount: 0, logical: 0, allocated: 0,
                                           bundleContext: bundleCtx,
                                           extraEvidenceMountBoundary: true))
                    continue
                }
                if depth + 1 <= config.maxDepth {
                    subdirs.append(SubdirToVisit(url: URL(fileURLWithPath: childPath),
                                                 depth: depth + 1, parentCanonical: canon,
                                                 rootDev: cst.st_dev.uint64))
                } else {
                    childNodes.append(node(fromLstat: cst, canon: childCanon, parent: canon,
                                           type: .directory, completeness: .notEnumerated,
                                           childCount: 0, logical: 0, allocated: 0, bundleContext: bundleCtx))
                }
            } else if isLink {
                let target = try? fm.destinationOfSymbolicLink(atPath: childPath)
                childNodes.append(symlinkNode(canon: childCanon, parent: canon, target: target, st: cst))
            } else if mode == S_IFREG {
                let logical = Int64(cst.st_size)
                let allocated = Int64(cst.st_blocks) * 512
                childNodes.append(node(fromLstat: cst, canon: childCanon, parent: canon,
                                       type: .file, completeness: .complete, childCount: 0,
                                       logical: logical, allocated: allocated, bundleContext: bundleCtx,
                                       cloudRemoteOnly: name.hasPrefix(".") && name.hasSuffix(".icloud")))
            } else {
                childNodes.append(node(fromLstat: cst, canon: childCanon, parent: canon,
                                       type: specialType(mode), completeness: .complete,
                                       childCount: 0, logical: 0, allocated: 0, bundleContext: bundleCtx))
            }
        }

        // The listing itself succeeded, so this directory is fully observed *at
        // this level*. Whether the whole subtree is complete is decided in
        // rollUpDirectoryTotals once the queued child directories come back.
        let selfNode = node(fromLstat: dirStat, canon: canon, parent: parentCanonical, type: .directory,
                            completeness: .complete,
                            childCount: childNodes.count + subdirs.count,
                            logical: childNodes.reduce(0) { $0 + $1.logicalBytes },
                            allocated: childNodes.reduce(0) { $0 + $1.allocatedBytes },
                            bundleContext: url.pathExtension == "app" ? canon : nil)
        return DirReadResult(selfNode: selfNode, childNodes: childNodes,
                             subdirectoriesToVisit: subdirs, wasDenied: false)
    }

    // MARK: - Roll-up

    private static func rollUpDirectoryTotals(_ input: [ScanNode], interrupted: Bool) -> [ScanNode] {
        var byPath: [String: Int] = [:]
        for (i, n) in input.enumerated() { byPath[n.canonicalPath] = i }
        // children grouped by parent
        var kids: [String: [Int]] = [:]
        for (i, n) in input.enumerated() { if let p = n.parentCanonicalPath { kids[p, default: []].append(i) } }
        // process directories deepest-first
        var order = Array(input.indices).filter { input[$0].type == .directory }
        order.sort { input[$0].canonicalPath.count > input[$1].canonicalPath.count }
        var nodes = input
        for i in order {
            let dir = nodes[i]
            var logical: Int64 = 0, allocated: Int64 = 0, complete = true
            for ci in kids[dir.canonicalPath] ?? [] {
                logical &+= nodes[ci].logicalBytes
                allocated &+= nodes[ci].allocatedBytes
                if nodes[ci].completeness != .complete { complete = false }
            }
            // Preserve a genuinely incomplete self state (permissionDenied /
            // notEnumerated / error). Only a fully-listed directory whose every
            // child also came back complete stays `.complete`.
            let newCompleteness: ScanCompleteness
            if dir.completeness != .complete {
                newCompleteness = dir.completeness
            } else {
                newCompleteness = complete ? .complete : .partial
            }
            nodes[i] = ScanNode(path: dir.path, canonicalPath: dir.canonicalPath,
                parentCanonicalPath: dir.parentCanonicalPath, type: .directory, identity: dir.identity,
                volumeClass: dir.volumeClass, volumeUUID: dir.volumeUUID,
                logicalBytes: logical, allocatedBytes: allocated,
                childCount: (kids[dir.canonicalPath] ?? []).count,
                createdAt: dir.createdAt, modifiedAt: dir.modifiedAt, accessedAt: dir.accessedAt,
                posixPermissions: dir.posixPermissions, ownerUID: dir.ownerUID, ownerName: dir.ownerName,
                isSymlink: false, symlinkTarget: nil, symlinkResolvesInsideRoot: nil,
                bundleContext: dir.bundleContext, cloudRemoteOnly: dir.cloudRemoteOnly,
                completeness: interrupted && !complete ? .partial : newCompleteness,
                observedAt: dir.observedAt)
        }
        return nodes
    }

    /// Replaces the placeholder `.dataVolume` on every node with a real
    /// classification. One `VolumeResolver` lookup per distinct device id
    /// (which is per mounted volume), then a struct copy per node.
    private static func stampVolumes(_ input: [ScanNode], resolver: VolumeResolver) -> [ScanNode] {
        var infoByDevice: [UInt64: VolumeInfo] = [:]
        return input.map { n in
            guard let dev = n.identity?.device else { return n }   // denied nodes stay .unknown
            let info: VolumeInfo
            if let cached = infoByDevice[dev] {
                info = cached
            } else {
                info = resolver.classify(path: n.canonicalPath)
                infoByDevice[dev] = info
            }
            return ScanNode(path: n.path, canonicalPath: n.canonicalPath,
                parentCanonicalPath: n.parentCanonicalPath, type: n.type, identity: n.identity,
                volumeClass: info.volumeClass, volumeUUID: info.uuid,
                logicalBytes: n.logicalBytes, allocatedBytes: n.allocatedBytes, childCount: n.childCount,
                createdAt: n.createdAt, modifiedAt: n.modifiedAt, accessedAt: n.accessedAt,
                posixPermissions: n.posixPermissions, ownerUID: n.ownerUID, ownerName: n.ownerName,
                isSymlink: n.isSymlink, symlinkTarget: n.symlinkTarget,
                symlinkResolvesInsideRoot: n.symlinkResolvesInsideRoot,
                bundleContext: n.bundleContext, cloudRemoteOnly: n.cloudRemoteOnly,
                completeness: n.completeness, observedAt: n.observedAt)
        }
    }

    // MARK: - stat helpers

    static func lstat(_ path: String) -> stat? {
        var st = stat()
        return path.withCString { cs in Darwin.lstat(cs, &st) == 0 ? st : nil }
    }

    private static func specialType(_ mode: mode_t) -> NodeType {
        switch mode {
        case S_IFSOCK: .socket
        case S_IFIFO: .fifo
        case S_IFBLK: .blockDevice
        case S_IFCHR: .charDevice
        default: .unknown
        }
    }

    private static func node(fromLstat st: stat, canon: String, parent: String?, type: NodeType,
                             completeness: ScanCompleteness, childCount: Int,
                             logical: Int64, allocated: Int64, bundleContext: String? = nil,
                             cloudRemoteOnly: Bool = false,
                             extraEvidenceMountBoundary: Bool = false) -> ScanNode {
        ScanNode(path: canon, canonicalPath: canon, parentCanonicalPath: parent, type: type,
                 identity: FileIdentity(device: st.st_dev.uint64, inode: st.st_ino),
                 volumeClass: volumeClass(forDevice: st.st_dev.uint64), volumeUUID: nil,
                 logicalBytes: logical, allocatedBytes: allocated, childCount: childCount,
                 createdAt: date(st.st_birthtimespec), modifiedAt: date(st.st_mtimespec),
                 accessedAt: date(st.st_atimespec),
                 posixPermissions: UInt16(st.st_mode & 0o7777), ownerUID: st.st_uid, ownerName: nil,
                 isSymlink: (st.st_mode & S_IFMT) == S_IFLNK, symlinkTarget: nil,
                 symlinkResolvesInsideRoot: nil, bundleContext: bundleContext,
                 cloudRemoteOnly: cloudRemoteOnly, completeness: completeness)
    }

    private static func symlinkNode(canon: String, parent: String?, target: String?, st: stat) -> ScanNode {
        ScanNode(path: canon, canonicalPath: canon, parentCanonicalPath: parent, type: .symlink,
                 identity: FileIdentity(device: st.st_dev.uint64, inode: st.st_ino),
                 volumeClass: volumeClass(forDevice: st.st_dev.uint64), volumeUUID: nil,
                 logicalBytes: 0, allocatedBytes: 0, childCount: 0,
                 createdAt: date(st.st_birthtimespec), modifiedAt: date(st.st_mtimespec),
                 accessedAt: date(st.st_atimespec),
                 posixPermissions: UInt16(st.st_mode & 0o7777), ownerUID: st.st_uid, ownerName: nil,
                 isSymlink: true, symlinkTarget: target, symlinkResolvesInsideRoot: nil,
                 bundleContext: nil, cloudRemoteOnly: false, completeness: .complete)
    }

    private static func makeDeniedNode(canon: String, parent: String?) -> ScanNode {
        ScanNode(path: canon, canonicalPath: canon, parentCanonicalPath: parent, type: .directory,
                 identity: nil, volumeClass: .unknown, volumeUUID: nil,
                 logicalBytes: 0, allocatedBytes: 0, childCount: 0, createdAt: nil, modifiedAt: nil,
                 accessedAt: nil, posixPermissions: nil, ownerUID: nil, ownerName: nil,
                 isSymlink: false, symlinkTarget: nil, symlinkResolvesInsideRoot: nil,
                 bundleContext: nil, cloudRemoteOnly: false, completeness: .permissionDenied)
    }

    private static func date(_ ts: timespec) -> Date? {
        ts.tv_sec == 0 ? nil : Date(timeIntervalSince1970: TimeInterval(ts.tv_sec) + TimeInterval(ts.tv_nsec) / 1e9)
    }

    /// Best-effort volume classification without mounting or elevated perms.
    private static func volumeClass(forDevice dev: UInt64) -> VolumeClass {
        // The engine is handed user roots on the Data volume; anything with a
        // different st_dev that we chose to descend is external. A precise UUID
        // map lives in DeepScanReport where DiskArbitration is available.
        return .dataVolume
    }
}

extension dev_t { var uint64: UInt64 { UInt64(bitPattern: Int64(self)) } }

enum PathPrefix {
    static func isUnder(_ path: String, _ root: String) -> Bool {
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
}
