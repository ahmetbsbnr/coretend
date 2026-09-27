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
        XCTAssertThrowsError(try CLICommand.parse(["record", "list"])) { error in
            XCTAssertEqual(error as? CLIError, .storePathRequired)
        }
    }

    func testOptionNamesCannotBeConsumedAsFlagValues() {
        let malformedCommands = [
            ["record", "list", "--store", "--store"],
            ["scan", "--root", "--rule", "--rule", "scan.explore"]
        ]
        for arguments in malformedCommands {
            XCTAssertThrowsError(try CLICommand.parse(arguments), "Expected malformed options to fail: \(arguments)") { error in
                XCTAssertEqual(error as? CLIError, .invalidArguments)
            }
        }
    }

    func testPermanentMutationCommandsAreRejected() {
        XCTAssertThrowsError(try CLICommand.parse(["delete", "/tmp/example"]))
        XCTAssertThrowsError(try CLICommand.parse(["scan", "--root", "/tmp", "--rule", "unknown"]))
    }

    func testLanguageOptionIsExplicitAndMustPrecedeCommand() throws {
        XCTAssertEqual(try CLIInvocation.parse(["--lang", "fr", "help"]).language, .fr)
        XCTAssertEqual(try CLIInvocation.parse(["help"]).language, .en)
        XCTAssertThrowsError(try CLIInvocation.parse(["--lang", "de", "help"]))
        XCTAssertThrowsError(try CLIInvocation.parse(["--lang", "fr"]))
        XCTAssertThrowsError(try CLIInvocation.parse(["help", "--lang", "fr"]))
    }

    func testFrenchTextOutputAndJSONShapeStayStable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let textOutput = OutputCapture()
        let textExit = await CoreTendCLIRunner.run(.scan(root: root, rule: .explore, format: .text), language: .fr) { textOutput.append($0) }
        XCTAssertEqual(textExit, 2)
        XCTAssertTrue(textOutput.values.contains("0 fichiers"))
        XCTAssertTrue(textOutput.values.contains(where: { $0.contains("Problème d’analyse [missing]") }))

        let jsonOutput = OutputCapture()
        let jsonExit = await CoreTendCLIRunner.run(.scan(root: root, rule: .explore, format: .json), language: .fr) { jsonOutput.append($0) }
        XCTAssertEqual(jsonExit, 2)
        let data = Data(jsonOutput.values.joined().utf8)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["complete"] as? Bool, false)
        XCTAssertEqual((object["issues"] as? [[String: Any]])?.first?["reason"] as? String, "missing")
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
