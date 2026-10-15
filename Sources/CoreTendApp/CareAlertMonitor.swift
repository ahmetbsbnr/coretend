import AppKit
import AppShell
import Domain
import UserNotifications

/// Checks the disk, the Trash and trashed apps once an hour while CoreTend runs (window or menu
/// bar), and posts a local notification for each alert that is due. Only when the person turned
/// alerts on; never in fixtures; nothing leaves the Mac.
@MainActor
final class CareAlertMonitor: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CareAlertMonitor()

    private var task: Task<Void, Never>?
    private let policy = CareAlertPolicy()

    /// macOS refuses notification APIs to a process without a bundle (a bare `swift run`).
    private var canNotify: Bool { Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app" }

    func start() {
        guard task == nil, canNotify, CoreTendPreferences().usesPersistentStorage else { return }
        UNUserNotificationCenter.current().delegate = self
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check()
                try? await Task.sleep(for: .seconds(60 * 60))
            }
        }
    }

    /// Asks macOS for permission when the person turns alerts on.
    func requestPermission() async -> Bool {
        guard canNotify else { return false }
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func check(now: Date = .now) async {
        let preferences = CoreTendPreferences()
        guard preferences.alertsEnabled, canNotify else { return }
        let home = HomeFolder.url
        let reading = await Task.detached(priority: .utility) {
            let snapshot = MacOSSystemSnapshotReader().read()
            let free: Int64? = if case .known(let value) = snapshot.availableBytes { value } else { nil }
            let total: Int64? = if case .known(let value) = snapshot.totalBytes { value } else { nil }
            let trashed = TrashedAppFinder(home: home, isInstalledElsewhere: CareAlertMonitor.isInstalledElsewhere).find()
            return CareAlertReading(freeBytes: free, totalBytes: total, trashBytes: TrashMeasure.bytes(home: home),
                                    trashedAppsWithLeftovers: trashed.count)
        }.value
        let lastShown = Dictionary(uniqueKeysWithValues: preferences.alertsLastShown.compactMap { key, date in
            CareAlert(rawValue: key).map { ($0, date) }
        })
        for alert in policy.due(reading, lastShown: lastShown, now: now) {
            await post(alert, reading: reading)
            preferences.saveAlertShown(alert.rawValue, at: now)
        }
    }

    private func post(_ alert: CareAlert, reading: CareAlertReading) async {
        let french = AppLanguage.usesFrench(CoreTendPreferences().language)
        let content = UNMutableNotificationContent()
        content.title = ProductCopy.value(for: "alerts.\(alert.rawValue).title", french: french)
        let detail: String
        switch alert {
        case .lowDiskSpace: detail = ProductFormat.bytes(reading.freeBytes ?? 0, french: french)
        case .heavyTrash: detail = ProductFormat.bytes(reading.trashBytes ?? 0, french: french)
        case .trashedAppLeftovers: detail = "\(reading.trashedAppsWithLeftovers)"
        }
        content.body = String(format: ProductCopy.value(for: "alerts.\(alert.rawValue).body", french: french), detail)
        content.userInfo = ["destination": alert == .trashedAppLeftovers ? Destination.apps.rawValue : Destination.home.rawValue]
        let request = UNNotificationRequest(identifier: "coretend.\(alert.rawValue)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Another copy of the app, outside any Trash, still uses the same identifier.
    nonisolated static func isInstalledElsewhere(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleIdentifier)
            .contains { !$0.path.contains("/.Trash/") && !$0.path.contains("/.Trashes/") }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let destination = response.notification.request.content.userInfo["destination"] as? String
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .coreTendOpenDestination, object: destination)
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
