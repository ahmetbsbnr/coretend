import Foundation
import Persistence
import Foundation

enum LocalStoreAccess {
    static func open() async throws -> SQLiteStore {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
        let url = StoreLocation.databaseURL(applicationSupportDirectory: support)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let store = try SQLiteStore(url: url)
        try await store.migrate()
        return store
    }

    static func exclusions() async throws -> [URL] {
        let store = try await open()
        return try await store.exclusions().map { URL(fileURLWithPath: $0, isDirectory: true) }
    }
}
