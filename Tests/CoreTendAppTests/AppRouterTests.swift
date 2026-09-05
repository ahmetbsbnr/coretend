// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import CoreTendApp

@Suite("AppRouter — cold-launch buffering & warm delivery")
@MainActor
struct AppRouterTests {
    @Test func aRouteArrivingBeforeTheWindowIsBufferedThenDrainedOnce() {
        AppRouter.shared.resetForTesting()
        AppRouter.shared.route(to: .module(.timeline))
        #expect(AppRouter.shared.pendingRoute == .module(.timeline), "cold launch: buffered")

        let drained = AppRouter.shared.markReceiverReady()
        #expect(drained == .module(.timeline))
        #expect(AppRouter.shared.pendingRoute == nil, "drained exactly once")

        // A second drain returns nothing.
        #expect(AppRouter.shared.markReceiverReady() == nil)
        AppRouter.shared.resetForTesting()
    }

    @Test func afterTheReceiverIsReadyARouteIsDeliveredNotBuffered() {
        AppRouter.shared.resetForTesting()
        _ = AppRouter.shared.markReceiverReady()

        var received: ModuleID?
        let observer = NotificationCenter.default.addObserver(
            forName: .mcNavigate, object: nil, queue: nil) { note in
            received = note.object as? ModuleID
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        AppRouter.shared.route(to: .module(.restoreCenter))
        #expect(received == .restoreCenter)
        #expect(AppRouter.shared.pendingRoute == nil, "warm: delivered, not buffered")
        AppRouter.shared.resetForTesting()
    }
}
