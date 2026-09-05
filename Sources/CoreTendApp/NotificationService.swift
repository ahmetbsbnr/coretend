// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
@preconcurrency import UserNotifications
import Persistence
import DesignSystem

// MARK: - Categories

/// The local-notification kinds CoreTend can send. Each is independently
/// toggleable in Settings. There is deliberately no "a scan ran" category —
/// a notification fires only when it carries something worth acting on.
enum NotificationCategory: String, CaseIterable, Identifiable, Sendable {
    /// Free space fell below a fixed floor. Checked on launch and after a
    /// scheduled scan — never on a background poll.
    case lowDiskSpace
    /// A scheduled scan finished and found a meaningful amount of
    /// potentially recoverable space.
    case scanResults
    /// Tracked storage grew significantly since the previous comparable
    /// scan. Only known right after a scan produces a new Timeline
    /// snapshot, so it is delivered together with `scanResults`.
    case storageGrowth

    var id: String { rawValue }

    /// Which module a tap on this notification should open.
    var routeModule: ModuleID {
        switch self {
        case .lowDiskSpace: return .cleanup
        case .scanResults: return .cleanup
        case .storageGrowth: return .timeline
        }
    }

    var settingsTitleKey: String { "notif.category.\(rawValue).title" }
}

// MARK: - Thresholds & rate limiting (pure)

/// Every "is this worth a notification / are we allowed to send it yet"
/// decision, as pure functions — no `UNUserNotificationCenter`, no clock, no
/// store — so the policy is exhaustively testable.
enum NotificationPolicy {
    /// Free-space floor. Matches the menu-bar attention badge's 5 GB alarm
    /// point rather than inventing a second number.
    static let lowDiskFloorBytes: Int64 = 5_000_000_000
    /// A scheduled scan's reclaimable total must clear this before it is
    /// worth interrupting the user.
    static let meaningfulReclaimableBytes: Int64 = 1_000_000_000
    /// Growth since the previous comparable scan must clear this.
    static let significantGrowthBytes: Int64 = 5_000_000_000

    /// Minimum spacing between two notifications of the same category —
    /// stops "low space" firing after every scan and stops duplicate
    /// completion alerts.
    static func minimumInterval(for category: NotificationCategory) -> TimeInterval {
        switch category {
        case .lowDiskSpace: return 24 * 3600
        case .scanResults: return 12 * 3600
        case .storageGrowth: return 24 * 3600
        }
    }

    static func rateLimitAllows(category: NotificationCategory, lastFired: Date?, now: Date) -> Bool {
        guard let lastFired else { return true }
        return now.timeIntervalSince(lastFired) >= minimumInterval(for: category)
    }

    static func isLowDisk(freeBytes: Int64) -> Bool { freeBytes < lowDiskFloorBytes }
    static func isMeaningfulReclaimable(_ bytes: Int64) -> Bool { bytes >= meaningfulReclaimableBytes }
    static func isSignificantGrowth(_ bytes: Int64) -> Bool { bytes >= significantGrowthBytes }
}

// MARK: - Preferences

/// Per-category enable flags, backed by `UserDefaults` (the same mechanism
/// `@AppStorage` toggles use). Categories default to on: nothing is ever
/// delivered until the user has also granted notification permission, which
/// is requested only in context.
struct NotificationPreferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func key(_ c: NotificationCategory) -> String { "notif.enabled.\(c.rawValue)" }

    func isEnabled(_ c: NotificationCategory) -> Bool {
        defaults.object(forKey: key(c)) as? Bool ?? true
    }

    func setEnabled(_ enabled: Bool, for c: NotificationCategory) {
        defaults.set(enabled, forKey: key(c))
    }
}

// MARK: - Delivery abstraction

/// The slice of `UNUserNotificationCenter` the service needs, behind a
/// protocol so tests drive it without touching the real notification
/// centre.
protocol NotificationDelivering: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async -> UNAuthorizationStatus
    /// Posts a notification whose only payload is a module rawValue for the
    /// tap route. No file paths, names, or measurements beyond the body text.
    func post(identifier: String, title: String, body: String, routeModule: String) async
}

struct SystemNotificationDelivery: NotificationDelivering {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> UNAuthorizationStatus {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        return await authorizationStatus()
    }

    func post(identifier: String, title: String, body: String, routeModule: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["route": routeModule]
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Service

/// Owns every local notification CoreTend sends. `@MainActor` to match the
/// app's other service objects; the actual delivery hops to the background
/// via the async `NotificationDelivering`. Rate-limit timestamps are the
/// only state it persists (one `settings` row per category).
@MainActor
final class NotificationService {
    private let delivery: NotificationDelivering
    private let preferences: NotificationPreferences
    private let store: Store?
    private let now: () -> Date

    init(delivery: NotificationDelivering = SystemNotificationDelivery(),
         preferences: NotificationPreferences = NotificationPreferences(),
         store: Store? = AppEnvironment.shared.store,
         now: @escaping () -> Date = Date.init) {
        self.delivery = delivery
        self.preferences = preferences
        self.store = store
        self.now = now
    }

    // MARK: Permission

    func authorizationStatus() async -> UNAuthorizationStatus {
        await delivery.authorizationStatus()
    }

    /// Called only from an explicit user action (a Settings toggle / the
    /// onboarding opt-in) — never automatically at launch.
    func requestPermission() async -> UNAuthorizationStatus {
        await delivery.requestAuthorization()
    }

    func isEnabled(_ category: NotificationCategory) -> Bool { preferences.isEnabled(category) }
    func setEnabled(_ enabled: Bool, for category: NotificationCategory) {
        preferences.setEnabled(enabled, for: category)
    }

    // MARK: Triggers

    /// Fire-and-forget low-space check. Safe to call on every launch and
    /// after every scheduled scan; the 24 h rate limit does the debouncing.
    func checkLowDiskSpace(freeBytes: Int64) async {
        guard NotificationPolicy.isLowDisk(freeBytes: freeBytes) else { return }
        await fireIfAllowed(
            .lowDiskSpace,
            title: L("notif.low_disk.title"),
            body: L("notif.low_disk.body", mcFormatBytes(freeBytes)))
    }

    /// One coalesced notification for a completed scheduled scan. Combines
    /// "meaningful reclaimable" and "significant growth" into a single
    /// message rather than two, and only when at least one qualifies.
    func reportScheduledScan(reclaimableBytes: Int64, growthBytes: Int64?) async {
        let reclaimableQualifies = NotificationPolicy.isMeaningfulReclaimable(reclaimableBytes)
            && isEnabled(.scanResults)
        let growthQualifies = (growthBytes.map(NotificationPolicy.isSignificantGrowth) ?? false)
            && isEnabled(.storageGrowth)
        guard reclaimableQualifies || growthQualifies else { return }

        let lastScan = await lastFired(.scanResults)
        let lastGrowth = await lastFired(.storageGrowth)
        let scanAllowed = reclaimableQualifies
            && NotificationPolicy.rateLimitAllows(category: .scanResults, lastFired: lastScan, now: now())
        let growthAllowed = growthQualifies
            && NotificationPolicy.rateLimitAllows(category: .storageGrowth, lastFired: lastGrowth, now: now())
        guard scanAllowed || growthAllowed else { return }
        guard await authorizationStatus().isAuthorized else { return }

        var lines: [String] = []
        if scanAllowed { lines.append(L("notif.scan.reclaimable", mcFormatBytes(reclaimableBytes))) }
        if growthAllowed, let growthBytes { lines.append(L("notif.scan.growth", mcFormatBytes(growthBytes))) }

        // Route to Timeline when the story is "it grew", otherwise Cleanup.
        let route = growthAllowed && !scanAllowed ? NotificationCategory.storageGrowth.routeModule
                                                  : NotificationCategory.scanResults.routeModule
        await delivery.post(
            identifier: "coretend.scheduledScan.\(Int(now().timeIntervalSince1970))",
            title: L("notif.scan.title"),
            body: lines.joined(separator: " "),
            routeModule: route.rawValue)

        if scanAllowed { await stampFired(.scanResults) }
        if growthAllowed { await stampFired(.storageGrowth) }
    }

    // MARK: Internals

    private func fireIfAllowed(_ category: NotificationCategory, title: String, body: String) async {
        guard isEnabled(category) else { return }
        guard await authorizationStatus().isAuthorized else { return }
        let last = await lastFired(category)
        guard NotificationPolicy.rateLimitAllows(category: category, lastFired: last, now: now()) else { return }
        await delivery.post(
            identifier: "coretend.\(category.rawValue).\(Int(now().timeIntervalSince1970))",
            title: title, body: body, routeModule: category.routeModule.rawValue)
        await stampFired(category)
    }

    private func settingKey(_ c: NotificationCategory) -> String { "notif.lastFired.\(c.rawValue)" }

    private func lastFired(_ c: NotificationCategory) async -> Date? {
        guard let store, let raw = try? await store.setting(settingKey(c)), let t = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    private func stampFired(_ c: NotificationCategory) async {
        try? await store?.setSetting(settingKey(c), value: String(now().timeIntervalSince1970))
    }
}

extension UNAuthorizationStatus {
    var isAuthorized: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }
}

// MARK: - Tap routing

/// Routes a notification tap to the module named in its `userInfo`. Set as
/// `UNUserNotificationCenter.current().delegate` once at launch. The only
/// value it reads is a `ModuleID` rawValue.
final class NotificationTapRouter: NSObject, UNUserNotificationCenterDelegate {
    /// Pure: the module a notification's `userInfo` points at, or nil. The
    /// only key read is `"route"` (a `ModuleID` rawValue).
    static func module(from userInfo: [AnyHashable: Any]) -> ModuleID? {
        (userInfo["route"] as? String).flatMap(ModuleID.init(rawValue:))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let module = Self.module(from: response.notification.request.content.userInfo) else { return }
        await MainActor.run { AppRouter.shared.route(to: .module(module)) }
    }

    /// Show CoreTend's notifications even while it is frontmost.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }
}
