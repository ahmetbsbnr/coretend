// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import WidgetKit
import WidgetShared
import Persistence

/// Reloads the widget timeline. Behind a protocol so `WidgetPublisher` can be
/// tested without a real `WidgetCenter`.
protocol WidgetReloading: Sendable {
    func reload()
}

struct SystemWidgetReloader: WidgetReloading {
    func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.status)
    }
}

/// Builds the low-sensitivity `WidgetSnapshot` from already-computed host data
/// and publishes it atomically to the App Group. **It never scans** — every
/// input is a number the host has already produced (a `MetricsCollector`
/// disk reading, a Timeline total, an activity kind). Called after meaningful
/// events (launch, completed scan, cleanup/restore completion), never on a
/// timer.
enum WidgetPublisher {
    /// Pure assembly — unit-tested directly.
    static func snapshot(freeBytes: Int64, totalBytes: Int64,
                         reclaimableBytes: Int64?, sinceLastScanDeltaBytes: Int64?,
                         lastScanDate: Date?, lastActivityKind: String?,
                         now: Date = Date()) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: now, freeBytes: freeBytes, totalBytes: totalBytes,
            reclaimableBytes: reclaimableBytes, sinceLastScanDeltaBytes: sinceLastScanDeltaBytes,
            lastScanDate: lastScanDate, lastActivityKind: lastActivityKind)
    }

    /// Reads the derived numbers from `store`, writes the snapshot, and
    /// reloads the widget on a successful write. Returns the published
    /// snapshot (or `nil` if there was nothing to publish / the write
    /// failed). `store` and the sinks are injectable for tests.
    @discardableResult
    static func gatherAndPublish(store: Store?, freeBytes: Int64, totalBytes: Int64,
                                 widgetStore: WidgetSnapshotStore = WidgetSnapshotStore(),
                                 reloader: WidgetReloading = SystemWidgetReloader(),
                                 now: Date = Date()) async -> WidgetSnapshot? {
        guard let store else { return nil }
        let cleanupLatest = try? await store.latestTimelineSnapshot(scope: TimelineScope.cleanup.rawValue)
        let comparison = try? await store.latestTimelineComparisonAcrossScopes()
        let lastScan = try? await store.latestTimelineSnapshot()
        let lastActivity = (try? await store.activity(limit: 1))?.first

        let snapshot = Self.snapshot(
            freeBytes: freeBytes, totalBytes: totalBytes,
            reclaimableBytes: cleanupLatest?.totalBytes,
            sinceLastScanDeltaBytes: comparison?.totalDeltaBytes,
            lastScanDate: lastScan?.date,
            lastActivityKind: lastActivity?.kind.rawValue,
            now: now)

        guard widgetStore.write(snapshot) else { return nil }
        reloader.reload()
        return snapshot
    }
}
