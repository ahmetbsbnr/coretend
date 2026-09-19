// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// The Overview's attention list only exists when something needs a person.
///
/// A summary screen that always has a row to show is a screen nobody reads —
/// the row becomes furniture. Each case here is a thing the person can act on,
/// and "everything is fine" is an empty list, not a green tick.
@Suite("Overview says nothing when there is nothing to say")
@MainActor
struct OverviewAttentionTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// Calendar arithmetic, not 86 400 × n.
    ///
    /// Subtracting seconds across a clock change lands on the wrong calendar
    /// day — thirty days before 14 November in Paris is 16 October by that
    /// arithmetic, which is 29 days. The screen counts midnight to midnight,
    /// because that is what a person means by "N days ago", so the test has to
    /// ask the same question.
    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: now)!
    }

    @Test func aHealthyMacProducesNoRows() {
        #expect(OverviewViewModel.attentionRows(
            fullDisk: .granted, brokenLoginItems: 0, lastScan: daysAgo(1), now: now).isEmpty)
    }

    @Test func aMissingGrantIsListed() {
        for grant in [SystemAuthorization.Grant.denied, .undetermined] {
            let rows = OverviewViewModel.attentionRows(
                fullDisk: grant, brokenLoginItems: 0, lastScan: daysAgo(1), now: now)
            #expect(rows == [.fullDiskAccessMissing])
        }
    }

    /// `.notApplicable` is the App Store build, where the grant is not a thing
    /// the person can give. Asking them for it would be asking for something
    /// that does not exist.
    @Test func aGrantThatCannotBeGivenIsNotAskedFor() {
        #expect(OverviewViewModel.attentionRows(
            fullDisk: .notApplicable, brokenLoginItems: 0, lastScan: daysAgo(1), now: now).isEmpty)
    }

    @Test func neverScannedOutranksStale() {
        let rows = OverviewViewModel.attentionRows(
            fullDisk: .granted, brokenLoginItems: 0, lastScan: nil, now: now)
        #expect(rows == [.neverScanned])
    }

    /// Six days is not worth a row; seven is. The boundary is the whole
    /// decision, so it is the thing tested.
    @Test func stalenessStartsAtAWeek() {
        #expect(OverviewViewModel.attentionRows(
            fullDisk: .granted, brokenLoginItems: 0, lastScan: daysAgo(6), now: now).isEmpty)
        #expect(OverviewViewModel.attentionRows(
            fullDisk: .granted, brokenLoginItems: 0, lastScan: daysAgo(7), now: now)
                == [.scansAreStale(days: 7)])
    }

    @Test func brokenLoginItemsAreCounted() {
        let rows = OverviewViewModel.attentionRows(
            fullDisk: .granted, brokenLoginItems: 3, lastScan: daysAgo(1), now: now)
        #expect(rows == [.brokenLoginItems(3)])
    }

    /// Several at once, in the order the screen shows them: what blocks the
    /// app first, then what is broken, then what is merely old.
    @Test func rowsKeepTheirOrder() {
        let rows = OverviewViewModel.attentionRows(
            fullDisk: .denied, brokenLoginItems: 2, lastScan: daysAgo(30), now: now)
        #expect(rows == [.fullDiskAccessMissing, .brokenLoginItems(2), .scansAreStale(days: 30)])
    }
}
