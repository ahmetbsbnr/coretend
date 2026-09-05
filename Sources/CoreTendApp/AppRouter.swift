// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppKit
import Foundation
import FinderShared

/// Where an external trigger (a notification tap, an App Intent, a Finder
/// Sync menu action) wants the app to land.
///
/// `.module` carries only a `ModuleID` — no payload. The three Finder cases
/// carry one already-validated `file:` URL (the host's `FinderHandoff` runs
/// `SelectionValidator` against the live filesystem *before* constructing
/// one of these). Each Finder case maps to an existing read-only CoreTend
/// screen; none can delete, clean, trash, restore, or uninstall.
enum AppRoute: Equatable, Sendable {
    case module(ModuleID)
    case scanFolder(URL)
    case inspectImage(URL)
    case inspectApplication(URL)
}

/// The single deep-link entry point, shared by notifications, App Intents
/// and the Finder Sync extension. It reuses the existing `.mcNavigate`
/// `NotificationCenter` routing that the sidebar, command palette and Help
/// menu already use — this is not a second navigation system, only a front
/// door that also handles the cold-launch race (a route arriving before
/// `MainWindow` has subscribed to `.mcNavigate`).
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    /// Set when a route arrives before a receiver is ready; `MainWindow`
    /// drains it in `onAppear`.
    private(set) var pendingRoute: AppRoute?
    private var receiverReady = false
    var finderSelectionRejected = false
    var openMainWindow: (() -> Void)?

    /// Consume-once URL payloads for a Finder route. The destination view
    /// pulls its own payload in `onAppear` (covers cold launch and the case
    /// where the view is not mounted yet); a mounted view instead reacts to
    /// the matching notification. Either way the URL is delivered exactly
    /// once — see `consume…`.
    private(set) var pendingFolderScanURL: URL?
    private(set) var pendingImageInspectionURL: URL?
    private(set) var pendingApplicationInspectionURL: URL?

    private init() {}

    /// Route now if the window is up, otherwise buffer for cold launch.
    /// Always brings the app and its main window forward first, so the
    /// trigger works whether the app was frontmost, backgrounded,
    /// menu-bar-only, or launched fresh.
    func route(to route: AppRoute) {
        pendingFolderScanURL = nil
        pendingImageInspectionURL = nil
        pendingApplicationInspectionURL = nil
        activateMainWindow()
        // Stash any URL payload up front, so a destination view that is
        // about to mount can pull it in `onAppear` regardless of timing.
        switch route {
        case .module: break
        case let .scanFolder(url): pendingFolderScanURL = url
        case let .inspectImage(url): pendingImageInspectionURL = url
        case let .inspectApplication(url): pendingApplicationInspectionURL = url
        }
        if receiverReady {
            deliver(route)
        } else {
            pendingRoute = route
        }
    }

    /// `MainWindow` calls this once on screen. Returns whatever route was
    /// buffered during a cold launch (or nil). The caller switches the
    /// sidebar selection; any URL payload is left for the destination view
    /// to consume.
    @discardableResult
    func markReceiverReady() -> AppRoute? {
        receiverReady = true
        defer { pendingRoute = nil }
        return pendingRoute
    }

    func markReceiverUnavailable() {
        receiverReady = false
    }

    func consumePendingFolderScanURL() -> URL? {
        guard let url = pendingFolderScanURL else { return nil }
        pendingFolderScanURL = nil
        if let route = pendingRoute { pendingRoute = .module(Self.module(for: route)) }
        guard url.isFileURL,
              case let .success(validated) = SelectionValidator.validate(path: url.path, for: .scanFolder) else {
            finderSelectionRejected = true
            return nil
        }
        return validated
    }

    func consumePendingImageInspectionURL() -> URL? {
        guard let url = pendingImageInspectionURL else { return nil }
        pendingImageInspectionURL = nil
        if let route = pendingRoute { pendingRoute = .module(Self.module(for: route)) }
        guard url.isFileURL,
              case let .success(validated) = SelectionValidator.validate(path: url.path, for: .inspectImage) else {
            finderSelectionRejected = true
            return nil
        }
        return validated
    }

    func consumePendingApplicationInspectionURL() -> URL? {
        guard let url = pendingApplicationInspectionURL else { return nil }
        pendingApplicationInspectionURL = nil
        if let route = pendingRoute { pendingRoute = .module(Self.module(for: route)) }
        guard url.isFileURL,
              case let .success(validated) = SelectionValidator.validate(path: url.path, for: .inspectApplication) else {
            finderSelectionRejected = true
            return nil
        }
        return validated
    }

    /// Test seam: reset the one-shot readiness / buffers between cases.
    func resetForTesting() {
        receiverReady = false
        finderSelectionRejected = false
        openMainWindow = nil
        pendingRoute = nil
        pendingFolderScanURL = nil
        pendingImageInspectionURL = nil
        pendingApplicationInspectionURL = nil
    }

    /// The sidebar module a route lands on.
    static func module(for route: AppRoute) -> ModuleID {
        switch route {
        case let .module(module): return module
        case .scanFolder: return .spaceLens
        case .inspectImage: return .privacyLab
        case .inspectApplication: return .protection
        }
    }

    private func deliver(_ route: AppRoute) {
        NotificationCenter.default.post(name: .mcNavigate, object: Self.module(for: route))
        // Warm path: if the destination view is already mounted it will not
        // fire `onAppear`, so nudge it with the payload notification too.
        // (The stashed URL above is the backup for a not-yet-mounted view.)
        switch route {
        case .module:
            break
        case let .scanFolder(url):
            NotificationCenter.default.post(name: .mcOpenSpaceLensAt, object: url, userInfo: ["finder": true])
        case let .inspectImage(url):
            NotificationCenter.default.post(name: .mcInspectImageAt, object: url)
        case let .inspectApplication(url):
            NotificationCenter.default.post(name: .mcInspectApplicationAt, object: url)
        }
    }

    private func activateMainWindow() {
        // `NSApplication.shared` (not `NSApp`, which is a nil IUO until the
        // app's run loop starts) so this is safe to call from any context,
        // including a headless test process.
        let app = NSApplication.shared
        app.activate(ignoringOtherApps: true)
        if let window = app.windows.first(where: { $0.title == "CoreTend" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
    }
}

extension Notification.Name {
    /// Carries a `URL` (an image file) — "switch to Privacy Lab and inspect
    /// this". Distinct from `.mcNavigate` (which only ever carries a
    /// `ModuleID`), mirroring `.mcOpenSpaceLensAt`.
    static let mcInspectImageAt = Notification.Name("mc.inspectImageAt")
    /// Carries a `URL` (an `.app` bundle) — "switch to Protection ▸ Integrity
    /// and inspect this application's signature".
    static let mcInspectApplicationAt = Notification.Name("mc.inspectApplicationAt")
}
