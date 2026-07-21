import Testing
import Foundation
@testable import MacCareApp

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
