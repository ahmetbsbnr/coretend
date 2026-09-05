// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import SystemMetrics

@Suite("Developer read-only inspection")
struct DeveloperStorageInspectorTests {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ path: String, home: URL, bytes: Int = 321) throws -> URL {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 42, count: bytes).write(to: url)
        return url
    }

    private func docker(_ home: URL) -> DeveloperStorageInspector.DockerInspection {
        DeveloperStorageInspector.docker(home: home, applicationRoots: [home.appendingPathComponent("Applications")])
    }

    @Test func dockerAbsentHasNoSize() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let result = docker(home)
        #expect(result.desktop == .absent)
        #expect(result.availability == .absent)
        #expect(result.disks.allSatisfy { $0.logicalBytes == nil && $0.allocatedBytes == nil })
    }

    @Test func dockerDesktopPresentWithNoStorageIsNotZeroUsage() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Applications/Docker.app"), withIntermediateDirectories: true)
        let result = docker(home)
        #expect(result.desktop == .available)
        #expect(result.availability == .unsupported)
        #expect(result.disks.allSatisfy { $0.availability == .absent })
    }

    @Test func dockerNormalFileUsesDirectLogicalAndAllocatedMetadata() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let path = try write(DeveloperStorageInspector.dockerDiskPaths[0], home: home)
        let before = try Data(contentsOf: path)
        let measurement = try #require(docker(home).disks.first)
        #expect(measurement.logicalBytes == 321)
        #expect(measurement.allocatedBytes != nil)
        #expect(measurement.fileCount == 1)
        #expect(try Data(contentsOf: path) == before)
    }

    @Test func dockerSparseLogicalSizeIsNotPhysicalUsage() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try write(DeveloperStorageInspector.dockerDiskPaths[0], home: home, bytes: 4)
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: 100_000_000)
        try handle.close()
        let measurement = try #require(docker(home).disks.first)
        #expect(measurement.logicalBytes == 100_000_000)
        #expect(try #require(measurement.allocatedBytes) < 1_000_000)
        #expect(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize == 100_000_000)
    }

    @Test func dockerInaccessibleIsUnavailableNotAbsent() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let path = try write(DeveloperStorageInspector.dockerDiskPaths[0], home: home)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: path.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path) }
        let result = docker(home)
        #expect(result.availability == .unavailable)
        #expect(result.disks[0].logicalBytes == nil)
    }

    @Test func dockerUnknownLayoutDoesNotSearchOrReadUnknownFiles() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let other = try write("Library/Containers/com.docker.docker/Data/future/private.disk", home: home)
        #expect(docker(home).availability == .unsupported)
        #expect(docker(home).disks.allSatisfy { $0.logicalBytes == nil })
        #expect(try Data(contentsOf: other).count == 321)
    }

    @Test func dockerLegacyQcow2IsMeasured() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        _ = try write(DeveloperStorageInspector.dockerDiskPaths[2], home: home, bytes: 900)
        #expect(docker(home).disks[2].logicalBytes == 900)
        #expect(docker(home).availability == .available)
    }

    @Test func simulatorAbsentAndEmptyAreDistinct() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        #expect(DeveloperStorageInspector.simulators(home: home).availability == .absent)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(DeveloperStorageInspector.simulatorPath),
                                                withIntermediateDirectories: true)
        let result = DeveloperStorageInspector.simulators(home: home)
        #expect(result.availability == .available)
        #expect(result.logicalBytes == 0)
    }

    @Test func simulatorMeasuresSyntheticDirectoryWithoutRuntimeClaimsOrMutation() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let a = try write(DeveloperStorageInspector.simulatorPath + "/synthetic/a.bin", home: home, bytes: 321)
        _ = try write(DeveloperStorageInspector.simulatorPath + "/synthetic/b.bin", home: home, bytes: 123)
        let result = DeveloperStorageInspector.simulators(home: home)
        #expect(result.logicalBytes == 444)
        #expect(result.fileCount == 2)
        #expect(result.allocatedBytes != nil)
        #expect(try Data(contentsOf: a).count == 321)
    }

    @Test func simulatorFailedWalkNeverPublishesPartialTotal() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        _ = try write(DeveloperStorageInspector.simulatorPath + "/readable.bin", home: home)
        let denied = try write(DeveloperStorageInspector.simulatorPath + "/denied/data.bin", home: home).deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: denied.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: denied.path) }
        let result = DeveloperStorageInspector.simulators(home: home)
        #expect(result.availability == .unavailable)
        #expect(result.logicalBytes == nil)
        #expect(result.allocatedBytes == nil)
    }

    @Test func simulatorDoesNotFollowSymlinksAndDeduplicatesHardLinks() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let original = try write(DeveloperStorageInspector.simulatorPath + "/original", home: home)
        let external = try write("external/private", home: home)
        let root = original.deletingLastPathComponent()
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: external)
        try FileManager.default.linkItem(at: original, to: root.appendingPathComponent("hard-link"))
        #expect(DeveloperStorageInspector.simulators(home: home).logicalBytes == 321)
    }

    @Test func rootSymlinkFailsClosedForBothInspectors() throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let external = try write("external/private", home: home).deletingLastPathComponent()
        let root = home.appendingPathComponent(DeveloperStorageInspector.simulatorPath)
        try FileManager.default.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: external)
        #expect(DeveloperStorageInspector.simulators(home: home).availability == .unsupported)
        #expect(DeveloperStorageInspector.file(root.appendingPathComponent("private")).availability == .unsupported)
    }
}
