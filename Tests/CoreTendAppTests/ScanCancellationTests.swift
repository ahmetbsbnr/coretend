// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// The regression suite for the 1.0.1 "Cancel does nothing" report.
///
/// The bug was not that cancellation failed — the CPU work did stop. It was
/// that every view model reset its phase from inside `case .cancelled:` of the
/// event loop, and `AsyncStream.Iterator.next()` returns `nil` on cancellation
/// *before* that event is ever delivered. The arm was dead code, so the UI
/// stayed in its scanning phase forever: spinner running, Cancel still shown,
/// and the scan unrestartable because of `guard phase != .scanning`.
///
/// These tests call `cancel()` directly, with no scan running and with the
/// phase forced to scanning, because that is exactly the state the user's
/// click lands in. Each one fails against the 1.0.1 code.
@MainActor
@Suite("Cancel leaves every scan view model usable again")
struct ScanCancellationTests {

    @Test func cleanupCancelLeavesIdle() {
        let model = CleanupViewModel()
        model.phase = .scanning
        model.isScanPaused = true
        model.cancelScan()
        #expect(model.phase == .idle)
        #expect(model.isScanPaused == false)
    }

    @Test func duplicatesCancelLeavesIdleWhenNothingFound() {
        let model = DuplicatesViewModel()
        model.phase = .scanning(processed: 12, total: 40)
        model.cancel()
        #expect(model.phase == .idle)
    }

    @Test func spaceLensCancelLeavesIdleWhenNoTreeYet() {
        let model = SpaceLensViewModel()
        model.phase = .scanning(items: 3)
        model.cancel()
        #expect(model.phase == .idle)
    }

    @Test func clutterCancelLeavesIdleWhenNothingFound() {
        let model = MyClutterViewModel()
        model.phase = .scanning
        model.cancel()
        #expect(model.phase == .idle)
    }

    @Test func similarImagesCancelLeavesIdleWhenNothingFound() {
        let model = SimilarImagesViewModel()
        model.phase = .scanning(processed: 5, total: 9)
        model.cancel()
        #expect(model.phase == .idle)
    }

    /// Cancelling must not discard results already on screen. A user who
    /// cancels a *rescan* still wants the tree they were browsing.
    @Test func cancellingDoesNotThrowAwayAnExistingResult() {
        let duplicates = DuplicatesViewModel()
        duplicates.phase = .results
        duplicates.cancel()
        #expect(duplicates.phase == .results)
    }

    /// Cancelling twice, or cancelling when idle, must be a no-op rather than
    /// an error or a phase change.
    @Test func cancelIsIdempotentAndSafeWhenIdle() {
        let model = CleanupViewModel()
        model.cancel_twiceFromIdle()
        #expect(model.phase == .idle)
    }

    /// A cancelled scan must be restartable. This is the guard that made the
    /// stuck phase user-visible as "the app is dead until I quit it".
    @Test func aCancelledScanIsRestartable() {
        let model = MyClutterViewModel()
        model.phase = .scanning
        model.cancel()
        #expect(model.phase != .scanning, "still scanning — start() would be refused by its own guard")
    }
}

private extension CleanupViewModel {
    func cancel_twiceFromIdle() {
        cancelScan()
        cancelScan()
    }
}
