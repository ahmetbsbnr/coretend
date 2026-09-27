import Foundation
import Persistence
import Foundation

enum LocalStoreAccess {
    static func open() async throws -> SQLiteStore {
        let environment = ProcessInfo.processInfo.environment
        let url: URL
        if environment["CORETEND_TEST_MODE"] != nil || environment["CORETEND_TEST_STORE_DIR"] != nil {
            guard let homePath = environment["HOME"] else { throw StoreError.invalidTestStoreOverride }
            let home = URL(fileURLWithPath: homePath, isDirectory: true)
            guard let isolatedURL = try TestStoreOverride.databaseURL(
                environment: environment,
                temporaryRoot: FileManager.default.temporaryDirectory,
                homeDirectory: home
            ) else { throw StoreError.invalidTestStoreOverride }
            url = isolatedURL
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
            url = StoreLocation.databaseURL(applicationSupportDirectory: support)
        }
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
