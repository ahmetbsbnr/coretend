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

    // MARK: - Finder payload routes (URL carried alongside the module)

    @Test func aFinderPayloadRouteBuffersTheModuleAndYieldsItsURLExactlyOnce() throws {
        AppRouter.shared.resetForTesting()
        let img = FileManager.default.temporaryDirectory.appendingPathComponent("router-\(UUID()).jpg")
        try Data().write(to: img)
        defer { try? FileManager.default.removeItem(at: img) }

        AppRouter.shared.route(to: .inspectImage(img))
        #expect(AppRouter.shared.pendingRoute == .inspectImage(img))
        #expect(AppRouter.module(for: .inspectImage(img)) == .privacyLab)

        // The destination view consumes the URL on appear — once.
        #expect(AppRouter.shared.consumePendingImageInspectionURL() == img)
        #expect(AppRouter.shared.consumePendingImageInspectionURL() == nil)

        // Draining the module route is still one-shot.
        #expect(AppRouter.shared.markReceiverReady() == .module(.privacyLab))
        #expect(AppRouter.shared.markReceiverReady() == nil)
        AppRouter.shared.resetForTesting()
    }

    @Test func aWarmFinderRoutePostsNavigateThenThePayloadNotification() {
        AppRouter.shared.resetForTesting()
        _ = AppRouter.shared.markReceiverReady()

        var nav: [ModuleID] = []
        var appURLs: [URL] = []
        let o1 = NotificationCenter.default.addObserver(forName: .mcNavigate, object: nil, queue: nil) {
            if let m = $0.object as? ModuleID { nav.append(m) }
        }
        let o2 = NotificationCenter.default.addObserver(forName: .mcInspectApplicationAt, object: nil, queue: nil) {
            if let u = $0.object as? URL { appURLs.append(u) }
        }
        defer { NotificationCenter.default.removeObserver(o1); NotificationCenter.default.removeObserver(o2) }

        let app = URL(fileURLWithPath: "/Applications/Demo.app")
        AppRouter.shared.route(to: .inspectApplication(app))

        #expect(nav == [.protection])
        #expect(appURLs == [app])
        #expect(AppRouter.shared.pendingRoute == nil)
        AppRouter.shared.resetForTesting()
    }

    @Test func resetForTestingClearsBufferedPayloads() {
        AppRouter.shared.resetForTesting()
        AppRouter.shared.route(to: .scanFolder(URL(fileURLWithPath: "/private/tmp/x")))
        AppRouter.shared.resetForTesting()
        #expect(AppRouter.shared.pendingRoute == nil)
        #expect(AppRouter.shared.consumePendingFolderScanURL() == nil)
    }
}
