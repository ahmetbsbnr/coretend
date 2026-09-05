// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
import FileRules
import Persistence
@testable import CoreTendApp

/// Proves the manifest is captured through the *existing* shared execution
/// path — `CleanupExecution` / `RecoveryPlanService` were not given a second,
/// restore-specific code path. These move a real fixture file to the real
/// `~/.Trash` (the same contract `RecoveryPlanExecutionTests` already relies
/// on) and clean it back out afterwards.
@Suite("Restore manifest capture — shared execution path")
struct RestoreCaptureIntegrationTests {
    private func fixtureHome() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rc-int-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func tempStore() throws -> (Store, String) {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("rc-store-\(UUID().uuidString).sqlite").path
        return (try Store(path: path), path)
    }

    @Test func cleanupExecutionCreatesARestoreManifestThroughTheSharedSink() async throws {
        let home = try fixtureHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let (store, storePath) = try tempStore()
        defer { try? FileManager.default.removeItem(atPath: storePath) }

        // A stale log file: user.logs is low-risk and matches files >7 days old.
        let logFile = home.appendingPathComponent("Library/Logs/old.log")
        try FileManager.default.createDirectory(at: logFile.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("stale log".utf8).write(to: logFile)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-10 * 86_400)],
                                              ofItemAtPath: logFile.path)

        let finding = ScanFinding(url: logFile, logicalSize: Int64("stale log".utf8.count),
                                  allocatedSize: nil, modificationDate: nil, ruleID: "user.logs",
                                  category: "user.logs", explanation: "", confidence: 1, risk: .low,
                                  preselected: true)
        let result = await CleanupExecution.execute([finding], home: home, sink: store)
        #expect(result.executed.count == 1)
        #expect(!FileManager.default.fileExists(atPath: logFile.path))

        let manifests = try await store.restoreManifestItems()
        #expect(manifests.count == 1, "the shared SafetyCenter sink captured exactly one manifest")
        let manifest = try #require(manifests.first)
        #expect(manifest.originalPath == logFile.standardizedFileURL.path)
        #expect(manifest.ruleID == "user.logs")
        #expect(manifest.state == .available)
        #expect(FileManager.default.fileExists(atPath: manifest.trashPath))

        // Leave the real Trash as we found it.
        try? FileManager.default.removeItem(atPath: manifest.trashPath)
    }

    @Test func recoveryPlanCleanupExecutionAlsoCapturesAManifest_noSeparatePath() async throws {
        let home = try fixtureHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let (store, storePath) = try tempStore()
        defer { try? FileManager.default.removeItem(atPath: storePath) }

        let logFile = home.appendingPathComponent("Library/Logs/rp.log")
        try FileManager.default.createDirectory(at: logFile.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("rp stale".utf8).write(to: logFile)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-10 * 86_400)],
                                              ofItemAtPath: logFile.path)

        let candidates = await RecoveryPlanService.cleanupCandidates(home: home, store: store)
        let logs = try #require(candidates.first { $0.candidate.finding.source == "user.logs" })
        _ = await RecoveryPlanService.executeOne(logs, home: home, store: store)

        let manifests = try await store.restoreManifestItems()
        #expect(manifests.contains { $0.originalPath == logFile.standardizedFileURL.path && $0.ruleID == "user.logs" })
        for m in manifests { try? FileManager.default.removeItem(atPath: m.trashPath) }
    }
}
