// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence

/// Shared app services. Created once at launch; injected into view models.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    /// Why the store is a state rather than an optional.
    ///
    /// It used to be `store = try? Store(path: (try? Store.defaultPath()) ?? ":memory:")`
    /// — two stacked silent failures on one line:
    ///
    /// - If `defaultPath()` throws (Application Support unreachable), the path
    ///   became SQLite's literal in-memory database. The app then ran normally,
    ///   wrote the user's exclusions and Safety Log to RAM, and **lost all of
    ///   it on quit**, with nothing on screen ever saying so.
    /// - If `Store(path:)` throws (corrupt file, failed migration, full disk),
    ///   `store` was nil forever and every persistence call became a no-op.
    ///
    /// Keeping the failure as a value means the UI can say what happened, and
    /// means `storeFailure` exists to be checked rather than inferred from a
    /// nil that could equally mean "not opened yet".
    enum StoreState {
        case ready(Store)
        /// Opened, but only in memory: nothing written will survive quitting.
        case ephemeral(Store, reason: String)
        case unavailable(reason: String)

        var store: Store? {
            switch self {
            case .ready(let store), .ephemeral(let store, _): store
            case .unavailable: nil
            }
        }

        /// True only when writes are actually durable.
        var isDurable: Bool {
            if case .ready = self { return true }
            return false
        }

        var failureReason: String? {
            switch self {
            case .ready: nil
            case .ephemeral(_, let reason), .unavailable(let reason): reason
            }
        }
    }

    let storeState: StoreState

    /// Kept so the many fire-and-forget call sites stay unchanged. Anything
    /// that gates a destructive decision must use `storeState` instead.
    var store: Store? { storeState.store }

    /// Result of the one-time MacCare Local -> CoreTend data migration, if it
    /// had anything to do. Kept so Settings can tell the user what moved, and
    /// so a failure is visible instead of silent.
    let migrationReport: LegacyDataMigration.Report?

    private init() {
        // Runs before the store is opened: the migration's whole job is to put
        // the database where the store is about to look for it.
        migrationReport = Self.runLegacyMigration()
        storeState = Self.openStore()
    }

    /// Opens the store, keeping any failure as a reportable state.
    ///
    /// The in-memory fallback is retained — an app that cannot open its
    /// database should still run, since every scan works without persistence —
    /// but it is now labelled `.ephemeral`, because "your history will be gone
    /// when you quit" is something the user is entitled to know.
    private static func openStore() -> StoreState {
        let path: String
        do {
            path = try Store.defaultPath()
        } catch {
            guard let memory = try? Store(path: ":memory:") else {
                return .unavailable(reason: error.localizedDescription)
            }
            return .ephemeral(memory, reason: error.localizedDescription)
        }
        do {
            return .ready(try Store(path: path))
        } catch {
            guard let memory = try? Store(path: ":memory:") else {
                return .unavailable(reason: error.localizedDescription)
            }
            return .ephemeral(memory, reason: error.localizedDescription)
        }
    }

    /// Reads the user's exclusions, distinguishing "none" from "could not
    /// read". See `ExclusionsSnapshot` for why that distinction is the whole
    /// point.
    func exclusions() async -> ExclusionsSnapshot {
        guard let store = storeState.store else { return .unavailable }
        guard let paths = try? await store.exclusions() else { return .unavailable }
        return .loaded(paths)
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
        Task { try? await store.recordActivity(record) }
    }

    /// Marks a folder as recently scanned for Favorites & Recents. Fire-and-forget
    /// like `record(_:)` above — a missed write here would only cost Recents
    /// freshness, never data correctness.
    func recordLocationVisit(path: String, bytes: Int64) {
        guard let store else { return }
        Task { try? await store.recordLocationVisit(path: path, bytes: bytes) }
    }
}
