// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

//
// SCHEDULED SCANS ARE READ-ONLY BY CONSTRUCTION.
//
// This file imports ScanCore (a read-only scan engine that only *emits*
// findings) and Persistence (Timeline history). It does NOT import
// FileRules, and references no SafetyCenter / CleanupExecution /
// RecoveryPlanService / RestoreService symbol. A scheduled run therefore has
// no code path to any delete/trash/restore API — the guarantee is a
// dependency fact, not a runtime flag. `ScheduledScanReadOnlyTests` proves
// it behaviourally (a scan over real deletable fixtures leaves every file in
// place).
//

import Foundation
import ScanCore
import Persistence

// MARK: - Cadence

/// The only cadences offered — no arbitrary schedule syntax.
enum ScanCadence: String, CaseIterable, Identifiable, Sendable {
    case off, daily, weekly

    var id: String { rawValue }

    /// `nil` for `.off`. A generous `tolerance` lets macOS batch the wake-up
    /// with other maintenance work.
    var interval: TimeInterval? {
        switch self {
        case .off: return nil
        case .daily: return 24 * 3600
        case .weekly: return 7 * 24 * 3600
        }
    }

    var tolerance: TimeInterval {
        switch self {
        case .off: return 0
        case .daily: return 2 * 3600
        case .weekly: return 12 * 3600
        }
    }

    var labelKey: String { "schedule.cadence.\(rawValue)" }
}

// MARK: - Result

/// What one scheduled run produced. Only `.completed` ever leads to a
/// Timeline write.
enum ScheduledScanResult: Sendable, Equatable {
    case skippedAlreadyRunning
    case cancelled
    case failed
    /// A real, finished scan. `growthBytes` is the increase vs the previous
    /// `cleanup` snapshot, or `nil` when there is no earlier snapshot to
    /// compare against.
    case completed(reclaimableBytes: Int64, growthBytes: Int64?)

    var isCompleted: Bool { if case .completed = self { return true } else { return false } }
}

// MARK: - Scheduling abstraction

/// The slice of `NSBackgroundActivityScheduler` the service needs, behind a
/// protocol so tests can fire the activity synchronously.
protocol BackgroundScheduling: AnyObject {
    /// Registers a repeating activity. `operation` is invoked on a
    /// background queue each time it fires and must call the supplied
    /// `finished` closure when done.
    func schedule(identifier: String, interval: TimeInterval, tolerance: TimeInterval,
                  operation: @escaping @Sendable (_ finished: @escaping @Sendable () -> Void) -> Void)
    func invalidate()
}

/// `NSBackgroundActivityScheduler` — the native macOS mechanism for
/// low-priority, repeating, best-effort maintenance work in a running app.
/// Chosen over `BGTaskScheduler` (iOS-shaped, needs Info.plist identifier
/// registration and a sandboxed app) and over a hand-rolled timer: it is
/// pure Foundation, needs no entitlement, is deferred automatically by the
/// system under low-power / thermal pressure, and coalesces with other
/// system maintenance. Its one limitation — it does not relaunch a quit app
/// — is acceptable for a utility that is typically left running / in the
/// menu bar, and is documented.
final class SystemBackgroundScheduler: BackgroundScheduling {
    private var activity: NSBackgroundActivityScheduler?

    func schedule(identifier: String, interval: TimeInterval, tolerance: TimeInterval,
                  operation: @escaping @Sendable (_ finished: @escaping @Sendable () -> Void) -> Void) {
        invalidate()
        let activity = NSBackgroundActivityScheduler(identifier: identifier)
        activity.repeats = true
        activity.interval = interval
        activity.tolerance = tolerance
        activity.qualityOfService = .utility
        activity.schedule { completion in
            operation { completion(NSBackgroundActivityScheduler.Result.finished) }
        }
        self.activity = activity
    }

    func invalidate() {
        activity?.invalidate()
        activity = nil
    }
}

// MARK: - Service

/// Runs the read-only Cleanup scan on a schedule and records its result to
/// Timeline. An `actor`: every run is serialized, `inProgress` prevents an
/// overlapping second run, and all work is off the main actor. It reuses the
/// exact `ScanEngine` + `UserCleanupRules` the interactive Cleanup screen
/// uses and the shared `CleanupTimeline.samples` mapping — never a second
/// scan engine.
actor ScheduledScanService {
    private let store: Store?
    private let home: URL
    private var inProgress = false

    init(store: Store?, home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.store = store
        self.home = home
    }

    /// Runs one scheduled scan over `rules` (always the read-only Cleanup
    /// catalog — a `[ScanRule]` is inert data, and this type has no way to
    /// act on a finding). `isCancelled` is checked between scan events so an
    /// app quit / system stop aborts promptly **without** writing a partial
    /// snapshot. Returns `.completed` only for a scan that reached
    /// `ScanEvent.finished`.
    func run(rules: [ScanRule],
             isCancelled: @Sendable () -> Bool = { Task.isCancelled }) async -> ScheduledScanResult {
        guard !inProgress else { return .skippedAlreadyRunning }
        inProgress = true
        defer { inProgress = false }

        let excluded = (try? await store?.exclusions()) ?? []
        let engine = ScanEngine(configuration: ScanConfiguration(home: home, excludedPaths: excluded))

        var findings: [ScanFinding] = []
        var finishedBytes: Int64?
        for await event in engine.run(rules: rules) {
            if isCancelled() { return .cancelled }
            switch event {
            case let .finding(finding):
                findings.append(finding)
            case let .finished(_, totalBytes):
                finishedBytes = totalBytes
            case .cancelled:
                return .cancelled
            default:
                break
            }
        }

        // No `.finished` event => the stream ended without completing.
        guard let reclaimable = finishedBytes, !isCancelled() else { return .failed }

        let samples = CleanupTimeline.samples(from: findings)
        _ = try? await store?.recordTimelineSnapshot(scope: "cleanup", trigger: "scheduled", samples: samples)
        _ = try? await store?.recordActivity(ActivityRecord(
            kind: .scan,
            summary: "Scheduled Cleanup scan: \(findings.count) items found",
            itemCount: findings.count, bytes: reclaimable))

        let growth = await growthSincePreviousSnapshot()
        return .completed(reclaimableBytes: reclaimable, growthBytes: growth)
    }

    /// Positive delta only (a shrink returns `nil` — "storage growth" is not
    /// a thing to report when it went down).
    private func growthSincePreviousSnapshot() async -> Int64? {
        guard let store,
              let comparison = try? await store.timelineComparisonSincePreviousSnapshot(scope: "cleanup")
        else { return nil }
        let delta = comparison.totalDeltaBytes
        return delta > 0 ? delta : nil
    }
}
