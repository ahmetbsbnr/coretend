import Foundation
import XCTest
@testable import AppShell

final class QuickLookCandidateTests: XCTestCase {
    func testOnlyRegularFilesInsideSelectedRootArePreviewable() throws {
        let fixture = FileManager.default.temporaryDirectory
            .appendingPathComponent("coretend-preview-\(UUID().uuidString)", isDirectory: true)
        let root = fixture.appendingPathComponent("chosen", isDirectory: true)
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        let outside = fixture.appendingPathComponent("outside.txt")
        let file = root.appendingPathComponent("file.txt")
        let nestedFile = nested.appendingPathComponent("nested.txt")
        let symlink = root.appendingPathComponent("linked.txt")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixture) }
        try Data("fixture-content".utf8).write(to: file)
        try Data("nested-content".utf8).write(to: nestedFile)
        try Data("outside-content".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)

        XCTAssertTrue(QuickLookCandidate.isAllowed(file, within: root))
        XCTAssertTrue(QuickLookCandidate.isAllowed(nestedFile, within: root))
        XCTAssertFalse(QuickLookCandidate.isAllowed(root, within: root))
        XCTAssertFalse(QuickLookCandidate.isAllowed(outside, within: root))
        XCTAssertFalse(QuickLookCandidate.isAllowed(symlink, within: root))
        XCTAssertFalse(QuickLookCandidate.isAllowed(root.appendingPathComponent("missing.txt"), within: root))
        XCTAssertEqual(try Data(contentsOf: file), Data("fixture-content".utf8))
    }

    func testRejectsSymlinkAsSelectedRoot() throws {
        let fixture = FileManager.default.temporaryDirectory
            .appendingPathComponent("coretend-preview-root-\(UUID().uuidString)", isDirectory: true)
        let root = fixture.appendingPathComponent("root", isDirectory: true)
        let rootLink = fixture.appendingPathComponent("root-link", isDirectory: true)
        let file = root.appendingPathComponent("file.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixture) }
        try Data("fixture-content".utf8).write(to: file)
        try FileManager.default.createSymbolicLink(at: rootLink, withDestinationURL: root)

        XCTAssertFalse(QuickLookCandidate.isAllowed(file, within: rootLink))
    }
}
