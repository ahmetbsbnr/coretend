// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Observation

/// App-scope owner of a Smart Scan run.
///
/// Held by `MainWindow` (not by `DashboardView`), so it outlives the
/// Dashboard being torn down and rebuilt as the user navigates the sidebar:
/// a scan started from the Dashboard keeps running while the user is on
/// another screen, and returning shows its current / completed / cancelled
/// state without restarting it.
///
/// It coordinates — it never deletes. The only action it offers past a
/// result is a handoff into the existing Recovery Plan screen.
@MainActor
@Observable
final class SmartScanModel {
    enum Phase: Equatable {
        case idle
        case running
        case completed
        case cancelled
    }

    private(set) var phase: Phase = .idle
    /// Live per-module states, refreshed while a run is in progress.
    private(set) var modules: [SmartScanModuleID: SmartScanModuleState] = [:]
    /// The most recent full report. Set only when a run finishes (completed
    /// or cancelled) — a cancelled report has `wasCancelled == true` and must
    /// not be treated as a finished scan by anything downstream.
    private(set) var report: SmartScanReport?
    private(set) var elapsed: TimeInterval = 0

    var isRunning: Bool { phase == .running }
    /// True only for a genuinely finished, non-cancelled run.
    var hasCompletedReport: Bool {
        phase == .completed && report?.wasCancelled == false
    }

    @ObservationIgnored private let coordinator: SmartScanCoordinator
    @ObservationIgnored private var driver: Task<Void, Never>?
    @ObservationIgnored private var startedAt: Date?
    /// Injected so tests can drive elapsed time deterministically.
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let pollInterval: Duration

    init(coordinator: SmartScanCoordinator? = nil,
         now: @Sendable @escaping () -> Date = Date.init,
         pollInterval: Duration = .milliseconds(250)) {
        self.coordinator = coordinator ?? SmartScanCoordinator(providers: SmartScanProviders.live())
        self.now = now
        self.pollInterval = pollInterval
    }

    /// Start a run. A no-op if one is already in progress — never launches a
    /// duplicate scan.
    func start() {
        guard phase != .running else { return }
        phase = .running
        report = nil
        elapsed = 0
        startedAt = now()
        modules = Dictionary(uniqueKeysWithValues: SmartScanModuleID.allCases.map { ($0, .queued) })

        driver = Task { [coordinator] in
            let runTask = await coordinator.start()
            // Refresh the live snapshot on an interval until the run resolves.
            // (This Task inherits MainActor isolation from the class.)
            while await coordinator.isRunning {
                self.modules = await coordinator.report.modules
                self.tickElapsed()
                try? await Task.sleep(for: self.pollInterval)
            }
            let final = await runTask.value
            self.modules = final.modules
            self.report = final
            self.tickElapsed()
            self.phase = final.wasCancelled ? .cancelled : .completed
            self.driver = nil
        }
    }

    private func tickElapsed() {
        if let started = startedAt { elapsed = now().timeIntervalSince(started) }
    }

    /// Cancel a running scan. Propagates to every provider; the resulting
    /// report is a partial, `wasCancelled` snapshot — no success state.
    func cancel() {
        guard phase == .running else { return }
        Task { await coordinator.cancel() }
    }

    /// Clear a finished/cancelled result so the Dashboard returns to its
    /// idle "here's what Smart Scan covers" state.
    func reset() {
        guard phase == .completed || phase == .cancelled else { return }
        phase = .idle
        report = nil
        modules = [:]
        elapsed = 0
        startedAt = nil
    }
}
