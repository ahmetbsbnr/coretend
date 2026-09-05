// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppKit
import Foundation

/// Where an external trigger (a notification tap, an App Intent) wants the
/// app to land. Deliberately small — a module is the only destination the
/// integration layer needs today — but an enum so a future "open Recovery
/// Plan with goal X" can extend it without a second router.
enum AppRoute: Equatable, Sendable {
    case module(ModuleID)
}

/// The single deep-link entry point, shared by notifications and App
/// Intents. It reuses the existing `.mcNavigate` `NotificationCenter`
/// routing that the sidebar, command palette and Help menu already use —
/// this is not a second navigation system, only a front door that also
/// handles the cold-launch race (a route posted before `MainWindow` has
/// subscribed to `.mcNavigate`).
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    /// Set when a route arrives before a receiver is ready; `MainWindow`
    /// drains it in `onAppear`. Never carries a file path or any payload
    /// beyond a `ModuleID`.
    private(set) var pendingRoute: AppRoute?
    private var receiverReady = false

    private init() {}

    /// Route now if the window is up, otherwise buffer for cold launch.
    /// Always brings the app and its main window forward first, so a
    /// notification tap works whether the app was frontmost, backgrounded,
    /// menu-bar-only, or launched fresh.
    func route(to route: AppRoute) {
        activateMainWindow()
        if receiverReady {
            deliver(route)
        } else {
            pendingRoute = route
        }
    }

    /// `MainWindow` calls this once on screen. Returns whatever route was
    /// buffered during a cold launch (or nil).
    @discardableResult
    func markReceiverReady() -> AppRoute? {
        receiverReady = true
        defer { pendingRoute = nil }
        return pendingRoute
    }

    /// Test seam: reset the one-shot readiness/buffer between cases.
    func resetForTesting() {
        receiverReady = false
        pendingRoute = nil
    }

    private func deliver(_ route: AppRoute) {
        switch route {
        case let .module(module):
            NotificationCenter.default.post(name: .mcNavigate, object: module)
        }
    }

    private func activateMainWindow() {
        // `NSApplication.shared` (not `NSApp`, which is a nil IUO until the
        // app's run loop starts) so this is safe to call from any context,
        // including a headless test process.
        let app = NSApplication.shared
        app.activate(ignoringOtherApps: true)
        app.windows.first { $0.title == "CoreTend" }?.makeKeyAndOrderFront(nil)
    }
}
