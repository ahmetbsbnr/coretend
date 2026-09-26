import Foundation
import XCTest
@testable import SafetyCore

final class SafetyCoreTests: XCTestCase {
    private func fixture() throws -> (root: URL, trash: URL, file: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-fixture-\(UUID())", isDirectory: true)
        let trash = root.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("candidate.txt")
        try Data("keep me".utf8).write(to: file)
        return (root, trash, file)
    }

    func testTrashFailurePreservesOriginalAndReturnsFailure() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let validator = PathValidator()
        let allowed = Set(["cleanup.fixture"])
        let approved = try validator.approve(target: f.file, allowedRoots: [f.root], ruleID: "cleanup.fixture", allowedRuleIDs: allowed)
        let executor = SafeActionExecutor(allowedRoots: [f.root], allowedRules: allowed,
                                          trash: FixtureTrashClient(trashRoot: f.trash, shouldFail: true))
        let outcome = await executor.execute(approved)
        XCTAssertEqual(try Data(contentsOf: f.file), Data("keep me".utf8))
        if case .failed(.trashFailed) = outcome { } else { XCTFail("expected failed Trash result") }
    }

    func testSuccessfulFakeTrashMovesOnlyInsideFixture() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let allowed = Set(["cleanup.fixture"])
        let approved = try PathValidator().approve(target: f.file, allowedRoots: [f.root], ruleID: "cleanup.fixture", allowedRuleIDs: allowed)
        let executor = SafeActionExecutor(allowedRoots: [f.root], allowedRules: allowed,
                                          trash: FixtureTrashClient(trashRoot: f.trash))
        let outcome = await executor.execute(approved)
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.file.path))
        if case .movedToTrash(_, let path) = outcome {
            XCTAssertTrue(path.hasPrefix(f.trash.path + "/"))
            XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: path)), Data("keep me".utf8))
        } else { XCTFail("expected fixture Trash move") }
    }

    func testApprovalRejectsOutsideRootAndUnknownRule() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        XCTAssertThrowsError(try PathValidator().approve(target: f.file, allowedRoots: [f.trash], ruleID: "cleanup.fixture", allowedRuleIDs: ["cleanup.fixture"]))
        XCTAssertThrowsError(try PathValidator().approve(target: f.file, allowedRoots: [f.root], ruleID: "unknown", allowedRuleIDs: []))
    }

    func testExecutionRejectsChangedIdentity() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let allowed = Set(["cleanup.fixture"])
        let approved = try PathValidator().approve(target: f.file, allowedRoots: [f.root], ruleID: "cleanup.fixture", allowedRuleIDs: allowed)
        try FileManager.default.removeItem(at: f.file)
        try Data("replacement".utf8).write(to: f.file)
        let executor = SafeActionExecutor(allowedRoots: [f.root], allowedRules: allowed,
                                          trash: FixtureTrashClient(trashRoot: f.trash))
        let outcome = await executor.execute(approved)
        if case .failed(.revalidation) = outcome { } else { XCTFail("expected revalidation failure") }
        XCTAssertEqual(try Data(contentsOf: f.file), Data("replacement".utf8))
    }

    func testExecutionRejectsExpiredApprovalWithoutCallingTrash() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let allowed = Set(["cleanup.fixture"])
        let approvedAt = Date(timeIntervalSince1970: 100)
        let approved = try PathValidator().approve(target: f.file, allowedRoots: [f.root], ruleID: "cleanup.fixture", allowedRuleIDs: allowed, now: approvedAt, lifetime: 5)
        let trash = FixtureTrashClient(trashRoot: f.trash)
        let executor = SafeActionExecutor(allowedRoots: [f.root], allowedRules: allowed,
                                          trash: trash, clock: { approvedAt.addingTimeInterval(6) })
        let outcome = await executor.execute(approved)
        if case .failed(.revalidation(.expiredApproval)) = outcome { } else { XCTFail("expected expiration failure") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.file.path))
        let contents = try FileManager.default.contentsOfDirectory(atPath: f.trash.path)
        XCTAssertTrue(contents.isEmpty)
    }
}
