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

    /// Non-nil only when a test injects a coordinator — production rebuilds a
    /// fresh coordinator (and a fresh candidate cache) for every run.
    @ObservationIgnored private let injectedCoordinator: SmartScanCoordinator?
    @ObservationIgnored private var coordinator: SmartScanCoordinator
    /// The candidate cache the storage-family providers read from. Kept so a
    /// completed run can hand the exact same candidates to Recovery Plan
    /// without re-scanning. Rebuilt per run in production so "New Smart Scan"
    /// genuinely re-reads the disk rather than replaying the last scan.
    @ObservationIgnored private var candidates: SmartScanRecoveryCandidates?
    @ObservationIgnored private var driver: Task<Void, Never>?
    @ObservationIgnored private var startedAt: Date?
    /// Injected so tests can drive elapsed time deterministically.
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let pollInterval: Duration

    /// Test seam: builds the coordinator for each run. Production leaves this
    /// nil and rebuilds `SmartScanProviders.live(...)` itself.
    @ObservationIgnored private let coordinatorFactory: (@MainActor () -> SmartScanCoordinator)?
    /// Test seam: number of times a fresh coordinator has been built (once at
    /// init if not injected, then once per `start()`).
    @ObservationIgnored private(set) var coordinatorGeneration = 0

    init(coordinator: SmartScanCoordinator? = nil,
         candidates: SmartScanRecoveryCandidates? = nil,
         coordinatorFactory: (@MainActor () -> SmartScanCoordinator)? = nil,
         now: @Sendable @escaping () -> Date = Date.init,
         pollInterval: Duration = .milliseconds(250)) {
        self.injectedCoordinator = coordinator
        self.coordinatorFactory = coordinatorFactory
        if let coordinator {
            self.coordinator = coordinator
            self.candidates = candidates
        } else if let coordinatorFactory {
            self.coordinator = coordinatorFactory()
            self.candidates = candidates
            self.coordinatorGeneration = 1
        } else {
            let cache = candidates ?? SmartScanRecoveryCandidates(
                home: FileManager.default.homeDirectoryForCurrentUser,
                store: AppEnvironment.shared.store)
            self.candidates = cache
            self.coordinator = SmartScanCoordinator(providers: SmartScanProviders.live(candidates: cache))
            self.coordinatorGeneration = 1
        }
        self.now = now
        self.pollInterval = pollInterval
    }

    /// Start a run. A no-op if one is already in progress — never launches a
    /// duplicate scan.
    func start() {
        guard phase != .running else { return }

        // Build a fresh coordinator + candidate cache so this run scans the
        // disk again from scratch — "New Smart Scan" must not replay the last
        // scan's snapshot. Tests that inject a single coordinator keep it.
        if injectedCoordinator == nil {
            if let coordinatorFactory {
                coordinator = coordinatorFactory()
            } else {
                let cache = SmartScanRecoveryCandidates(
                    home: FileManager.default.homeDirectoryForCurrentUser,
                    store: AppEnvironment.shared.store)
                candidates = cache
                coordinator = SmartScanCoordinator(providers: SmartScanProviders.live(candidates: cache))
            }
            coordinatorGeneration += 1
        }

        phase = .running
        report = nil
        elapsed = 0
        startedAt = now()
        modules = Dictionary(uniqueKeysWithValues: SmartScanModuleID.allCases.map { ($0, .queued) })
        // A new run invalidates any prior Recovery Plan handoff immediately —
        // the old candidate picture is about to be replaced.
        SmartScanHandoff.shared.clear()

        driver = Task { [coordinator] in
            let runTask = await coordinator.start()
            // Refresh the live snapshot on an interval until the run resolves.
            // (This Task inherits MainActor isolation from the class.)
            while await coordinator.isRunning {
                let snapshot = await coordinator.report.modules
                if snapshot != self.modules { self.modules = snapshot }
                self.tickElapsed()
                try? await Task.sleep(for: self.pollInterval)
            }
            let final = await runTask.value
            if final.modules != self.modules { self.modules = final.modules }
            self.report = final
            self.tickElapsed()
            self.phase = final.wasCancelled ? .cancelled : .completed
            self.driver = nil
            // Publish the exact candidate set to the Recovery Plan handoff —
            // only for a genuinely finished run, never a cancelled partial.
            if !final.wasCancelled, let candidates = self.candidates {
                SmartScanHandoff.shared.record(cache: candidates, report: final, at: self.now())
            }
        }
    }

    private func tickElapsed() {
        guard let started = startedAt else { return }
        // Publish at whole-second granularity only: the driver polls faster
        // than that for module states, but the visible clock does not need
        // to — and re-assigning `elapsed` every 250 ms would churn SwiftUI.
        let seconds = now().timeIntervalSince(started).rounded(.down)
        if seconds != elapsed { elapsed = seconds }
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
        SmartScanHandoff.shared.clear()
    }
}
