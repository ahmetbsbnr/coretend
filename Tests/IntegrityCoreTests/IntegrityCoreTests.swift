import Foundation
import Testing
@testable import IntegrityCore

@Suite("ProvenanceScanner")
struct ProvenanceScannerTests {
    @Test("a plain file with no quarantine attribute reports isQuarantined == false")
    func noQuarantine() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("plain.txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)

        let results = ProvenanceScanner.scan(folder: dir)
        #expect(results.count == 1)
        #expect(results[0].isQuarantined == false)
        #expect(results[0].sourceURL == nil)
    }

    @Test("a file carrying LSQuarantine metadata is reported as quarantined, with the fields the xattr actually stores")
    func withQuarantine() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var file = dir.appendingPathComponent("downloaded.dmg")
        try "bytes".write(to: file, atomically: true, encoding: .utf8)

        // The `com.apple.quarantine` xattr itself only ever holds flag,
        // timestamp, agent and an event UUID. The origin/data URLs a real
        // download carries live in LaunchServices' separate quarantine-events
        // database, keyed by that UUID — populated by a browser's real
        // download registration, not by `setResourceValues` from a
        // command-line test binary with no app-level LaunchServices context.
        // So only the xattr-backed fields are asserted here; a real download's
        // origin URL is what Downloads actually shows once a browser creates
        // the file, which this synthetic unit test cannot reproduce.
        var values = URLResourceValues()
        values.quarantineProperties = [
            "LSQuarantineAgentName": "Safari",
        ]
        try file.setResourceValues(values)

        let results = ProvenanceScanner.scan(folder: dir)
        #expect(results.count == 1)
        #expect(results[0].isQuarantined == true)
        #expect(results[0].agentName == "Safari")
    }

    @Test("directories are excluded, only regular files are reported")
    func skipsDirectories() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try FileManager.default.createDirectory(at: dir.appendingPathComponent("subfolder"), withIntermediateDirectories: true)
        try "x".write(to: dir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let results = ProvenanceScanner.scan(folder: dir)
        #expect(results.count == 1)
        #expect(results[0].name == "file.txt")
    }

    @Test("a missing folder returns an empty list rather than throwing")
    func missingFolder() {
        let results = ProvenanceScanner.scan(folder: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)"))
        #expect(results.isEmpty)
    }

    @Test("limit caps the number of results")
    func respectsLimit() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        for i in 0..<10 {
            try "x".write(to: dir.appendingPathComponent("f\(i).txt"), atomically: true, encoding: .utf8)
        }
        let results = ProvenanceScanner.scan(folder: dir, limit: 3)
        #expect(results.count == 3)
    }
}

@Suite("CodeSignInspector")
struct CodeSignInspectorTests {
    @Test("a system app is reported as Apple-signed and valid")
    func appleSystemApp() {
        // /System/Applications/Calculator.app exists on every supported macOS version.
        let info = CodeSignInspector.inspect(at: URL(fileURLWithPath: "/System/Applications/Calculator.app"))
        #expect(info.tier == .appleSigned)
        #expect(info.signatureValid == true)
    }

    @Test("a nonexistent path is reported unsigned, never crashes")
    func missingPath() {
        let info = CodeSignInspector.inspect(at: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).app"))
        #expect(info.tier == .adHocOrUnsigned)
        #expect(info.signatureValid == false)
    }

    @Test("a freshly-written plain file (no signature at all) is unsigned")
    func plainFileIsUnsigned() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).bin")
        try "not a bundle".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let info = CodeSignInspector.inspect(at: file)
        #expect(info.tier == .adHocOrUnsigned)
    }
}

@Suite("LoginItemScanner")
struct LoginItemScannerTests {
    @Test("scanning never throws and returns items with a non-empty label")
    func scanIsSafeAndLabeled() {
        let items = LoginItemScanner.scan()
        for item in items {
            #expect(!item.label.isEmpty)
            #expect(!item.plistPath.isEmpty)
        }
    }
}
