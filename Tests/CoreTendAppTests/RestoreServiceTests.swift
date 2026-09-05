// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import SafetyCore
import Persistence
@testable import CoreTendApp

/// A fully synthetic Trash layout under a temporary directory. Nothing here
/// touches the real `~/.Trash`: `RestoreValidator` accepts any path with a
/// `.Trash` component, so a `<fixture>/.Trash/...` source is a valid,
/// hermetic stand-in for a real Trash item.
private struct Fixture {
    let root: URL
    var trashDir: URL { root.appendingPathComponent(".Trash") }
    var store: Store

    init() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("rs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".Trash"),
                                                withIntermediateDirectories: true)
        self.root = root
        self.store = try Store(path: root.appendingPathComponent("store.sqlite").path)
    }

    func cleanup() { try? FileManager.default.removeItem(at: root) }

    @discardableResult
    func makeFile(_ relative: String, contents: String = "data") throws -> URL {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func makeTrashedFile(_ name: String, contents: String = "data") throws -> URL {
        let url = trashDir.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    /// Records a manifest row for an item whose Trash copy is at
    /// `trashDir/<name>` and whose original location is `root/<originalRel>`.
    /// The destination's parent directory is created unless `createParent`
    /// is false (used by the "parent missing" case).
    @discardableResult
    func recordManifest(name: String, originalRel: String, isDirectory: Bool = false,
                        inode: String? = nil, volumeUUID: String? = nil, createParent: Bool = true,
                        size: Int64 = 4, operationID: UUID = UUID()) async throws -> String {
        let trashURL = trashDir.appendingPathComponent(name)
        let originalURL = root.appendingPathComponent(originalRel)
        if createParent {
            try FileManager.default.createDirectory(at: originalURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
        }
        await store.recordRestoreManifest(RestoreManifestRecord(
            operationID: operationID, originalURL: originalURL, trashURL: trashURL,
            isDirectory: isDirectory, sizeBytes: size, modificationDate: Date(),
            volumeUUID: volumeUUID, inode: inode, ruleID: "user.caches", risk: .low))
        return try await store.restoreManifestItems().first { $0.trashPath == trashURL.path }!.id
    }
}

@Suite("RestoreService — availability")
struct RestoreServiceAvailabilityTests {
    @Test func presentTrashItemWithClearDestinationIsAvailable() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt")
        _ = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt")

        let groups = await RestoreService(store: fx.store).load()
        let item = try #require(groups.first?.items.first)
        #expect(item.availability == .available)
    }

    @Test func missingTrashItemIsReportedAndPersistedSoItIsNotOfferedAgain() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        let id = try await fx.recordManifest(name: "gone.txt", originalRel: "Downloads/gone.txt")
        // Never actually created in the synthetic Trash.

        let service = RestoreService(store: fx.store)
        let groups = await service.load()
        #expect(groups.first?.items.first?.availability == .missingFromTrash)
        let persisted = try #require(try await fx.store.restoreManifestItem(id: id))
        #expect(persisted.state == .missingFromTrash, "load persists the sticky source-side transition")
    }

    @Test func occupiedOriginalLocationIsAConflictNotOverwritten() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt", contents: "trashed")
        try fx.makeFile("Downloads/a.txt", contents: "the file that is already there")
        _ = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt")

        let groups = await RestoreService(store: fx.store).load()
        #expect(groups.first?.items.first?.availability == .destinationOccupied)
    }

    @Test func missingOriginalParentIsReported() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt")
        _ = try await fx.recordManifest(name: "a.txt", originalRel: "NoSuchFolder/a.txt", createParent: false)

        let groups = await RestoreService(store: fx.store).load()
        #expect(groups.first?.items.first?.availability == .parentMissing)
    }

    @Test func wrongInodeInTheManifestIsInvalidIdentity() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt")
        _ = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt", inode: "424242424242")

        let groups = await RestoreService(store: fx.store).load()
        #expect(groups.first?.items.first?.availability == .invalidIdentity)
    }

    @Test func matchingRealInodeIsAvailable() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        let trashURL = try fx.makeTrashedFile("a.txt")
        let realInode = try #require(FilesystemIdentity.inode(atPath: trashURL.path))
        _ = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt", inode: realInode)

        let groups = await RestoreService(store: fx.store).load()
        #expect(groups.first?.items.first?.availability == .available)
    }

    @Test func directoryRecordedAsFileMismatchIsInvalidIdentity() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt") // a regular file
        _ = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt", isDirectory: true)

        let groups = await RestoreService(store: fx.store).load()
        #expect(groups.first?.items.first?.availability == .invalidIdentity)
    }
}

@Suite("RestoreService — restore execution")
struct RestoreServiceExecutionTests {
    @Test func restoresAFileBackToItsOriginalLocationAndMarksTheManifest() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt", contents: "the original bytes")
        let id = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt")
        let service = RestoreService(store: fx.store)
        _ = await service.load()

        let summary = await service.restore(itemIDs: [id])
        #expect(summary.restoredCount == 1)
        #expect(summary.conflictCount == 0)
        let restored = fx.root.appendingPathComponent("Downloads/a.txt")
        #expect(FileManager.default.fileExists(atPath: restored.path))
        #expect(try String(contentsOf: restored, encoding: .utf8) == "the original bytes")
        #expect(!FileManager.default.fileExists(atPath: fx.trashDir.appendingPathComponent("a.txt").path))

        let manifest = try #require(try await fx.store.restoreManifestItem(id: id))
        #expect(manifest.state == .restored)
        #expect(manifest.restoredAt != nil)
    }

    @Test func restoresAWholeDirectoryWithItsContents() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        let trashedDir = fx.trashDir.appendingPathComponent("CacheDir")
        let nested = trashedDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("child".utf8).write(to: trashedDir.appendingPathComponent("child.bin"))
        try Data("nested".utf8).write(to: nested.appendingPathComponent("deep.bin"))
        let id = try await fx.recordManifest(name: "CacheDir", originalRel: "Library/Caches/CacheDir",
                                             isDirectory: true)
        // Ensure the destination parent exists.
        try FileManager.default.createDirectory(at: fx.root.appendingPathComponent("Library/Caches"),
                                                withIntermediateDirectories: true)

        let service = RestoreService(store: fx.store)
        _ = await service.load()
        let summary = await service.restore(itemIDs: [id])
        #expect(summary.restoredCount == 1)
        let dest = fx.root.appendingPathComponent("Library/Caches/CacheDir")
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("child.bin").path))
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("sub/deep.bin").path))
    }

    @Test func refusesToOverwriteAnOccupiedDestinationAndLeavesBothSidesUntouched() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt", contents: "trashed copy")
        try fx.makeFile("Downloads/a.txt", contents: "PRECIOUS existing file")
        let id = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt")

        let service = RestoreService(store: fx.store)
        let summary = await service.restore(itemIDs: [id])
        #expect(summary.restoredCount == 0)
        #expect(summary.conflictCount == 1)
        // Destination NOT overwritten, trash copy NOT consumed.
        #expect(try String(contentsOf: fx.root.appendingPathComponent("Downloads/a.txt"), encoding: .utf8)
                == "PRECIOUS existing file")
        #expect(FileManager.default.fileExists(atPath: fx.trashDir.appendingPathComponent("a.txt").path))
    }

    @Test func destinationCreatedBetweenReviewAndExecutionIsCaughtNotOverwritten() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt", contents: "trashed")
        let id = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt")
        let service = RestoreService(store: fx.store)

        // "Review": available.
        let groups = await service.load()
        #expect(groups.first?.items.first?.availability == .available)

        // Race: something appears at the destination after review.
        try fx.makeFile("Downloads/a.txt", contents: "sneaked in")

        let summary = await service.restore(itemIDs: [id])
        #expect(summary.restoredCount == 0)
        #expect(summary.conflictCount == 1)
        #expect(try String(contentsOf: fx.root.appendingPathComponent("Downloads/a.txt"), encoding: .utf8)
                == "sneaked in")
    }

    @Test func itemRemovedFromTrashBeforeExecutionIsSkippedAsUnavailable() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt")
        let id = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt")
        let service = RestoreService(store: fx.store)
        _ = await service.load()

        try FileManager.default.removeItem(at: fx.trashDir.appendingPathComponent("a.txt"))

        let summary = await service.restore(itemIDs: [id])
        #expect(summary.restoredCount == 0)
        #expect(summary.unavailableCount == 1)
        #expect(try await fx.store.restoreManifestItem(id: id)?.state == .missingFromTrash)
    }

    @Test func multiItemRestoreReportsRealPerItemOutcomes() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        // 1) available
        try fx.makeTrashedFile("ok.txt", contents: "ok")
        let okID = try await fx.recordManifest(name: "ok.txt", originalRel: "Downloads/ok.txt")
        // 2) destination occupied
        try fx.makeTrashedFile("busy.txt", contents: "busy")
        try fx.makeFile("Downloads/busy.txt", contents: "already here")
        let busyID = try await fx.recordManifest(name: "busy.txt", originalRel: "Downloads/busy.txt")
        // 3) missing from trash
        let missingID = try await fx.recordManifest(name: "missing.txt", originalRel: "Downloads/missing.txt")

        let service = RestoreService(store: fx.store)
        _ = await service.load()
        let summary = await service.restore(itemIDs: [okID, busyID, missingID])

        #expect(summary.requested == 3)
        #expect(summary.restoredCount == 1)
        #expect(summary.conflictCount == 1)
        #expect(summary.unavailableCount == 1)
        #expect(FileManager.default.fileExists(atPath: fx.root.appendingPathComponent("Downloads/ok.txt").path))
    }

    @Test func aRestoreRunWritesOneCoarseActivityRecord() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt", contents: "12345")
        let id = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt", size: 5)
        let service = RestoreService(store: fx.store)
        _ = await service.load()
        _ = await service.restore(itemIDs: [id])

        let restoreActivity = try await fx.store.activity(kind: .restore)
        #expect(restoreActivity.count == 1)
        #expect(restoreActivity.first?.itemCount == 1)
        #expect(restoreActivity.first?.bytes == 5)
    }

    @Test func restoreEmitsARedactedSafetyAuditEventNeverARawPath() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        try fx.makeTrashedFile("a.txt")
        let id = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt")
        let service = RestoreService(store: fx.store)
        _ = await service.load()
        _ = await service.restore(itemIDs: [id])

        let log = try await fx.store.safetyLog()
        let restoreRow = try #require(log.first { $0.ruleID == "restore.user.caches" })
        #expect(restoreRow.stage == .executed)
        #expect(!restoreRow.redactedPath.contains(NSHomeDirectory()))
        #expect(!restoreRow.redactedPath.contains(NSUserName()))
    }
}

@Suite("RestoreService — forget history")
struct RestoreServiceForgetTests {
    @Test func forgetRemovesManifestsButNeverTouchesTheTrash() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        let trashURL = try fx.makeTrashedFile("a.txt", contents: "still in trash")
        _ = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt")
        let service = RestoreService(store: fx.store)
        #expect(await service.hasHistory())

        await service.forgetHistory()

        #expect(!(await service.hasHistory()))
        #expect(try await fx.store.restoreManifestCount() == 0)
        #expect(FileManager.default.fileExists(atPath: trashURL.path),
                "Forget Restore History must not remove anything from the Trash")
        #expect(try String(contentsOf: trashURL, encoding: .utf8) == "still in trash")
    }

    @Test func forgetDoesNotTouchActivityOrSafetyLog() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        _ = try await fx.store.recordActivity(ActivityRecord(kind: .cleanup, summary: "x", itemCount: 1, bytes: 1))
        await fx.store.recordSafetyEvent(SafetyAuditEvent(
            operationID: UUID(), stage: .executed, path: "/Users/x/y", ruleID: "r", risk: .low, size: 1, result: "ok"))
        _ = try await fx.recordManifest(name: "a.txt", originalRel: "Downloads/a.txt")

        try await fx.store.clearRestoreManifests()

        #expect(try await fx.store.activity().count == 1)
        #expect(try await fx.store.safetyLog().count == 1)
    }
}

@Suite("RestoreService — pure helpers")
struct RestoreServicePureTests {
    @Test func shortLocationHidesTheFullPathButStaysRecognizable() {
        let long = "/Users/someone/Library/Application Support/Vendor/App/Deep/file.bin"
        let short = RestoreDisplay.shortLocation(long)
        #expect(!short.contains("file.bin"))
        #expect(short.contains("…"))
        #expect(short.count < long.count)
    }

    @Test func groupingKeepsOneGroupPerOperation() async throws {
        let fx = try Fixture(); defer { fx.cleanup() }
        let opA = UUID(), opB = UUID()
        try fx.makeTrashedFile("a1.txt"); try fx.makeTrashedFile("a2.txt"); try fx.makeTrashedFile("b1.txt")
        _ = try await fx.recordManifest(name: "a1.txt", originalRel: "Downloads/a1.txt", operationID: opA)
        _ = try await fx.recordManifest(name: "a2.txt", originalRel: "Downloads/a2.txt", operationID: opA)
        _ = try await fx.recordManifest(name: "b1.txt", originalRel: "Downloads/b1.txt", operationID: opB)

        let groups = await RestoreService(store: fx.store).load()
        #expect(groups.count == 2)
        #expect(Set(groups.map(\.itemCount)) == [1, 2])
    }

    @Test func volumeIsMountedIsTrueForARealMountedUUIDAndFalseForGarbage() {
        let boot = URL(fileURLWithPath: "/")
        if let realUUID = FilesystemIdentity.volumeUUID(of: boot) {
            #expect(RestoreService.volumeIsMounted(uuid: realUUID, fileManager: .default))
        }
        #expect(!RestoreService.volumeIsMounted(uuid: "not-a-real-volume-uuid", fileManager: .default))
    }
}
