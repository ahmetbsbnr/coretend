import Foundation
import Persistence
import SafetyCore

/// Selects the fixture Trash only for a complete, validated test profile. A malformed
/// override fails closed instead of falling through to the user's macOS Trash.
enum AppTrashClient {
    static func make(environment: [String: String] = ProcessInfo.processInfo.environment) -> any TrashClient {
        guard environment["CORETEND_TEST_TRASH_DIR"] != nil else { return MacOSTrashClient() }
        guard let homePath = environment["HOME"] else { return UnavailableTrashClient() }
        let home = URL(fileURLWithPath: homePath, isDirectory: true)
        do {
            guard let directory = try TestStoreOverride.trashDirectory(
                environment: environment,
                temporaryRoot: FileManager.default.temporaryDirectory,
                homeDirectory: home
            ) else {
                return UnavailableTrashClient()
            }
            return FixtureDirectoryTrashClient(
                directory: directory
            )
        } catch {
            return UnavailableTrashClient()
        }
    }
}

private struct FixtureDirectoryTrashClient: TrashClient {
    let directory: URL

    func moveToTrash(_ url: URL) async throws -> URL {
        // Revalidate the environment on every move in case a test process changed it
        // after the review dialog was opened.
        let environment = ProcessInfo.processInfo.environment
        guard let homePath = environment["HOME"],
              let current = try TestStoreOverride.trashDirectory(
                environment: environment,
                temporaryRoot: FileManager.default.temporaryDirectory,
                homeDirectory: URL(fileURLWithPath: homePath, isDirectory: true)
              ), current.path == directory.path else {
            throw FixtureTrashError.revalidation
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }
}

private enum FixtureTrashError: Error { case revalidation }

private struct UnavailableTrashClient: TrashClient {
    func moveToTrash(_ url: URL) async throws -> URL {
        throw CocoaError(.fileWriteNoPermission)
    }
}
