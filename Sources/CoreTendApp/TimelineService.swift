// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence

/// The comparison window a Timeline screen can ask for. Every case maps to
/// one `Store` call, so a View picks a window by name instead of computing
/// dates or calling Persistence itself.
enum TimelineWindow: String, CaseIterable, Identifiable {
    case sincePreviousScan
    case last24Hours
    case last7Days
    case last30Days

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sincePreviousScan: L("timeline.window.since_previous")
        case .last24Hours: L("timeline.window.last_24h")
        case .last7Days: L("timeline.window.last_7d")
        case .last30Days: L("timeline.window.last_30d")
        }
    }
}

/// The clean boundary between `Persistence` and Timeline UI. Views (and their
/// view models) call this — never `Store` directly, and never reconstruct
/// comparison math themselves; every method here maps to exactly one `Store`
/// call, or composes calls that are already scope-safe by construction (see
/// `Store.swift`'s Timeline section for what "scope-safe" means).
///
/// `@MainActor` to match `AppEnvironment` and this app's other services; the
/// actual work still happens off the main actor inside the `Store` actor —
/// this type only sequences calls and shapes results for a View.
@MainActor
final class TimelineService {
    private let store: Store?

    init(store: Store? = AppEnvironment.shared.store) {
        self.store = store
    }

    /// Every wired scope that has at least one recorded snapshot. Drives
    /// whether the "nothing has ever been scanned" empty state applies, and
    /// which scopes a picker should offer as having real content.
    func scopesWithHistory() async -> [TimelineScope] {
        guard let store else { return [] }
        var found: [TimelineScope] = []
        for scope in TimelineScope.allCases {
            if (try? await store.latestTimelineSnapshot(scope: scope.rawValue)) != nil {
                found.append(scope)
            }
        }
        return found
    }

    /// The scope of the single most recently completed scan of any kind, or
    /// nil if nothing has ever run. Used to pick a sensible default tab.
    func mostRecentScope() async -> TimelineScope? {
        guard let store, let latest = try? await store.latestTimelineSnapshot() else { return nil }
        return TimelineScope(rawValue: latest.scope)
    }

    func latestSnapshot(scope: TimelineScope) async -> TimelineSnapshotRecord? {
        guard let store else { return nil }
        return try? await store.latestTimelineSnapshot(scope: scope.rawValue)
    }

    /// Newest first, for a scope's own "recent history" list.
    func recentHistory(scope: TimelineScope, limit: Int = 10) async -> [TimelineSnapshotRecord] {
        guard let store else { return [] }
        return (try? await store.timelineSnapshots(scope: scope.rawValue, limit: limit)) ?? []
    }

    /// nil means "not enough history yet for this window" — never a fake
    /// zero-delta comparison.
    func comparison(scope: TimelineScope, window: TimelineWindow) async -> TimelineComparison? {
        guard let store else { return nil }
        switch window {
        case .sincePreviousScan:
            return try? await store.timelineComparisonSincePreviousSnapshot(scope: scope.rawValue)
        case .last24Hours:
            return try? await store.timelineComparison(scope: scope.rawValue,
                                                         since: Date().addingTimeInterval(-24 * 3600))
        case .last7Days:
            return try? await store.timelineComparison(scope: scope.rawValue,
                                                         since: Date().addingTimeInterval(-7 * 24 * 3600))
        case .last30Days:
            return try? await store.timelineComparison(scope: scope.rawValue,
                                                         since: Date().addingTimeInterval(-30 * 24 * 3600))
        }
    }

    /// "Since last scan" for a Dashboard-level card: the single most recent
    /// scan of any kind, compared only against the previous snapshot of that
    /// same scope — never blended across scopes. nil means either nothing has
    /// ever been scanned, or the most recently scanned scope has no earlier
    /// snapshot of its own yet.
    func overallSinceLastScan() async -> TimelineComparison? {
        guard let store else { return nil }
        return try? await store.latestTimelineComparisonAcrossScopes()
    }

    /// Explicit, user-initiated, all-or-nothing — every scope's history.
    func clearHistory() async {
        guard let store else { return }
        try? await store.clearTimelineHistory()
    }
}
