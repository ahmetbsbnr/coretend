import XCTest
@testable import CLIContract

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
}
