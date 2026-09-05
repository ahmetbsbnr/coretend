// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Darwin

public enum StorageAvailability: String, Sendable, Equatable {
    case available, absent, unavailable, unsupported, cancelled
}

/// Logical/allocated measurements for precisely the same known file set.
/// This is occupied storage, never reclaimable space. No mutation API.
public struct StorageMeasurement: Sendable, Equatable {
    public let path: URL
    public let availability: StorageAvailability
    public let logicalBytes: Int64?
    public let allocatedBytes: Int64?
    public let fileCount: Int

    public init(path: URL, availability: StorageAvailability, logicalBytes: Int64? = nil,
                allocatedBytes: Int64? = nil, fileCount: Int = 0) {
        self.path = path
        self.availability = availability
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
        self.fileCount = fileCount
    }
}

/// Native, metadata-only reads. No file contents, process launches, shell,
/// Docker/Simulator APIs, or filesystem mutation. Work runs off MainActor.
public enum DeveloperStorageInspector {
    public static let simulatorPath = "Library/Developer/CoreSimulator"
    public static let dockerDiskPaths = [
        "Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
        "Library/Containers/com.docker.docker/Data/vms/0/data/Docker.qcow2",
        "Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/Docker.qcow2",
    ]

    public struct DockerInspection: Sendable {
        public let desktop: StorageAvailability
        public let container: StorageAvailability
        public let disks: [StorageMeasurement]
        /// An installation/container with no supported disks is an unknown
        /// layout, not zero usage. Absence at known app paths is not proof
        /// that Docker is uninstalled everywhere.
        public var availability: StorageAvailability {
            if disks.contains(where: { $0.availability == .available }) { return .available }
            if disks.contains(where: { $0.availability == .unavailable })
                || desktop == .unavailable || container == .unavailable { return .unavailable }
            if desktop == .absent && container == .absent { return .absent }
            return .unsupported
        }
    }

    public static func presence(_ path: URL, directory: Bool = true) -> StorageAvailability {
        let normalized = canonical(path.standardizedFileURL.path)
        guard normalized == canonical(path.resolvingSymlinksInPath().path) else { return .unsupported }
        var info = stat()
        guard lstat(path.path, &info) == 0 else {
            return errno == ENOENT ? .absent : .unavailable
        }
        let kind = info.st_mode & S_IFMT
        guard kind == (directory ? S_IFDIR : S_IFREG) else { return .unsupported }
        guard FileManager.default.isReadableFile(atPath: path.path),
              !directory || FileManager.default.isExecutableFile(atPath: path.path) else { return .unavailable }
        return .available
    }

    public static func file(_ path: URL) -> StorageMeasurement {
        let state = presence(path, directory: false)
        guard state == .available else { return StorageMeasurement(path: path, availability: state) }
        guard let values = try? path.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey]),
              let size = values.fileSize else { return StorageMeasurement(path: path, availability: .unavailable) }
        return StorageMeasurement(path: path, availability: .available, logicalBytes: Int64(size),
                                  allocatedBytes: values.totalFileAllocatedSize.map(Int64.init), fileCount: 1)
    }

    public static func directory(_ path: URL) -> StorageMeasurement {
        let state = presence(path)
        guard state == .available else { return StorageMeasurement(path: path, availability: state) }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
                                        .fileSizeKey, .totalFileAllocatedSizeKey, .fileResourceIdentifierKey]
        var failed = false
        guard let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: Array(keys),
            errorHandler: { _, _ in failed = true; return true }) else {
            return StorageMeasurement(path: path, availability: .unavailable)
        }
        var logical: Int64 = 0
        var allocated: Int64? = 0
        var count = 0
        // Avoid counting hard links twice within this inspection. Cross-file
        // APFS clone attribution is intentionally not inferred.
        var identifiers: Set<AnyHashable> = []
        while let url = enumerator.nextObject() as? URL {
            guard !Task.isCancelled else { return StorageMeasurement(path: path, availability: .cancelled) }
            guard let values = try? url.resourceValues(forKeys: keys) else { failed = true; continue }
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            if values.isDirectory == true {
                if !FileManager.default.isReadableFile(atPath: url.path) {
                    failed = true
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true else { continue }
            guard let size = values.fileSize else { failed = true; continue }
            if let identifier = values.fileResourceIdentifier as? AnyHashable,
               !identifiers.insert(identifier).inserted { continue }
            logical += Int64(size)
            count += 1
            if let total = allocated, let size = values.totalFileAllocatedSize {
                allocated = total + Int64(size)
            } else { allocated = nil }
        }
        // Never label a partial measurement as a total. Failure is explicit.
        guard !failed else { return StorageMeasurement(path: path, availability: .unavailable) }
        return StorageMeasurement(path: path, availability: .available, logicalBytes: logical,
                                  allocatedBytes: allocated, fileCount: count)
    }

    public static func simulators(home: URL) -> StorageMeasurement {
        directory(home.appendingPathComponent(simulatorPath))
    }

    public static func docker(home: URL, applicationRoots: [URL]) -> DockerInspection {
        let apps = applicationRoots.map { presence($0.appendingPathComponent("Docker.app")) }
        let desktop: StorageAvailability = apps.contains(.available) ? .available
            : apps.contains(.unavailable) ? .unavailable : apps.contains(.unsupported) ? .unsupported : .absent
        return DockerInspection(desktop: desktop,
            container: presence(home.appendingPathComponent("Library/Containers/com.docker.docker")),
            disks: dockerDiskPaths.map { file(home.appendingPathComponent($0)) })
    }

    private static func canonical(_ path: String) -> String {
        path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
    }
}
