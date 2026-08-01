import Testing
import Foundation
@testable import SafetyCore

private func makeTempRoot(_ prefix: String) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite("PathValidator")
struct PathValidatorTests {
    let tempRoot: URL
    let validator: PathValidator

    init() throws {
        tempRoot = try makeTempRoot("coretend-tests")
        validator = PathValidator(allowedRoots: [tempRoot])
    }

    private func makeFile(_ name: String) throws -> URL {
        let url = tempRoot.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        return url
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    @Test func validFileInsideRootPasses() throws {
        defer { cleanup() }
        let file = try makeFile("ok.txt")
        #expect(try validator.validate(file).path == file.standardizedFileURL.path)
    }

    @Test func emptyPathRejected() {
        defer { cleanup() }
        #expect(throws: SafetyError.self) { try validator.validate(URL(fileURLWithPath: "")) }
    }

    @Test func rootRejected() {
        defer { cleanup() }
        #expect(throws: SafetyError.self) { try validator.validate(URL(fileURLWithPath: "/")) }
    }

    @Test func systemRejected() {
        defer { cleanup() }
        #expect(throws: SafetyError.self) {
            try validator.validate(URL(fileURLWithPath: "/System/Library/CoreServices"))
        }
    }

    @Test func binRejected() {
        defer { cleanup() }
        #expect(throws: SafetyError.self) { try validator.validate(URL(fileURLWithPath: "/bin/ls")) }
    }

    @Test func sbinRejected() {
        defer { cleanup() }
        #expect(throws: SafetyError.self) { try validator.validate(URL(fileURLWithPath: "/sbin/mount")) }
    }

    @Test func usrBinRejected() {
        defer { cleanup() }
        #expect(throws: SafetyError.self) { try validator.validate(URL(fileURLWithPath: "/usr/bin/env")) }
    }

    @Test func usrLibRejected() {
        defer { cleanup() }
        #expect(throws: SafetyError.self) { try validator.validate(URL(fileURLWithPath: "/usr/lib/dyld")) }
    }

    @Test func homeDirectoryItselfRejected() {
        defer { cleanup() }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let homeValidator = PathValidator(allowedRoots: [home])
        #expect(throws: SafetyError.self) { try homeValidator.validate(home) }
    }

    @Test func outsideAllowedRootsRejected() {
        defer { cleanup() }
        #expect(throws: SafetyError.self) {
            try validator.validate(URL(fileURLWithPath: "/private/tmp/other-file"))
        }
    }

    @Test func dotDotTraversalRejected() {
        defer { cleanup() }
        let sneaky = tempRoot.appendingPathComponent("../../etc/passwd")
        #expect(throws: SafetyError.self) { try validator.validate(sneaky) }
    }

    @Test func prefixBoundaryNotConfused() {
        defer { cleanup() }
        // "/a/bc" must not count as under "/a/b".
        #expect(!PathValidator.isPath(tempRoot.path + "x/file", under: tempRoot.path))
        #expect(PathValidator.isPath(tempRoot.path + "/file", under: tempRoot.path))
    }

    @Test func symlinkEscapingAllowlistRejected() throws {
        defer { cleanup() }
        let outside = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-outside-\(UUID().uuidString).txt")
        try Data("secret".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        let link = tempRoot.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        #expect(throws: SafetyError.self) { try validator.validate(link) }
    }

    @Test func symlinkInsideAllowlistPasses() throws {
        defer { cleanup() }
        let target = try makeFile("target.txt")
        let link = tempRoot.appendingPathComponent("inlink")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(throws: Never.self) { try validator.validate(link) }
    }

    @Test func unicodePathPasses() throws {
        defer { cleanup() }
        let file = try makeFile("éüñ🙂-fichier.txt")
        #expect(throws: Never.self) { try validator.validate(file) }
    }

    @Test func veryLongPathHandled() throws {
        defer { cleanup() }
        var dir = tempRoot
        for i in 0..<20 {
            dir = dir.appendingPathComponent("subdir-level-\(i)-padding-padding")
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("deep.txt")
        try Data("x".utf8).write(to: file)
        #expect(throws: Never.self) { try validator.validate(file) }
    }
}

@Suite("SafetyCenter")
struct SafetyCenterTests {
    let tempRoot: URL

    init() throws {
        tempRoot = try makeTempRoot("coretend-center")
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    @Test func dryRunDoesNotDelete() async throws {
        defer { cleanup() }
        let file = tempRoot.appendingPathComponent("victim.txt")
        try Data("data".utf8).write(to: file)
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [tempRoot]), dryRun: true)
        let op = try await center.approve(url: file, logicalSize: 4, ruleID: "test", risk: .low)
        let result = await center.execute([op])
        #expect(result.wasDryRun)
        #expect(result.executed.count == 1)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func vanishedFileSkippedAtExecution() async throws {
        defer { cleanup() }
        let file = tempRoot.appendingPathComponent("gone.txt")
        try Data("data".utf8).write(to: file)
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [tempRoot]), dryRun: true)
        let op = try await center.approve(url: file, logicalSize: 4, ruleID: "test", risk: .low)
        try FileManager.default.removeItem(at: file)
        let result = await center.execute([op])
        #expect(result.executed.isEmpty)
        #expect(result.skipped.count == 1)
    }

    @Test func symlinkSwappedAfterApprovalRejected() async throws {
        defer { cleanup() }
        let file = tempRoot.appendingPathComponent("swap.txt")
        try Data("data".utf8).write(to: file)
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [tempRoot]), dryRun: false)
        let op = try await center.approve(url: file, logicalSize: 4, ruleID: "test", risk: .low)
        // Replace the file with a symlink pointing outside the allowlist.
        let outside = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-swap-target-\(UUID().uuidString).txt")
        try Data("outside".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: outside)
        let result = await center.execute([op])
        #expect(result.executed.isEmpty, "swapped symlink must be skipped")
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }
}

private actor MockAuditSink: SafetyAuditSink {
    private(set) var events: [SafetyAuditEvent] = []
    func recordSafetyEvent(_ event: SafetyAuditEvent) async { events.append(event) }
}

@Suite("SafetyCenter audit sink")
struct SafetyCenterAuditSinkTests {
    let tempRoot: URL

    init() throws {
        tempRoot = try makeTempRoot("coretend-audit-sink")
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    @Test func dryRunEmitsApprovedThenDryRunNeverExecuted() async throws {
        defer { cleanup() }
        let file = tempRoot.appendingPathComponent("victim.txt")
        try Data("data".utf8).write(to: file)
        let sink = MockAuditSink()
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [tempRoot]), dryRun: true, sink: sink)
        let op = try await center.approve(url: file, logicalSize: 4, ruleID: "test", risk: .low)
        _ = await center.execute([op])
        let stages = await sink.events.map(\.stage)
        #expect(stages == [.approved, .dryRun])
        #expect(!stages.contains(.executed), "a dry run must never be recorded as executed")
    }

    @Test func realExecutionEmitsExecutedNotDryRun() async throws {
        defer { cleanup() }
        let file = tempRoot.appendingPathComponent("victim.txt")
        try Data("data".utf8).write(to: file)
        let sink = MockAuditSink()
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [tempRoot]), dryRun: false, sink: sink)
        let op = try await center.approve(url: file, logicalSize: 4, ruleID: "test", risk: .low)
        _ = await center.execute([op])
        let stages = await sink.events.map(\.stage)
        #expect(stages == [.approved, .executed])
        #expect(!stages.contains(.dryRun))
    }

    @Test func invalidPathEmitsErrorEvent() async throws {
        defer { cleanup() }
        let sink = MockAuditSink()
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [tempRoot]), dryRun: true, sink: sink)
        _ = try? await center.approve(url: URL(fileURLWithPath: "/System/Library"), logicalSize: 0, ruleID: "test", risk: .low)
        let events = await sink.events
        #expect(events.count == 1)
        #expect(events.first?.stage == .error)
    }

    @Test func vanishedFileEmitsSkippedEvent() async throws {
        defer { cleanup() }
        let file = tempRoot.appendingPathComponent("gone.txt")
        try Data("data".utf8).write(to: file)
        let sink = MockAuditSink()
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [tempRoot]), dryRun: true, sink: sink)
        let op = try await center.approve(url: file, logicalSize: 4, ruleID: "test", risk: .low)
        try FileManager.default.removeItem(at: file)
        _ = await center.execute([op])
        let stages = await sink.events.map(\.stage)
        #expect(stages == [.approved, .skipped])
    }
}
