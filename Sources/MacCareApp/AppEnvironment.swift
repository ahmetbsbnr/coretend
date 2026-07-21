import Foundation
import Persistence

/// Shared app services. Created once at launch; injected into view models.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let store: Store?

    private init() {
        store = try? Store(path: (try? Store.defaultPath()) ?? ":memory:")
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
