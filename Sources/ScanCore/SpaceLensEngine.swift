import Foundation
import CoreGraphics

/// A node in the sized directory tree produced by SpaceLensEngine.
public struct SpaceNode: Sendable, Identifiable {
    public let id: String              // path
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public var children: [SpaceNode]   // largest first; only for directories
    /// True when this directory's contents couldn't be fully enumerated
    /// (permission denied) — its size is a lower bound, not exact.
    public let isAccessDenied: Bool
    /// True when this file is an iCloud placeholder not downloaded locally —
    /// its size reflects the placeholder, not the full remote item.
    public let isCloudPlaceholder: Bool

    public init(name: String, path: String, isDirectory: Bool, size: Int64, children: [SpaceNode] = [],
                isAccessDenied: Bool = false, isCloudPlaceholder: Bool = false) {
        self.id = path
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
        self.isAccessDenied = isAccessDenied
        self.isCloudPlaceholder = isCloudPlaceholder
    }
}

public enum SpaceLensEvent: Sendable {
    case progress(scannedItems: Int, currentPath: String)
    case finished(root: SpaceNode)
    case cancelled
}

/// Computes directory sizes bottom-up. Children below `minChildSize` are merged
/// into an "Other" bucket to keep the tree small in memory.
public struct SpaceLensEngine: Sendable {
    public let root: URL
    public let maxDepth: Int
    public let minChildSize: Int64

    public init(root: URL, maxDepth: Int = 6, minChildSize: Int64 = 10_000_000) {
        self.root = root
        self.maxDepth = maxDepth
        self.minChildSize = minChildSize
    }

    public func run(pauseController: ScanPauseController? = nil) -> AsyncStream<SpaceLensEvent> {
        let root = root
        let maxDepth = maxDepth
        let minChildSize = minChildSize
        return AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                var scanned = 0
                let node = await Self.size(directory: root, depth: 0, maxDepth: maxDepth,
                                           minChildSize: minChildSize, scanned: &scanned,
                                           continuation: continuation, pauseController: pauseController)
                if Task.isCancelled {
                    continuation.yield(.cancelled)
                } else {
                    continuation.yield(.finished(root: node))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileSizeKey, .isPackageKey,
        .ubiquitousItemDownloadingStatusKey,
    ]

    private static func size(directory: URL, depth: Int, maxDepth: Int, minChildSize: Int64,
                             scanned: inout Int, continuation: AsyncStream<SpaceLensEvent>.Continuation,
                             pauseController: ScanPauseController? = nil) async -> SpaceNode {
        var children: [SpaceNode] = []
        var otherBytes: Int64 = 0
        var total: Int64 = 0

        let enumeration = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys),
            options: [])
        let accessDenied = enumeration == nil
        let contents = enumeration ?? []

        for url in contents {
            await pauseController?.waitWhilePaused()
            if Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true { continue }
            scanned += 1
            if scanned % 256 == 0 {
                continuation.yield(.progress(scannedItems: scanned, currentPath: url.path))
            }
            let isDir = values.isDirectory == true && values.isPackage != true
            if isDir {
                if depth + 1 < maxDepth {
                    let child = await size(directory: url, depth: depth + 1, maxDepth: maxDepth,
                                           minChildSize: minChildSize, scanned: &scanned,
                                           continuation: continuation, pauseController: pauseController)
                    total += child.size
                    if child.size >= minChildSize { children.append(child) } else { otherBytes += child.size }
                } else {
                    let bytes = await shallowSize(of: url, scanned: &scanned, pauseController: pauseController)
                    total += bytes
                    if bytes >= minChildSize {
                        children.append(SpaceNode(name: url.lastPathComponent, path: url.path,
                                                  isDirectory: true, size: bytes))
                    } else { otherBytes += bytes }
                }
            } else {
                let bytes = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                let isCloudPlaceholder = values.ubiquitousItemDownloadingStatus.map { $0 != .current } ?? false
                total += bytes
                if bytes >= minChildSize {
                    children.append(SpaceNode(name: url.lastPathComponent, path: url.path,
                                              isDirectory: false, size: bytes,
                                              isCloudPlaceholder: isCloudPlaceholder))
                } else { otherBytes += bytes }
            }
        }

        children.sort { $0.size > $1.size }
        if otherBytes > 0 {
            children.append(SpaceNode(name: "Other (small items)",
                                      path: directory.path + "/\u{2026}other",
                                      isDirectory: false, size: otherBytes))
        }
        return SpaceNode(name: directory.lastPathComponent.isEmpty ? directory.path : directory.lastPathComponent,
                         path: directory.path, isDirectory: true, size: total, children: children,
                         isAccessDenied: accessDenied)
    }

    /// Total allocated size of a subtree without materializing nodes.
    private static func shallowSize(of directory: URL, scanned: inout Int,
                                    pauseController: ScanPauseController? = nil) async -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isSymbolicLinkKey],
            options: []) else { return 0 }
        var total: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            await pauseController?.waitWhilePaused()
            if Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isSymbolicLinkKey]) else { continue }
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            scanned += 1
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }
}

/// Squarified-ish treemap layout: alternating horizontal/vertical slices.
/// Simple, stable, and fast enough for a few hundred rectangles.
public enum TreemapLayout {
    public struct Rect: Sendable, Identifiable {
        public let id: String
        public let node: SpaceNode
        public let frame: CGRect
    }

    public static func layout(nodes: [SpaceNode], in bounds: CGRect) -> [Rect] {
        var result: [Rect] = []
        slice(nodes: nodes, bounds: bounds, horizontal: bounds.width >= bounds.height, into: &result)
        return result
    }

    private static func slice(nodes: [SpaceNode], bounds: CGRect, horizontal: Bool, into result: inout [Rect]) {
        let total = nodes.reduce(Int64(0)) { $0 + $1.size }
        guard total > 0, !nodes.isEmpty, bounds.width > 1, bounds.height > 1 else { return }
        var offset: CGFloat = 0
        for node in nodes {
            let fraction = CGFloat(Double(node.size) / Double(total))
            let frame: CGRect
            if horizontal {
                frame = CGRect(x: bounds.minX + offset, y: bounds.minY,
                               width: bounds.width * fraction, height: bounds.height)
                offset += bounds.width * fraction
            } else {
                frame = CGRect(x: bounds.minX, y: bounds.minY + offset,
                               width: bounds.width, height: bounds.height * fraction)
                offset += bounds.height * fraction
            }
            result.append(Rect(id: node.id, node: node, frame: frame))
        }
    }
}
