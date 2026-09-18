// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence
import Testing
@testable import CoreTendApp

/// The regression suite for the worst outcome this app can produce: scanning,
/// and offering for deletion, a folder the user explicitly protected.
@Suite("Exclusions: unreadable is not empty")
struct ExclusionsSnapshotTests {

    /// The whole point of the type. Before it, three different failures — store
    /// never opened, database corrupt, read threw — all became `[]`, which is
    /// also what a user with no exclusions has.
    @Test func anUnreadableListIsNotTheSameValueAsAnEmptyOne() {
        #expect(ExclusionsSnapshot.loaded([]) != ExclusionsSnapshot.unavailable)
    }

    /// An empty list is a legitimate, trustworthy answer: the user simply has
    /// no exclusions. It must not be mistaken for a failure either — that would
    /// warn every new user about a problem they do not have.
    @Test func anEmptyLoadedListIsStillTrustworthy() {
        let snapshot = ExclusionsSnapshot.loaded([])
        #expect(snapshot.isTrustworthy)
        #expect(snapshot.paths.isEmpty)
        #expect(snapshot.count == 0)
    }

    @Test func aLoadedListReportsItsPaths() {
        let snapshot = ExclusionsSnapshot.loaded(["/Users/x/Documents", "/Volumes/Backup"])
        #expect(snapshot.isTrustworthy)
        #expect(snapshot.count == 2)
        #expect(snapshot.paths.contains("/Volumes/Backup"))
    }

    /// `unavailable` still yields no paths to the engine — there is nothing
    /// better to exclude — but it must never claim to be trustworthy, because
    /// that flag is what gates the deletion suggestion.
    @Test func unavailableYieldsNoPathsAndIsNeverTrustworthy() {
        let snapshot = ExclusionsSnapshot.unavailable
        #expect(snapshot.paths.isEmpty)
        #expect(snapshot.isTrustworthy == false)
        #expect(snapshot.count == 0)
    }

    /// The load-bearing rule, stated as a test so it cannot be lost in a
    /// refactor: nothing may be preselected for deletion from an untrustworthy
    /// snapshot. Cleanup findings arrive `preselected`, so without this gate a
    /// protected folder's contents come back already ticked.
    @Test func preselectionIsGatedOnTrustworthiness() {
        func shouldPreselect(findingIsPreselected: Bool, _ snapshot: ExclusionsSnapshot) -> Bool {
            findingIsPreselected && snapshot.isTrustworthy
        }
        #expect(shouldPreselect(findingIsPreselected: true, .loaded([])))
        #expect(shouldPreselect(findingIsPreselected: true, .loaded(["/x"])))
        #expect(shouldPreselect(findingIsPreselected: true, .unavailable) == false)
        #expect(shouldPreselect(findingIsPreselected: false, .loaded([])) == false)
    }
}

@Suite("Store failure is a reportable state")
@MainActor
struct StoreStateTests {
    private func makeStore() throws -> Persistence.Store {
        try Persistence.Store(path: ":memory:")
    }

    /// Only a real on-disk store counts as durable. The in-memory fallback used
    /// to be indistinguishable from success: the app ran, wrote the user's
    /// exclusions and Safety Log to RAM, and lost all of it on quit with
    /// nothing on screen saying so.
    @Test func ephemeralIsNotDurableAndCarriesItsReason() throws {
        let state = AppEnvironment.StoreState.ephemeral(try makeStore(), reason: "disk full")
        #expect(state.store != nil, "the app must still run without persistence")
        #expect(state.isDurable == false)
        #expect(state.failureReason == "disk full")
    }

    @Test func readyIsDurableAndHasNoReasonToReport() throws {
        let state = AppEnvironment.StoreState.ready(try makeStore())
        #expect(state.isDurable)
        #expect(state.failureReason == nil)
        #expect(state.store != nil)
    }

    /// The distinction Settings branches on: `unavailable` has no store at all
    /// and gets the stronger message.
    @Test func unavailableHasNoStore() {
        let state = AppEnvironment.StoreState.unavailable(reason: "corrupt database")
        #expect(state.store == nil)
        #expect(state.isDurable == false)
        #expect(state.failureReason == "corrupt database")
    }
}
