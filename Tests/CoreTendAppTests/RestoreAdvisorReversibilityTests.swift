// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
@testable import CoreTendApp

/// The real behavior that replaces the old "no mapping claims a Restore
/// Center that doesn't exist" guard: `.restorableByCoreTend` is produced
/// **only** when a restore manifest exists and its Trash item is currently
/// present, identity-checked, and its destination is clear — never merely
/// because CoreTend used the Trash.
@Suite("RestoreReversibility mapping")
struct RestoreAdvisorReversibilityTests {
    @Test func onlyLiveAvailabilityYieldsRestorableByCoreTend() {
        #expect(RestoreReversibility.of(.available) == .restorableByCoreTend)
    }

    @Test func everyBlockedOrUncheckableStateIsNotRestorableByCoreTend() {
        for availability: RestoreAvailability in [
            .destinationOccupied, .parentMissing, .parentNotWritable,
            .invalidIdentity, .volumeUnavailable, .alreadyRestored,
        ] {
            #expect(RestoreReversibility.of(availability) != .restorableByCoreTend,
                    "\(availability) must not claim built-in restoration")
            #expect(RestoreReversibility.of(availability) == .trash,
                    "the Trash item still exists, so Finder Put Back may still work")
        }
    }

    @Test func anEmptiedTrashIsHonestlyIrreversible() {
        // Nothing left for CoreTend or Finder to put back.
        #expect(RestoreReversibility.of(.missingFromTrash) == .irreversible)
    }

    @Test func everyAvailabilityCaseIsMapped() {
        // Compilation + total coverage: no case falls through to a default.
        for availability in [
            RestoreAvailability.available, .destinationOccupied, .parentMissing, .parentNotWritable,
            .missingFromTrash, .invalidIdentity, .volumeUnavailable, .alreadyRestored,
        ] {
            _ = RestoreReversibility.of(availability)
        }
    }
}
