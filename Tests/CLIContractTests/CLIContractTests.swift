import XCTest
@testable import CLIContract
import SafetyCore
import ScanCore

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

    func testVersionOutputUsesSelectedLanguage() async throws {
        let english = OutputCapture()
        let englishExit = await CoreTendCLIRunner.run(.version, language: .en) { english.append($0) }
        XCTAssertEqual(englishExit, 0)
        XCTAssertEqual(english.values, ["CoreTend 2.1.0"])

        let french = OutputCapture()
        let frenchExit = await CoreTendCLIRunner.run(.version, language: .fr) { french.append($0) }
        XCTAssertEqual(frenchExit, 0)
        XCTAssertEqual(french.values, ["CoreTend 2.1.0"])
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

    private func cleanFixture() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-cli-clean-\(UUID())", isDirectory: true)
        for (path, size) in [("Library/Caches/com.example/a", 8192), ("Library/Developer/Xcode/Archives/2026/App.xcarchive/x", 4096)] {
            let url = home.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 2, count: size).write(to: url)
        }
        return home
    }

    func testCleanParsesItsFlags() throws {
        guard case .clean(nil, false, .text) = try CLICommand.parse(["clean"]) else { return XCTFail() }
        guard case .clean(.npmCache?, true, .json) = try CLICommand.parse(["clean", "--confirm", "--rule", "cleanup.npmcache", "--format", "json"]) else { return XCTFail() }
        XCTAssertThrowsError(try CLICommand.parse(["clean", "--rule", "scan.explore"]), "only cleanup rules")
        guard case .mcp = try CLICommand.parse(["mcp"]) else { return XCTFail() }
    }

    func testCleanWithoutConfirmMovesNothingAndWithConfirmMovesOnlySafeItems() async throws {
        let home = try cleanFixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let trash = RecordingTrash()
        var dry = CleanCommand(rule: nil, confirm: false, format: .text, language: .en)
        dry.home = home; dry.trash = trash
        let dryLines = Lines()
        let dryExit = await dry.run { dryLines.append($0) }
        XCTAssertEqual(dryExit, 0)
        XCTAssertTrue(trash.moved.isEmpty)
        XCTAssertTrue(dryLines.all.last?.contains("Nothing moved") == true)

        var real = CleanCommand(rule: nil, confirm: true, format: .text, language: .en)
        real.home = home; real.trash = trash
        let exit = await real.run { _ in }
        XCTAssertEqual(exit, 0)
        XCTAssertEqual(trash.moved.map(\.lastPathComponent), ["com.example"], "the medium-risk archive is not moved without --rule")
    }

    func testMCPServerAnswersInitializeListsReadOnlyToolsAndIgnoresNotifications() async throws {
        let home = try cleanFixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let server = MCPServer(home: home)
        let initializeReply = await server.handle(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}"#)
        let initialize = try XCTUnwrap(initializeReply)
        XCTAssertTrue(initialize.contains(#""name":"coretend""#))
        let notification = await server.handle(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#)
        XCTAssertNil(notification)
        let listReply = await server.handle(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)
        let list = try XCTUnwrap(listReply)
        for tool in ["disk_usage", "cleanup_candidates", "largest_items", "app_leftovers"] { XCTAssertTrue(list.contains(tool), tool) }
        let callReply = await server.handle(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"cleanup_candidates","arguments":{}}}"#)
        let call = try XCTUnwrap(callReply)
        XCTAssertTrue(call.contains("cleanup.usercaches"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.appendingPathComponent("Library/Caches/com.example/a").path), "read-only")
        let unknownReply = await server.handle(#"{"jsonrpc":"2.0","id":4,"method":"files/delete"}"#)
        let unknown = try XCTUnwrap(unknownReply)
        XCTAssertTrue(unknown.contains("-32601"))
    }
}

private final class RecordingTrash: TrashClient, @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    var moved: [URL] { lock.lock(); defer { lock.unlock() }; return urls }
    func moveToTrash(_ url: URL) async throws -> URL {
        record(url)
        return url
    }
    private func record(_ url: URL) { lock.withLock { urls.append(url) } }
}

private final class Lines: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    var all: [String] { lock.lock(); defer { lock.unlock() }; return lines }
    func append(_ line: String) { lock.lock(); lines.append(line); lock.unlock() }
}
