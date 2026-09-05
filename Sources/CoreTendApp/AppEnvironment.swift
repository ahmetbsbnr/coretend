// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence
import SystemMetrics

/// Shared app services. Created once at launch; injected into view models.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let store: Store?

    /// Result of the one-time MacCare Local -> CoreTend data migration, if it
    /// had anything to do. Kept so Settings can tell the user what moved, and
    /// so a failure is visible instead of silent.
    let migrationReport: LegacyDataMigration.Report?

    private init() {
        // Runs before the store is opened: the migration's whole job is to put
        // the database where the store is about to look for it.
        migrationReport = Self.runLegacyMigration()
        store = try? Store(path: (try? Store.defaultPath()) ?? ":memory:")
    }

    /// Migrates pre-rebrand user data on first launch under the new identity.
    /// A no-op on a fresh install and on every launch after the first, so it is
    /// safe to call unconditionally here rather than behind a "have we done
    /// this yet" flag that could itself get out of sync with the filesystem.
    ///
    /// Skipped entirely under the test marker. A distribution smoke test points
    /// the store at a throwaway directory; if the migration still ran it would
    /// read the user's real pre-rename data and copy it there, which is exactly
    /// the isolation the test claims to have. Suppression is keyed on the marker
    /// alone, not on a valid override path: if the marker is set and the path was
    /// rejected, the app is running under a test harness that believes it is
    /// isolated, and touching real data would be worse than doing nothing.
    private static func runLegacyMigration() -> LegacyDataMigration.Report? {
        guard !TestStoreOverride.isTestMarkerSet(environment: ProcessInfo.processInfo.environment)
        else { return nil }
        guard let migration = try? LegacyDataMigration.standard() else { return nil }
        let report = migration.run()
        return report.didAnything || !report.failures.isEmpty ? report : nil
    }

    func record(_ record: ActivityRecord) {
        guard let store else { return }
        Task {
            _ = try? await store.recordActivity(record)
            await self.publishWidgetSnapshotNow()
        }
    }

    /// Publishes the low-sensitivity Widget snapshot from current derived
    /// numbers, then reloads the widget. Fire-and-forget and idempotent —
    /// called after meaningful events (launch, completed scan, cleanup /
    /// restore completion), never on a timer. A no-op when the App Group
    /// container is unavailable.
    func publishWidgetSnapshot() {
        Task { await self.publishWidgetSnapshotNow() }
    }

    private func publishWidgetSnapshotNow() async {
        guard let store else { return }
        let metrics = await MetricsCollector().snapshot()
        await WidgetPublisher.gatherAndPublish(
            store: store, freeBytes: metrics.diskFreeBytes, totalBytes: metrics.diskTotalBytes)
    }

    /// Marks a folder as recently scanned for Favorites & Recents. Fire-and-forget
    /// like `record(_:)` above — a missed write here would only cost Recents
    /// freshness, never data correctness.
    func recordLocationVisit(path: String, bytes: Int64) {
        guard let store else { return }
        Task { try? await store.recordLocationVisit(path: path, bytes: bytes) }
    }

    /// Records one scan's category-level footprint into Storage Timeline.
    /// `scope` identifies the scan methodology (see `TimelineScope`) — it is
    /// what keeps later comparisons from mixing incomparable scan kinds.
    /// Fire-and-forget like `record(_:)` — a missed write only costs Timeline
    /// history, never data correctness.
    func recordTimelineSnapshot(scope: TimelineScope, samples: [TimelineCategorySample]) {
        guard let store else { return }
        Task {
            _ = try? await store.recordTimelineSnapshot(scope: scope.rawValue, samples: samples)
            await self.publishWidgetSnapshotNow()
        }
    }
}
