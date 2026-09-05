// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SwiftUI
import Persistence
@preconcurrency import UserNotifications
import SystemMetrics
import FileRules

/// The app-lifecycle glue for the macOS integration layer: it owns the
/// background scan scheduler, wires a completed scheduled scan to the
/// notification service, installs the notification tap-router delegate, and
/// exposes the cadence to Settings. One instance, created at launch.
///
/// It does not scan or notify itself — it sequences `ScheduledScanService`
/// (an actor, off the main actor) and `NotificationService`.
@MainActor
@Observable
final class MacIntegrations {
    static let shared = MacIntegrations()

    /// Persisted cadence choice. `Settings` binds to this through
    /// `cadenceBinding`; changing it reschedules immediately.
    private(set) var cadence: ScanCadence

    private let scheduler: BackgroundScheduling
    private let scanService: ScheduledScanService
    let notifications: NotificationService
    private let metrics = MetricsCollector()
    private let tapRouter = NotificationTapRouter()
    private var runningScan: Task<Void, Never>?

    /// A no-op scheduler under the isolated test marker: a test launching the
    /// real app must not register a real `NSBackgroundActivityScheduler`.
    private static func defaultScheduler() -> BackgroundScheduling {
        if TestStoreOverride.isTestMarkerSet(environment: ProcessInfo.processInfo.environment) {
            return InertBackgroundScheduler()
        }
        return SystemBackgroundScheduler()
    }

    init(scheduler: BackgroundScheduling? = nil,
         scanService: ScheduledScanService? = nil,
         notifications: NotificationService? = nil,
         cadence: ScanCadence? = nil) {
        self.scheduler = scheduler ?? Self.defaultScheduler()
        self.scanService = scanService ?? ScheduledScanService(store: AppEnvironment.shared.store)
        self.notifications = notifications ?? NotificationService()
        let stored = UserDefaults.standard.string(forKey: Self.cadenceKey)
        self.cadence = cadence ?? ScanCadence(rawValue: stored ?? "") ?? .off
    }

    static let cadenceKey = "schedule.cadence"
    private var started = false

    // MARK: Launch

    /// Called from `MainWindow.onAppear`; safe to call more than once.
    func start() {
        guard !started else { return }
        started = true
        UNUserNotificationCenter.current().delegate = tapRouter
        applyCadence(cadence)
        Task { await self.checkLowDiskSpaceOnce() }
        // Refresh the Widget snapshot from current numbers at launch.
        AppEnvironment.shared.publishWidgetSnapshot()
    }

    private func checkLowDiskSpaceOnce() async {
        let snapshot = await metrics.snapshot()
        await notifications.checkLowDiskSpace(freeBytes: snapshot.diskFreeBytes)
    }

    // MARK: Cadence

    func cadenceBinding() -> Binding<ScanCadence> {
        Binding(get: { self.cadence }, set: { self.setCadence($0) })
    }

    func setCadence(_ new: ScanCadence) {
        cadence = new
        UserDefaults.standard.set(new.rawValue, forKey: Self.cadenceKey)
        applyCadence(new)
    }

    private func applyCadence(_ cadence: ScanCadence) {
        runningScan?.cancel()
        runningScan = nil
        guard let interval = cadence.interval else {
            scheduler.invalidate()
            return
        }
        scheduler.schedule(identifier: "com.ahmetbsbnr.coretend.scheduledScan",
                           interval: interval, tolerance: cadence.tolerance) { [weak self] finished in
            // Runs on a background queue. Hop to the main actor to own the
            // task, then always call `finished` so the system marks the
            // activity complete even on cancel/failure.
            Task { @MainActor in
                await self?.runScheduledScan()
                finished()
            }
        }
    }

    // MARK: Run

    /// Runs one scheduled scan and, if it actually completed with something
    /// worth surfacing, sends a single coalesced notification. Serialized:
    /// a second call while one is running is dropped by the service's own
    /// `inProgress` guard.
    @discardableResult
    func runScheduledScan() async -> ScheduledScanResult {
        let task = Task<ScheduledScanResult, Never> { [scanService] in
            await scanService.run(rules: UserCleanupRules.all)
        }
        runningScan = Task { _ = await task.value }
        let result = await task.value
        runningScan = nil

        if case let .completed(reclaimable, growth) = result {
            await notifications.reportScheduledScan(reclaimableBytes: reclaimable, growthBytes: growth)
            let snapshot = await metrics.snapshot()
            await notifications.checkLowDiskSpace(freeBytes: snapshot.diskFreeBytes)
            // The scheduled scan wrote a fresh cleanup Timeline snapshot
            // directly (not via AppEnvironment) — refresh the widget now.
            AppEnvironment.shared.publishWidgetSnapshot()
        }
        return result
    }
}

/// A `BackgroundScheduling` that does nothing — used under the test marker so
/// launching the packaged app in a smoke test registers no real activity.
final class InertBackgroundScheduler: BackgroundScheduling {
    func schedule(identifier: String, interval: TimeInterval, tolerance: TimeInterval,
                  operation: @escaping @Sendable (@escaping @Sendable () -> Void) -> Void) {}
    func invalidate() {}
}
