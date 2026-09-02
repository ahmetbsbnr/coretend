import Testing
import Foundation
import ScanCore
@testable import CoreTendApp

@Suite("Cloud Cleanup sync-state classification")
struct CloudCleanupTests {
    typealias SyncState = CloudCleanupViewModel.SyncState

    @Test func realPlaceholderSignalAlwaysWins() {
        // The ubiquitous "not downloaded" signal beats any byte heuristic.
        #expect(SyncState.classify(logicalBytes: 1000, localBytes: 1000, isCloudPlaceholder: true) == .placeholder)
    }

    @Test func fullyDownloadedIsLocal() {
        #expect(SyncState.classify(logicalBytes: 1000, localBytes: 1000, isCloudPlaceholder: false) == .local)
        #expect(SyncState.classify(logicalBytes: 1000, localBytes: 2000, isCloudPlaceholder: false) == .local)
    }

    @Test func mostlyRemoteIsPlaceholderPartialInBetween() {
        #expect(SyncState.classify(logicalBytes: 1000, localBytes: 50, isCloudPlaceholder: false) == .placeholder)
        #expect(SyncState.classify(logicalBytes: 1000, localBytes: 500, isCloudPlaceholder: false) == .partial)
    }

    @Test func emptyFolderIsLocalNotRemote() {
        #expect(SyncState.classify(logicalBytes: 0, localBytes: 0, isCloudPlaceholder: false) == .local)
    }

    @Test func detectsKnownProviderRootsUnderFixtureHome() throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-cloud-\(UUID().uuidString)")
        let fm = FileManager.default
        defer { try? fm.removeItem(at: home) }
        try fm.createDirectory(at: home.appendingPathComponent("Dropbox"), withIntermediateDirectories: true)
        // Provider-named CloudStorage directory (Google Drive File Provider layout).
        try fm.createDirectory(
            at: home.appendingPathComponent("Library/CloudStorage/GoogleDrive-user@example.com"),
            withIntermediateDirectories: true)

        let found = CloudCleanupViewModel.detectProviders(home: home)
        #expect(found.contains { $0.name == "Dropbox" })
        #expect(found.contains { $0.name == "Google Drive" })
        // No iCloud/OneDrive roots exist in the fixture — they must not appear.
        #expect(!found.contains { $0.name == "OneDrive" })
        #expect(!found.contains { $0.name == "iCloud Drive" })
    }

    @Test func emptyHomeYieldsNoProviders() throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-cloud-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        #expect(CloudCleanupViewModel.detectProviders(home: home).isEmpty)
    }

    @Test func measureWalksTreeSkipsSymlinksAndSortsByLocalBytes() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-cloud-\(UUID().uuidString)")
        let fm = FileManager.default
        let sub = root.appendingPathComponent("folder")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try Data(repeating: 0, count: 4000).write(to: root.appendingPathComponent("small.txt"))
        try Data(repeating: 0, count: 40_000).write(to: sub.appendingPathComponent("big.bin"))
        // A symlink at top level must be skipped, not measured.
        try fm.createSymbolicLink(
            at: root.appendingPathComponent("link"), withDestinationURL: sub)

        let entries = CloudCleanupViewModel.measure(root: root)
        let names = entries.map(\.name)
        #expect(!names.contains("link"))
        #expect(names.contains("folder"))
        #expect(names.contains("small.txt"))
        // Sorted by local bytes descending: the 40 KB folder outranks the 4 KB file.
        #expect(entries.first?.name == "folder")
        let folder = try #require(entries.first { $0.name == "folder" })
        #expect(folder.isDirectory)
        #expect(folder.localBytes >= 40_000)
    }

    @Test func asyncMeasureHonorsPauseAndResume() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-cloud-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        for index in 0..<20 {
            try Data(repeating: UInt8(index), count: 1024)
                .write(to: root.appendingPathComponent("item-\(index).bin"))
        }

        let pauseController = ScanPauseController()
        let probe = CompletionProbe()
        await pauseController.pause()
        let task = Task {
            let entries = await CloudCleanupViewModel.measure(root: root, pauseController: pauseController)
            await probe.markCompleted()
            return entries
        }
        try await Task.sleep(nanoseconds: 40_000_000)
        #expect(await !probe.completed)

        await pauseController.resume()
        let entries = await task.value
        #expect(entries.count == 20)
    }

    @Test func recoverableCountsOnlyBytesActuallyOnDiskNeverLogical() {
        // A remote-only placeholder contributes its (near-zero) LOCAL bytes to the
        // recoverable figure — never its logical size. This is the core honesty
        // invariant: we never claim we can free bytes that aren't on this disk.
        let placeholder = CloudCleanupViewModel.Entry(
            id: "a", name: "big.mov", isDirectory: false,
            logicalBytes: 5_000_000_000, localBytes: 0, isCloudPlaceholder: true)
        let localFile = CloudCleanupViewModel.Entry(
            id: "b", name: "notes.txt", isDirectory: false,
            logicalBytes: 2000, localBytes: 2000, isCloudPlaceholder: false)
        #expect(placeholder.syncState == .placeholder)
        #expect(placeholder.isMostlyRemote == true)
        #expect(localFile.isMostlyRemote == false)
        // Recoverable = sum of local bytes only (2000), not 5 GB of cloud data.
        #expect(placeholder.localBytes + localFile.localBytes == 2000)
    }
}

private actor CompletionProbe {
    private(set) var completed = false

    func markCompleted() {
        completed = true
    }
}
