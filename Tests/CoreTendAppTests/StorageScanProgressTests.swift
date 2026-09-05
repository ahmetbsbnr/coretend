// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
import SafetyCore
@testable import CoreTendApp

private func f(_ bytes: Int64, risk: RiskLevel = .low) -> ScanFinding {
    ScanFinding(url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString)"),
                logicalSize: bytes, allocatedSize: bytes, modificationDate: nil,
                ruleID: "r", category: "cache", explanation: "e",
                confidence: 1, risk: risk, preselected: false)
}

@Suite("StorageScanProgress — real engine events, no fabricated percentage")
struct StorageScanProgressTests {

    @Test func thereIsNoPercentageField() {
        // Compile-time guarantee via Mirror: no member named like a fraction.
        let names = Mirror(reflecting: StorageScanProgress()).children.compactMap(\.label)
        for n in names {
            #expect(!n.lowercased().contains("fraction"))
            #expect(!n.lowercased().contains("percent"))
            #expect(!(n.lowercased().contains("progress") && n != "phase"))
        }
    }

    @Test func startAndProgressEventsPopulateRealCounters() {
        var p = StorageScanProgress()
        p = p.applying(.started)
        #expect(p.phase == .scanning)
        p = p.applying(.progress(scanned: 12_000, currentPath: "/Users/x/Library/Caches/com.demo"))
        #expect(p.itemsInspected == 12_000)
        #expect(p.currentPath.hasSuffix("com.demo"))
    }

    @Test func findingsSplitByRiskIntoReclaimableVsReviewRequired() {
        var p = StorageScanProgress().applying(.started)
        p = p.applying(.finding(f(1_000, risk: .low)))
        p = p.applying(.finding(f(2_000, risk: .medium)))
        p = p.applying(.finding(f(9_000, risk: .high)))
        #expect(p.findingsDetected == 3)
        #expect(p.reclaimableBytesSoFar == 3_000)
        #expect(p.reviewRequiredBytesSoFar == 9_000)
        #expect(p.detectedBytesSoFar == 12_000)
    }

    @Test func aPerPathErrorDoesNotFailOrStallTheScan() {
        var p = StorageScanProgress().applying(.started)
        p = p.applying(.progress(scanned: 5, currentPath: "/a"))
        p = p.applying(.error(path: "/b", message: "permission denied"))
        #expect(p.phase == .scanning)
        #expect(p.itemsInspected == 5)
        #expect(p.failureMessage == nil)
    }

    @Test func finishedTransitionsToDoneAndClearsTheCurrentPath() {
        var p = StorageScanProgress().applying(.started)
        p = p.applying(.progress(scanned: 40, currentPath: "/deep/path"))
        p = p.applying(.finished(scanned: 42, totalBytes: 1_234))
        #expect(p.phase == .done)
        #expect(p.itemsInspected == 42)
        #expect(p.currentPath.isEmpty)
    }

    @Test func pauseResumeCancelAreExplicitNonEngineTransitions() {
        var p = StorageScanProgress().applying(.started)
        p.markPaused();  #expect(p.phase == .paused)
        #expect(p.isCancellable)              // still cancellable while paused
        p.markResumed(); #expect(p.phase == .scanning)
        p.markCancelled()
        #expect(p.phase == .cancelled)
        #expect(!p.isCancellable)
        #expect(p.currentPath.isEmpty)
    }

    @Test func cancelledProgressIsNeverDone() {
        var p = StorageScanProgress().applying(.started)
        p = p.applying(.finding(f(500)))
        p.markCancelled()
        // A cancelled scan must not be presented as a completed one.
        #expect(p.phase == .cancelled)
        #expect(p.phase != .done)
    }

    @Test func isPausableOnlyReflectsAnAttachedController() {
        let withController = StorageScanProgress(isPausable: true)
        let without = StorageScanProgress(isPausable: false)
        #expect(withController.isPausable)
        #expect(!without.isPausable)   // no fake Pause button when nothing can pause
    }
}
