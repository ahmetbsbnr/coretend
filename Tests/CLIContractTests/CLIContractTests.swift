import XCTest
@testable import CLIContract

private final class OutputCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    func append(_ value: String) { lock.lock(); storage.append(value); lock.unlock() }
    var values: [String] { lock.lock(); defer { lock.unlock() }; return storage }
}

final class CLIContractTests: XCTestCase {
    func testParsesExplicitReadOnlyScanScope() throws {
        let command = try CLICommand.parse(["scan", "--root", "/tmp/example", "--rule", "scan.explore", "--format", "json"])
        guard case .scan(let root, let rule, let format) = command else { return XCTFail("wrong command") }
        XCTAssertEqual(root.path, "/tmp/example")
        XCTAssertEqual(rule.rawValue, "scan.explore")
        XCTAssertEqual(format, .json)
    }

    func testRecordRequiresExplicitStorePath() {
        XCTAssertThrowsError(try CLICommand.parse(["record", "list"]))
    }

    func testPermanentMutationCommandsAreRejected() {
        XCTAssertThrowsError(try CLICommand.parse(["delete", "/tmp/example"]))
        XCTAssertThrowsError(try CLICommand.parse(["scan", "--root", "/tmp", "--rule", "unknown"]))
    }

    func testScanMissingRootReturnsPartialExitAndStructuredIssue() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let output = OutputCapture()
        let exit = await CoreTendCLIRunner.run(.scan(root: root, rule: .explore, format: .json)) { output.append($0) }
        XCTAssertEqual(exit, 2)
        let data = Data(output.values.joined().utf8)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["complete"] as? Bool, false)
        XCTAssertEqual((object["files"] as? [Any])?.count, 0)
        let issues = try XCTUnwrap(object["issues"] as? [[String: Any]])
        XCTAssertEqual(issues.first?["reason"] as? String, "missing")
    }

    func testScanFixtureReturnsCompleteSuccess() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("fixture".utf8).write(to: root.appendingPathComponent("sample.txt"))
        let output = OutputCapture()
        let exit = await CoreTendCLIRunner.run(.scan(root: root, rule: .explore, format: .json)) { output.append($0) }
        XCTAssertEqual(exit, 0)
        let data = Data(output.values.joined().utf8)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["complete"] as? Bool, true)
        XCTAssertEqual((object["files"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((object["issues"] as? [Any])?.count, 0)
    }
}
