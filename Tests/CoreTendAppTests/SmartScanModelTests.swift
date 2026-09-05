// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import CoreTendApp

private struct FakeProvider: SmartScanProvider {
    let module: SmartScanModuleID
    var hang = false

    func scan(progress: @Sendable (String) -> Void) async throws -> SmartScanModuleResult {
        if hang {
            for _ in 0..<10_000 {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(5))
            }
        }
        progress("done")
        return SmartScanModuleResult(
            module: module, headline: "h",
            totals: SmartScanTotals(potentiallyRecoverableBytes: 10), overlapsStorage: false)
    }
}

@MainActor
private func waitUntil(_ timeout: Duration = .seconds(3),
                       _ condition: () -> Bool) async {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(20))
    }
}

@MainActor
@Suite("SmartScanModel — app-scope lifetime")
struct SmartScanModelTests {

    private func model(_ providers: [SmartScanProvider]) -> SmartScanModel {
        SmartScanModel(coordinator: SmartScanCoordinator(providers: providers),
                       pollInterval: .milliseconds(20))
    }

    @Test func startRunsToCompletionAndPublishesAReport() async {
        let m = model([FakeProvider(module: .storage), FakeProvider(module: .integrity)])
        m.start()
        await waitUntil { m.phase == .completed }
        #expect(m.hasCompletedReport)
        #expect(m.report?.wasCancelled == false)
        #expect(m.report?.globalRecoverableBytes == 20)
        if case .completed = m.modules[.storage] {} else { Issue.record("storage not completed") }
    }

    @Test func startWhileRunningDoesNotRestart() async {
        let m = model([FakeProvider(module: .storage, hang: true)])
        m.start()
        await waitUntil { m.phase == .running }
        m.start()   // must be a no-op, not a reset or a second run
        #expect(m.phase == .running)
        m.cancel()
        await waitUntil { m.phase == .cancelled }
    }

    @Test func cancelYieldsCancelledNeverCompleted() async {
        let m = model([FakeProvider(module: .storage, hang: true)])
        m.start()
        await waitUntil { m.phase == .running }
        m.cancel()
        await waitUntil { m.phase == .cancelled }
        #expect(m.phase == .cancelled)
        #expect(!m.hasCompletedReport)
        #expect(m.report?.wasCancelled == true)
    }

    @Test func resetReturnsToIdleAfterAFinishedRun() async {
        let m = model([FakeProvider(module: .storage)])
        m.start()
        await waitUntil { m.phase == .completed }
        m.reset()
        #expect(m.phase == .idle)
        #expect(m.report == nil)
        #expect(m.modules.isEmpty)
    }

    @Test func resetIsIgnoredWhileRunning() async {
        let m = model([FakeProvider(module: .storage, hang: true)])
        m.start()
        await waitUntil { m.phase == .running }
        m.reset()
        #expect(m.phase == .running)
        m.cancel()
        await waitUntil { m.phase == .cancelled }
    }
}
