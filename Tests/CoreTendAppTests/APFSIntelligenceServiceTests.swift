// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import Persistence
@testable import CoreTendApp

private func tempDBPath() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent("apfs-\(UUID().uuidString).sqlite").path
}

@Suite("APFSIntelligenceService")
struct APFSIntelligenceServiceTests {
    @Test func nilStoreIsUnavailableNeverAFabricatedFigure() async {
        let result = await APFSIntelligenceService.filesAnalyzed(store: nil)
        #expect(result == nil)
    }

    @Test func noCleanupScanEverRunIsUnavailable() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        let result = await APFSIntelligenceService.filesAnalyzed(store: store)
        #expect(result == nil, "no Cleanup Timeline snapshot exists yet — this must not be reported as zero")
    }

    @Test func fullyMeasuredCategoriesProduceAMeasuredPhysicalTotal() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "user.caches", engine: "cleanup", logicalBytes: 1_000,
                                    physicalBytes: 900, fileCount: 1, risk: "low"),
            TimelineCategorySample(category: "user.logs", engine: "cleanup", logicalBytes: 500,
                                    physicalBytes: 400, fileCount: 1, risk: "low"),
        ])
        let result = try #require(await APFSIntelligenceService.filesAnalyzed(store: store))
        #expect(result.logicalBytes == 1_500)
        #expect(result.physicalBytes == 1_300)
    }

    @Test func oneCategoryMissingPhysicalBytesMakesTheWholeTotalUnavailable() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "user.caches", engine: "cleanup", logicalBytes: 1_000,
                                    physicalBytes: 900, fileCount: 1, risk: "low"),
            TimelineCategorySample(category: "user.logs", engine: "cleanup", logicalBytes: 500,
                                    physicalBytes: nil, fileCount: 1, risk: "low"),
        ])
        let result = try #require(await APFSIntelligenceService.filesAnalyzed(store: store))
        #expect(result.logicalBytes == 1_500, "logical is still reported — only the physical pairing is withheld")
        #expect(result.physicalBytes == nil,
                "a partial physical sum must never be presented as if it covered the whole scan")
    }

    @Test func emptyScanIsAMeasuredZeroNotUnavailable() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [])
        let result = try #require(await APFSIntelligenceService.filesAnalyzed(store: store))
        #expect(result.logicalBytes == 0)
        #expect(result.physicalBytes == 0, "nothing found is a real measured zero, not a missing measurement")
    }

    @Test func usesTheMostRecentCleanupSnapshotNotAnOlderOne() async throws {
        let path = tempDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try Store(path: path)
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "user.caches", engine: "cleanup", logicalBytes: 100,
                                    physicalBytes: 90, fileCount: 1, risk: "low"),
        ])
        try await store.recordTimelineSnapshot(scope: "cleanup", samples: [
            TimelineCategorySample(category: "user.caches", engine: "cleanup", logicalBytes: 999,
                                    physicalBytes: 900, fileCount: 1, risk: "low"),
        ])
        let result = try #require(await APFSIntelligenceService.filesAnalyzed(store: store))
        #expect(result.logicalBytes == 999)
    }
}
