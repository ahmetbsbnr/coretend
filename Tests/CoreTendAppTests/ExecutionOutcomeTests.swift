// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import CoreTendApp

@Suite("Partial failure is reported, not discarded")
struct ExecutionOutcomeTests {

    @Test("a clean run shows no skip message at all")
    func cleanRunIsQuiet() {
        // "0 skipped" on every successful cleanup is noise, and noise is what
        // makes the one run that did skip something invisible.
        let outcome = ExecutionOutcome(executedCount: 12, skippedCount: 0, freedBytes: 4_096)
        #expect(outcome.hasSkips == false)
        #expect(outcome.message == nil)
    }

    @Test("a run with skips says so, and says how many")
    func skipsAreSurfaced() {
        let outcome = ExecutionOutcome(executedCount: 7, skippedCount: 3, freedBytes: 1_024)
        #expect(outcome.hasSkips)
        #expect(outcome.message?.contains("3") == true)
    }

    @Test("a run where everything was skipped is not dressed up as success")
    func totalFailureStillReportsSkips() {
        // SpaceLens executes a single operation, so this is its normal failure
        // shape: nothing moved, nothing freed, and the screen used to stay
        // silent about it.
        let outcome = ExecutionOutcome(executedCount: 0, skippedCount: 1, freedBytes: 0)
        #expect(outcome.executedCount == 0)
        #expect(outcome.hasSkips)
        #expect(outcome.message != nil)
    }

    @Test("the activity summary is left alone when nothing was skipped")
    func annotationIsAbsentOnCleanRuns() {
        let outcome = ExecutionOutcome(executedCount: 5, skippedCount: 0, freedBytes: 10)
        #expect(outcome.annotate("Moved 5 items to Trash") == "Moved 5 items to Trash")
    }

    @Test("the activity summary carries the skip count when there was one")
    func annotationRecordsSkips() {
        // A record read months later should not require knowing that an absent
        // number meant zero — when it is not zero, it is written down.
        let outcome = ExecutionOutcome(executedCount: 5, skippedCount: 2, freedBytes: 10)
        let summary = outcome.annotate("Moved 5 items to Trash")
        #expect(summary.contains("Moved 5 items to Trash"))
        #expect(summary.contains("2"))
        #expect(summary != "Moved 5 items to Trash")
    }

    @Test("freed bytes count only what actually moved")
    func freedBytesExcludeSkipped() {
        // The headline number is what the user got back. Counting skipped
        // sizes into it would overstate the result of a partial run.
        let outcome = ExecutionOutcome(executedCount: 1, skippedCount: 9, freedBytes: 512)
        #expect(outcome.freedBytes == 512)
    }

    @Test("the title reports freed space regardless of skips")
    func titleAlwaysPresent() {
        for skipped in [0, 4] {
            let outcome = ExecutionOutcome(executedCount: 3, skippedCount: skipped, freedBytes: 2_048)
            #expect(!outcome.title.isEmpty)
        }
    }

    @Test("two outcomes with the same numbers are equal")
    func equatableByValue() {
        // Phase is Equatable, and SwiftUI relies on that to decide whether the
        // done state changed.
        let a = ExecutionOutcome(executedCount: 2, skippedCount: 1, freedBytes: 8)
        let b = ExecutionOutcome(executedCount: 2, skippedCount: 1, freedBytes: 8)
        let c = ExecutionOutcome(executedCount: 2, skippedCount: 0, freedBytes: 8)
        #expect(a == b)
        #expect(a != c)
    }
}
