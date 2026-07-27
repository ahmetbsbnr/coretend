import Foundation
import Persistence

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

    /// Interprets the persisted `dryRunDefault` setting. Absent (nil) or any value
    /// other than the literal "false" means dry-run stays ON — safety is the default,
    /// so only an explicit "false" opts out. Pure so it is directly testable.
    nonisolated static func dryRunEnabled(fromSetting value: String?) -> Bool {
        value != "false"
    }

    func record(_ record: ActivityRecord) {
        guard let store else { return }
        Task { try? await store.recordActivity(record) }
    }
}
