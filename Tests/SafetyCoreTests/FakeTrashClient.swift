import Foundation
@testable import SafetyCore

actor FixtureTrashClient: TrashClient {
    private let trashRoot: URL
    private let shouldFail: Bool

    init(trashRoot: URL, shouldFail: Bool = false) {
        self.trashRoot = trashRoot
        self.shouldFail = shouldFail
    }

    func moveToTrash(_ url: URL) async throws -> URL {
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        let destination = trashRoot.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }
}
