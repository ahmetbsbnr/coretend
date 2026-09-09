// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// DiskGraph — the value model produced by DeepScanEngine.
//
// A ScanNode is one observed filesystem object. Nodes form a parent/child
// graph keyed by canonical path. Nothing here deletes; the engine only
// *observes*. Sizes carry truthful labels (logical vs allocated) because
// APFS clones / sparse files / compression make "reclaimable" an estimate,
// never an exact figure.

import Foundation

/// Which volume a node lives on, and whether we could read it fully.
public enum VolumeClass: String, Sendable, Codable {
    case dataVolume          // the writable user Data volume
    case systemVolume        // read-only system volume (analysis only)
    case externalVolume      // removable / secondary — opt-in
    case networkVolume       // SMB/AFP/NFS — labelled, never auto-acted-on
    case unknown
}

/// How complete our observation of a node (and its subtree) is.
public enum ScanCompleteness: String, Sendable, Codable {
    case complete            // fully enumerated
    case partial             // stopped early (timeout / cancel / budget)
    case permissionDenied    // TCC / POSIX perms blocked us
    case notEnumerated       // discovered but not descended into
    case error               // I/O error mid-read
}

public enum NodeType: String, Sendable, Codable {
    case file, directory, symlink, package, socket, fifo, blockDevice, charDevice, unknown
}

/// A stable identity for a filesystem object on a given volume.
/// (dev, ino) survives renames within a volume and lets us de-duplicate
/// hard links so a linked file is never counted twice.
public struct FileIdentity: Sendable, Codable, Hashable {
    public let device: UInt64
    public let inode: UInt64
    public init(device: UInt64, inode: UInt64) {
        self.device = device
        self.inode = inode
    }
}

/// One observed filesystem object.
public struct ScanNode: Sendable, Codable, Identifiable {
    public var id: String { canonicalPath }

    public let path: String              // path as discovered
    public let canonicalPath: String     // symlinks resolved, "." / ".." removed
    public let parentCanonicalPath: String?
    public let type: NodeType
    public let identity: FileIdentity?
    public let volumeClass: VolumeClass
    public let volumeUUID: String?

    /// Sum of file sizes in bytes (st_size). For a directory this is the
    /// recursive logical total of complete children.
    public let logicalBytes: Int64
    /// Sum of on-disk allocation (st_blocks * 512). Can be smaller than
    /// logical (compression / sparse) or share blocks with clones.
    public let allocatedBytes: Int64
    /// Direct children count (directories only).
    public let childCount: Int

    public let createdAt: Date?
    public let modifiedAt: Date?
    public let accessedAt: Date?

    public let posixPermissions: UInt16?
    public let ownerUID: UInt32?
    public let ownerName: String?

    public let isSymlink: Bool
    public let symlinkTarget: String?
    public let symlinkResolvesInsideRoot: Bool?

    /// Whether this node sits inside an application bundle (`.app`), and if so
    /// which one. Used to avoid treating bundle internals as loose files.
    public let bundleContext: String?

    /// Whether this node (or an ancestor) is an iCloud / CloudStorage item and
    /// only a stub is present locally.
    public let cloudRemoteOnly: Bool

    public let completeness: ScanCompleteness
    public let observedAt: Date

    public init(path: String, canonicalPath: String, parentCanonicalPath: String?,
                type: NodeType, identity: FileIdentity?, volumeClass: VolumeClass,
                volumeUUID: String?, logicalBytes: Int64, allocatedBytes: Int64,
                childCount: Int, createdAt: Date?, modifiedAt: Date?, accessedAt: Date?,
                posixPermissions: UInt16?, ownerUID: UInt32?, ownerName: String?,
                isSymlink: Bool, symlinkTarget: String?, symlinkResolvesInsideRoot: Bool?,
                bundleContext: String?, cloudRemoteOnly: Bool,
                completeness: ScanCompleteness, observedAt: Date = Date()) {
        self.path = path
        self.canonicalPath = canonicalPath
        self.parentCanonicalPath = parentCanonicalPath
        self.type = type
        self.identity = identity
        self.volumeClass = volumeClass
        self.volumeUUID = volumeUUID
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
        self.childCount = childCount
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.accessedAt = accessedAt
        self.posixPermissions = posixPermissions
        self.ownerUID = ownerUID
        self.ownerName = ownerName
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
        self.symlinkResolvesInsideRoot = symlinkResolvesInsideRoot
        self.bundleContext = bundleContext
        self.cloudRemoteOnly = cloudRemoteOnly
        self.completeness = completeness
        self.observedAt = observedAt
    }
}

/// Immutable snapshot the detectors run against. Backed by an ordered node
/// list plus lookup indexes; small enough to pass by value between actors.
public struct DiskGraph: Sendable {
    public let nodes: [ScanNode]
    public let byCanonicalPath: [String: Int]        // canonicalPath -> index
    public let childrenOf: [String: [Int]]           // parent canonicalPath -> child indexes
    public let scannedRoots: [String]
    public let startedAt: Date
    public let finishedAt: Date
    public let wasCancelled: Bool
    public let hitTimeout: Bool
    /// Roots we could not read at all (reported to the user, never silently dropped).
    public let deniedRoots: [String]

    public init(nodes: [ScanNode], scannedRoots: [String], startedAt: Date,
                finishedAt: Date, wasCancelled: Bool, hitTimeout: Bool, deniedRoots: [String]) {
        self.nodes = nodes
        self.scannedRoots = scannedRoots
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.wasCancelled = wasCancelled
        self.hitTimeout = hitTimeout
        self.deniedRoots = deniedRoots
        var byPath: [String: Int] = [:]
        var children: [String: [Int]] = [:]
        byPath.reserveCapacity(nodes.count)
        for (i, n) in nodes.enumerated() {
            byPath[n.canonicalPath] = i
            if let p = n.parentCanonicalPath { children[p, default: []].append(i) }
        }
        self.byCanonicalPath = byPath
        self.childrenOf = children
    }

    public func node(at canonicalPath: String) -> ScanNode? {
        byCanonicalPath[canonicalPath].map { nodes[$0] }
    }

    public func children(of canonicalPath: String) -> [ScanNode] {
        (childrenOf[canonicalPath] ?? []).map { nodes[$0] }
    }

    /// Depth-first descendants (excluding the node itself). Cycle-safe: the
    /// engine already broke symlink loops, but we still guard on visited paths.
    public func descendants(of canonicalPath: String) -> [ScanNode] {
        var out: [ScanNode] = []
        var stack = childrenOf[canonicalPath] ?? []
        var seen = Set<String>()
        while let i = stack.popLast() {
            let n = nodes[i]
            if !seen.insert(n.canonicalPath).inserted { continue }
            out.append(n)
            if let more = childrenOf[n.canonicalPath] { stack.append(contentsOf: more) }
        }
        return out
    }

    /// True when every node under `canonicalPath` was fully read — a
    /// precondition for any CONFIRMED-confidence candidate.
    public func subtreeFullyObserved(_ canonicalPath: String) -> Bool {
        guard let root = node(at: canonicalPath), root.completeness == .complete else { return false }
        return descendants(of: canonicalPath).allSatisfy { $0.completeness == .complete }
    }
}
