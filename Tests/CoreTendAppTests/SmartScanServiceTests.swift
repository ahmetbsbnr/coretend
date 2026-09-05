// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import CoreTendApp

// A fake provider with controllable timing / outcome. Records how many
// disk-heavy providers were live at once (via a shared box).
private actor Live { var n = 0; var peak = 0
    func enter() { n += 1; peak = max(peak, n) }
    func leave() { n -= 1 }
}

private struct FakeProvider: SmartScanProvider {
    let module: SmartScanModuleID
    var recoverable: Int64 = 0
    var review: Int64 = 0
    var attention = 0
    var informational = 0
    var overlapsStorage = false
    var delayMs: UInt64 = 5
    var outcome: Outcome = .ok
    var live: Live? = nil
    /// Emit a progress ping on the very last line before returning — the
    /// shape a real provider has (it reports its final tally then returns).
    var progressOnExit = false

    enum Outcome { case ok, throwsGeneric, unavailable, hang }

    func scan(progress: @Sendable (String) -> Void) async throws -> SmartScanModuleResult {
        if let live { await live.enter() }
        defer { if let live { Task { await live.leave() } } }
        progress("scanning \(module.rawValue)…")
        if outcome == .hang {
            try await Task.sleep(for: .seconds(5))     // long enough to be cancelled
        } else {
            try await Task.sleep(for: .milliseconds(delayMs))
        }
        switch outcome {
        case .throwsGeneric: throw NSError(domain: "x", code: 1)
        case .unavailable: throw SmartScanError.unavailable("permission-limited")
        case .ok, .hang:
            if progressOnExit { progress("final tally") }
            return SmartScanModuleResult(
                module: module,
                headline: "\(module.rawValue) done",
                totals: .init(potentiallyRecoverableBytes: recoverable, needsReviewBytes: review,
                              attentionCount: attention, informationalCount: informational),
                overlapsStorage: overlapsStorage)
        }
    }
}

@Suite("SmartScanCoordinator — orchestration, isolation, anti-double-counting")
struct SmartScanServiceTests {

    @Test func everyConnectedModuleReachesCompleted_unconnectedIsUnavailable() async {
        let c = SmartScanCoordinator(providers: [
            FakeProvider(module: .storage, recoverable: 2_000),
            FakeProvider(module: .integrity, attention: 3),
        ])
        let report = await c.start().value
        #expect({ if case .completed = report.modules[.storage] { return true } else { return false } }())
        #expect({ if case .completed = report.modules[.integrity] { return true } else { return false } }())
        #expect(report.modules[.developer] == .unavailable(reason: "not-connected"))
        #expect(report.wasCancelled == false)
    }

    @Test func aLateProgressPingDoesNotResurrectACompletedModule() async {
        // Regression: a provider that reports progress on its last line
        // before returning used to clobber its own `.completed` state back
        // to `.scanning`, dropping its bytes from the aggregate.
        let c = SmartScanCoordinator(providers: [
            FakeProvider(module: .storage, recoverable: 2_000, progressOnExit: true),
        ])
        let report = await c.start().value
        #expect({ if case .completed = report.modules[.storage] { return true } else { return false } }())
        #expect(report.globalRecoverableBytes == 2_000)
    }

    @Test func aggregateSeparatesTheFourBuckets_neverOneNumber() async {
        let c = SmartScanCoordinator(providers: [
            FakeProvider(module: .storage, recoverable: 5_000, review: 1_000),
            FakeProvider(module: .developer, recoverable: 3_000),
            FakeProvider(module: .integrity, attention: 4),
            FakeProvider(module: .applications, informational: 7),
        ])
        let r = await c.start().value
        #expect(r.globalRecoverableBytes == 8_000)          // storage + developer (no overlap)
        #expect(r.needsReviewBytes == 1_000)                // separate bucket
        #expect(r.attentionCount == 4)                      // a COUNT, not bytes
        #expect(r.informationalCount == 7)                  // a COUNT, not bytes
        #expect(r.isGlobalRecoverableExact == true)
    }

    @Test func antiDoubleCounting_overlappingModuleIsExcludedFromTheGlobalFigure() async {
        let c = SmartScanCoordinator(providers: [
            FakeProvider(module: .storage, recoverable: 10_000),
            // Privacy browser caches also live under ~/Library/Caches, which
            // Storage already counted — must NOT be added again.
            FakeProvider(module: .privacy, recoverable: 4_000, overlapsStorage: true),
        ])
        let r = await c.start().value
        #expect(r.globalRecoverableBytes == 10_000, "the overlapping 4 000 is not summed")
        #expect(r.isGlobalRecoverableExact == false, "so the UI shows category totals separately")
    }

    @Test func moduleFailureIsIsolated_theRestStillComplete() async {
        let c = SmartScanCoordinator(providers: [
            FakeProvider(module: .storage, recoverable: 1_000),
            FakeProvider(module: .developer, outcome: .throwsGeneric),
            FakeProvider(module: .integrity, attention: 1),
        ])
        let r = await c.start().value
        #expect(r.modules[.developer] == .failed(reason: "engine-error"))
        #expect({ if case .completed = r.modules[.storage] { return true } else { return false } }())
        #expect({ if case .completed = r.modules[.integrity] { return true } else { return false } }())
        #expect(r.globalRecoverableBytes == 1_000, "a failed module contributes nothing")
    }

    @Test func permissionLimitedModuleIsUnavailable_notFailed() async {
        let c = SmartScanCoordinator(providers: [
            FakeProvider(module: .privacy, outcome: .unavailable),
            FakeProvider(module: .storage, recoverable: 500),
        ])
        let r = await c.start().value
        #expect(r.modules[.privacy] == .unavailable(reason: "permission-limited"))
    }

    @Test func diskHeavyProvidersRespectTheConcurrencyCap() async {
        let live = Live()
        let providers: [SmartScanProvider] = [.storage, .developer, .duplicates, .privacy].map {
            FakeProvider(module: $0, recoverable: 100, delayMs: 40, live: live)
        }
        let c = SmartScanCoordinator(providers: providers, diskConcurrency: 2)
        _ = await c.start().value
        let peak = await live.peak
        #expect(peak <= 2, "at most 2 disk-heavy scans ran at once (got \(peak))")
        #expect(peak >= 1)
        #expect(await c.peakDiskConcurrency <= 2)
    }

    @Test func cheapMetadataModulesAreNotCappedByTheDiskLimit() async {
        // Two cheap modules + a diskConcurrency of 1 — the cheap ones must
        // still both run (they are not disk-heavy).
        let c = SmartScanCoordinator(providers: [
            FakeProvider(module: .applications, informational: 1, delayMs: 20),
            FakeProvider(module: .integrity, attention: 1, delayMs: 20),
        ], diskConcurrency: 1)
        let r = await c.start().value
        #expect({ if case .completed = r.modules[.applications] { return true } else { return false } }())
        #expect({ if case .completed = r.modules[.integrity] { return true } else { return false } }())
    }

    @Test func cancellationYieldsAPartialReport_withNoCompletedModuleAndNoTimelineWrite() async {
        let c = SmartScanCoordinator(providers: [
            FakeProvider(module: .storage, outcome: .hang),
            FakeProvider(module: .developer, outcome: .hang),
        ])
        let task = await c.start()
        try? await Task.sleep(for: .milliseconds(20))
        await c.cancel()
        let r = await task.value
        #expect(r.wasCancelled == true)
        for m in [SmartScanModuleID.storage, .developer] {
            #expect(r.modules[m] == .cancelled, "\(m) must be cancelled, never completed")
        }
        #expect(r.globalRecoverableBytes == 0)
        // The coordinator never writes a Timeline snapshot itself; a
        // cancelled report carries wasCancelled so callers skip the write.
    }

    @Test func startWhileRunningReturnsTheSameRun_noDuplicateScan() async {
        let c = SmartScanCoordinator(providers: [FakeProvider(module: .storage, delayMs: 60)])
        let a = await c.start()
        let b = await c.start()
        #expect(a == b, "the second start() returns the in-flight task, not a new scan")
        _ = await a.value
    }

    @Test func healthyEmptyResult_zeroAcrossEveryBucket_noScore() async {
        let c = SmartScanCoordinator(providers: SmartScanModuleID.allCases.map {
            FakeProvider(module: $0)   // all zero
        })
        let r = await c.start().value
        #expect(r.globalRecoverableBytes == 0)
        #expect(r.needsReviewBytes == 0)
        #expect(r.attentionCount == 0)
        #expect(r.informationalCount == 0)
        // There is deliberately no "score" / "percentage" field to assert on.
    }

    @Test func theServiceHasNoDestructiveDependency() throws {
        let src = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Sources/CoreTendApp/SmartScanService.swift"),
            encoding: .utf8)
        for forbidden in ["SafetyCenter", "CleanupExecution", "RecoveryPlanService.execute",
                          "RestoreService", "trashItem", "FileManager.default.removeItem",
                          "removeItem(at", "import FileRules"] {
            #expect(!src.contains(forbidden), "SmartScanService references \(forbidden)")
        }
    }
}
