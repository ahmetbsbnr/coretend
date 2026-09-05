// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import FileRules
@testable import CoreTendApp

/// Exercises `RecoveryPlanService` against a disposable fixture home and a
/// nil audit store — real `ScanEngine`/`DuplicateEngine` scans, real
/// `SafetyCenter.execute` Trash moves (the same real-Trash contract
/// `PathValidatorTests.executionEmitsApprovedThenExecuted` already exercises
/// for `SafetyCenter` directly), never a mock standing in for the actual
/// safety path. `store: nil` throughout: RecoveryPlanService already treats
/// a nil store as "skip the optional activity/exclusions write" (the same
/// tolerance `AppEnvironment.record(_:)` has for a nil store), so these
/// tests never touch the real `~/Library/Application Support/CoreTend`
/// database the `AppEnvironment.shared` singleton would otherwise open.
@Suite("RecoveryPlanService execution")
struct RecoveryPlanExecutionTests {
    private func fixtureHome() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ content: String, to url: URL, ageDays: Int) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
        let old = Date().addingTimeInterval(-Double(ageDays) * 86_400)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: url.path)
    }

    @Test func cleanupCandidateExecutesAndMovesTheRealFileToTrash() async throws {
        let home = try fixtureHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let logFile = home.appendingPathComponent("Library/Logs/old.log")
        try write("stale log content", to: logFile, ageDays: 10) // user.logs: older than 7 days

        let candidates = await RecoveryPlanService.cleanupCandidates(home: home, store: nil)
        let logsCandidate = try #require(candidates.first { $0.candidate.finding.source == "user.logs" })
        #expect(logsCandidate.candidate.category == .recommended)
        #expect(logsCandidate.candidate.reclaimableBytes == Int64("stale log content".utf8.count))

        let result = await RecoveryPlanService.executeOne(logsCandidate, home: home, store: nil)
        #expect(result.processedCount == 1)
        #expect(result.processedBytes == Int64("stale log content".utf8.count))
        #expect(result.skippedCount == 0)
        #expect(!FileManager.default.fileExists(atPath: logFile.path), "the real file must be moved to Trash")
    }

    @Test func cleanupCandidateWithNoMatchesIsAZeroByteRecommendedFindingNotACrash() async throws {
        let home = try fixtureHome()
        defer { try? FileManager.default.removeItem(at: home) }
        // No files created at all — every rule should report 0 bytes, never crash.
        let candidates = await RecoveryPlanService.cleanupCandidates(home: home, store: nil)
        #expect(candidates.count == UserCleanupRules.all.count, "one candidate per shipped Cleanup rule, even with nothing found")
        for data in candidates {
            #expect(data.candidate.reclaimableBytes == 0)
        }
    }

    @Test func userCachesIsAlwaysNotIncludedRegardlessOfWhatItFinds() async throws {
        let home = try fixtureHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try write("cache bytes", to: home.appendingPathComponent("Library/Caches/SomeApp/data.cache"), ageDays: 0)

        let candidates = await RecoveryPlanService.cleanupCandidates(home: home, store: nil)
        let cachesCandidate = try #require(candidates.first { $0.candidate.finding.source == "user.caches" })
        #expect(cachesCandidate.candidate.reclaimableBytes > 0, "it did find real bytes")
        #expect(cachesCandidate.candidate.category == .notIncluded)
        #expect(cachesCandidate.candidate.exclusionReason == .overlapsAnotherSource,
                "never silently dropped — shown, with its real bytes, explained as an overlap")
    }

    /// `DuplicateEngine`'s default `minimumSize` is 1 MB (not worth flagging
    /// tiny duplicate files) — fixture content must clear that floor for the
    /// real engine to consider it at all.
    private func megabyteOfContent(seed: UInt8) -> String {
        String(repeating: Character(UnicodeScalar(seed)), count: 1_100_000)
    }

    @Test func duplicatesCandidateExecutesAndKeepsExactlyOneCopy() async throws {
        let home = try fixtureHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let content = megabyteOfContent(seed: 65)
        let a = home.appendingPathComponent("Downloads/a.bin")
        let b = home.appendingPathComponent("Downloads/copy/b.bin")
        try write(content, to: a, ageDays: 0)
        try write(content, to: b, ageDays: 0)

        let candidates = await RecoveryPlanService.duplicateCandidates(home: home)
        let duplicate = try #require(candidates.first)
        #expect(duplicate.candidate.category == .reviewRequired)
        #expect(duplicate.candidate.reclaimableBytes == Int64(content.utf8.count))

        let result = await RecoveryPlanService.executeOne(duplicate, home: home, store: nil)
        #expect(result.processedCount == 1, "exactly one of the two copies is removed")
        #expect(result.processedBytes == Int64(content.utf8.count))
        let aExists = FileManager.default.fileExists(atPath: a.path)
        let bExists = FileManager.default.fileExists(atPath: b.path)
        #expect(aExists != bExists, "exactly one copy survives — never both, never neither")
    }

    @Test func duplicatesWithNoDuplicatesProducesNoCandidateAtAll() async throws {
        let home = try fixtureHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try write(megabyteOfContent(seed: 65), to: home.appendingPathComponent("Downloads/a.bin"), ageDays: 0)
        try write(megabyteOfContent(seed: 66), to: home.appendingPathComponent("Documents/b.bin"), ageDays: 0)
        let candidates = await RecoveryPlanService.duplicateCandidates(home: home)
        #expect(candidates.isEmpty)
    }
}
