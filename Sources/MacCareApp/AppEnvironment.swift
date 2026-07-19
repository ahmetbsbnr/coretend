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

    func record(_ record: ActivityRecord) {
        guard let store else { return }
        Task { try? await store.recordActivity(record) }
    }
}
