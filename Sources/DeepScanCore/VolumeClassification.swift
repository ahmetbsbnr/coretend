// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// VolumeResolver — classifies which volume a path lives on using Foundation's
// volume resource values (no elevated privileges, no mounting). Results are
// cached per volume root so a full scan does one lookup per mounted volume,
// not one per file.
//
// This replaces the engine's earlier "everything is .dataVolume" placeholder.

import Foundation

public struct VolumeInfo: Sendable, Hashable {
    public let volumeRoot: String
    public let uuid: String?
    public let name: String?
    public let volumeClass: VolumeClass
    public let isReadOnly: Bool
    public let isBrowsable: Bool
}

public final class VolumeResolver: @unchecked Sendable {
    private let lock = NSLock()
    private var byMountPoint: [String: VolumeInfo] = [:]
    // Cheap path -> mount-point memo so repeated deep paths don't re-hit URL APIs.
    private var mountPointOf: [String: String] = [:]

    public init() {}

    private static let volumeKeys: Set<URLResourceKey> = [
        .volumeURLKey, .volumeUUIDStringKey, .volumeNameKey,
        .volumeIsInternalKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
        .volumeIsLocalKey, .volumeIsReadOnlyKey, .volumeIsBrowsableKey,
        .volumeIsRootFileSystemKey,
    ]

    /// Classify `path`. Falls back to `.dataVolume` only when the OS gives us
    /// nothing to go on (never fabricates a UUID / name).
    public func classify(path: String) -> VolumeInfo {
        // 1. Determine the mount point. Resolve against the nearest *existing*
        //    ancestor so a not-yet-created path still classifies correctly.
        let anchor = Self.nearestExistingAncestor(of: path)
        let mount: String
        if let cached = withLock({ mountPointOf[anchor] }) {
            mount = cached
        } else {
            let m = (try? URL(fileURLWithPath: anchor).resourceValues(forKeys: [.volumeURLKey]))?
                .volume?.standardizedFileURL.path
                ?? Self.fallbackMountPoint(for: anchor)
            withLock { mountPointOf[anchor] = m }
            mount = m
        }

        // 2. One classification per mount point.
        if let cached = withLock({ byMountPoint[mount] }) { return cached }
        let info = Self.describe(mountPoint: mount)
        withLock { byMountPoint[mount] = info }
        return info
    }

    /// Convenience for the engine, which only needs the enum.
    public func volumeClass(forPath path: String) -> VolumeClass { classify(path: path).volumeClass }

    // MARK: - internals

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }; return body()
    }

    private static func describe(mountPoint: String) -> VolumeInfo {
        let url = URL(fileURLWithPath: mountPoint)
        let v = try? url.resourceValues(forKeys: volumeKeys)

        let isInternal = v?.volumeIsInternal ?? false
        let isRemovable = (v?.volumeIsRemovable ?? false) || (v?.volumeIsEjectable ?? false)
        let isLocal = v?.volumeIsLocal ?? true
        let isRoot = v?.volumeIsRootFileSystem ?? (mountPoint == "/")
        let isReadOnly = v?.volumeIsReadOnly ?? false
        let isBrowsable = v?.volumeIsBrowsable ?? true

        let cls: VolumeClass
        if !isLocal {
            cls = .networkVolume
        } else if mountPoint.hasPrefix("/Volumes/") && isReadOnly && mountPoint.contains(" ") == false
                    && Self.looksLikeDiskImage(mountPoint) {
            cls = .externalVolume       // disk images surface as read-only /Volumes mounts
        } else if isRemovable {
            cls = .externalVolume
        } else if isRoot && isReadOnly {
            cls = .systemVolume         // the sealed system volume ("/")
        } else if isInternal {
            cls = .dataVolume
        } else if mountPoint.hasPrefix("/Volumes/") {
            cls = .externalVolume
        } else {
            cls = .dataVolume
        }

        return VolumeInfo(
            volumeRoot: mountPoint,
            uuid: v?.volumeUUIDString,
            name: v?.volumeName,
            volumeClass: cls,
            isReadOnly: isReadOnly,
            isBrowsable: isBrowsable)
    }

    private static func looksLikeDiskImage(_ mountPoint: String) -> Bool {
        // Best-effort: a diskimages-helper mount. We cannot query the backing
        // store without DiskArbitration, so treat any read-only /Volumes mount
        // that is not removable media conservatively as external.
        true
    }

    static func nearestExistingAncestor(of path: String) -> String {
        var p = URL(fileURLWithPath: path).standardizedFileURL.path
        let fm = FileManager.default
        while p != "/" && !fm.fileExists(atPath: p) {
            p = (p as NSString).deletingLastPathComponent
        }
        return p
    }

    /// If `.volumeURLKey` is unavailable, walk up until the device number
    /// changes — that boundary is the mount point.
    static func fallbackMountPoint(for path: String) -> String {
        var current = URL(fileURLWithPath: path).standardizedFileURL
        var lastDev = deviceID(of: current.path)
        while current.path != "/" {
            let parent = current.deletingLastPathComponent()
            if deviceID(of: parent.path) != lastDev { return current.path }
            lastDev = deviceID(of: parent.path)
            current = parent
        }
        return "/"
    }

    private static func deviceID(of path: String) -> UInt64 {
        var st = stat()
        return path.withCString { lstat($0, &st) == 0 ? UInt64(bitPattern: Int64(st.st_dev)) : 0 }
    }
}
