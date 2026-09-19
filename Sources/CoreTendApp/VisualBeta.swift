// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence

/// Turns a requested `VisualBetaFixture` on at launch.
///
/// Two things happen, in this order and no other: the synchronous seams
/// (volumes, permission state) are set before any view can read them, and the
/// store seeding is started as a task because `Store` is an actor. Setting the
/// seams first is what stops the first frame rendering real hardware and then
/// flipping to the scenario a moment later, which is visible in a capture.
enum VisualBeta {
    /// The scenario this launch is running, if any. Read by the harness so a
    /// capture's evidence file can name it.
    /// `nonisolated(unsafe)` rather than actor-isolated, deliberately: these
    /// are written exactly once, from `CoreTendApp.init`, before any window or
    /// task exists, and are read-only thereafter. Isolating them to the main
    /// actor would make them unreadable from `OverviewViewModel`'s nonisolated
    /// static helpers, which is where the volume seam is consumed.
    nonisolated(unsafe) private(set) static var active: VisualBetaFixture?

    static func activateIfRequested() {
        guard let fixture = VisualBetaFixture.requested() else { return }
        active = fixture

        OverviewFacts.fixtureVolumes = fixture.volumes
        OverviewFacts.fixtureDeniesFullDiskAccess = fixture.fullDiskAccessDenied

        // The store is opened by AppEnvironment on the main actor; seeding is
        // awaited off the launch path so a slow write cannot delay first paint.
        Task { @MainActor in
            guard let store = AppEnvironment.shared.store else { return }
            await fixture.seed(into: store)
            // The Overview and Record both load from the store in `.task`,
            // which may already have run against an empty table.
            NotificationCenter.default.post(name: .mcFixtureSeeded, object: nil)
        }
    }
}

extension Notification.Name {
    /// Posted once a Visual Beta scenario has finished writing its history, so
    /// a view that loaded before the seed landed reloads rather than showing
    /// an empty state the scenario did not ask for.
    static let mcFixtureSeeded = Notification.Name("mcFixtureSeeded")
}
