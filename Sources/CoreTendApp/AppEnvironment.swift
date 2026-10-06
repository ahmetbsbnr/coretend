// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Observation
import Persistence

enum PersistenceAvailability: Equatable {
    case persistent
    case temporary
    case unavailable
    case degraded

    var afterPersistenceFailure: Self {
        self == .unavailable ? .unavailable : .degraded
    }

    var warningKey: String? {
        switch self {
        case .persistent: nil
        case .temporary: "persistence.warning.temporary"
        case .unavailable: "persistence.warning.unavailable"
        case .degraded: "persistence.warning.degraded"
        }
    }
}

struct StoreBootstrapResult {
    let store: Store?
    let availability: PersistenceAvailability
}

enum StoreBootstrap {
    /// Opens the durable location first. Only a failure to resolve that
    /// location falls back to memory, matching the existing behavior; a
    /// database that exists but cannot be opened fails closed as unavailable.
    static func open(defaultPath: () throws -> String) -> StoreBootstrapResult {
        let path: String
        do {
            path = try defaultPath()
        } catch {
            do {
                return StoreBootstrapResult(store: try Store(path: ":memory:"), availability: .temporary)
            } catch {
                return StoreBootstrapResult(store: nil, availability: .unavailable)
            }
        }

        do {
            return StoreBootstrapResult(store: try Store(path: path), availability: .persistent)
        } catch {
            return StoreBootstrapResult(store: nil, availability: .unavailable)
        }
    }
}

/// Shared app services. Created once at launch; injected into view models.
@MainActor
@Observable
final class AppEnvironment {
    static let shared = AppEnvironment()

    let store: Store?
    private(set) var persistenceAvailability: PersistenceAvailability

    var persistenceWarning: String? {
        persistenceAvailability.warningKey.map { L($0) }
    }

    /// Result of the one-time MacCare Local -> CoreTend data migration, if it
    /// had anything to do. Kept so Settings can tell the user what moved, and
    /// so a failure is visible instead of silent.
    let migrationReport: LegacyDataMigration.Report?

    private init() {
        // Runs before the store is opened: the migration's whole job is to put
        // the database where the store is about to look for it.
        migrationReport = Self.runLegacyMigration()
        let bootstrap = StoreBootstrap.open(defaultPath: Store.defaultPath)
        store = bootstrap.store
        persistenceAvailability = bootstrap.availability
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
            do {
                try await store.recordActivity(record)
            } catch {
                notePersistenceFailure()
            }
        }
    }

    /// Marks a folder as recently scanned for Favorites & Recents. Fire-and-forget
    /// like `record(_:)` above — a missed write here would only cost Recents
    /// freshness, never data correctness.
    func recordLocationVisit(path: String, bytes: Int64) {
        guard let store else { return }
        Task {
            do {
                try await store.recordLocationVisit(path: path, bytes: bytes)
            } catch {
                notePersistenceFailure()
            }
        }
    }

    func notePersistenceFailure() {
        persistenceAvailability = persistenceAvailability.afterPersistenceFailure
    }

    /// SafetyCore's audit sink intentionally does not throw into the file
    /// operation. Read its in-memory failure tally afterward so audit loss is
    /// still surfaced globally without changing that contract.
    func refreshAuditHealth() async {
        guard let store else { return }
        if await store.unrecordedEventCount > 0 {
            persistenceAvailability = .degraded
        }
    }
}
