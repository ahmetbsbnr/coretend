import Testing
import Foundation
import SafetyCore
@testable import ScanCore

@Suite("ScanEngine")
struct ScanEngineTests {
    let tempRoot: URL

    init() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-scan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempRoot.appendingPathComponent("Library/Caches/AppX"),
            withIntermediateDirectories: true)
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    private func rule(minimumAgeDays: Int = 0) -> ScanRule {
        ScanRule(id: "test.caches", name: "Test caches", category: "Test",
                 explanation: "test", minimumAgeDays: minimumAgeDays,
                 risk: .low, preselect: true) { home in
            [home.appendingPathComponent("Library/Caches")]
        }
    }

    @Test func scanFindsFilesAndReportsSizes() async throws {
        defer { cleanup() }
        let file = tempRoot.appendingPathComponent("Library/Caches/AppX/blob.bin")
        try Data(repeating: 0, count: 1024).write(to: file)
        let engine = ScanEngine(configuration: ScanConfiguration(home: tempRoot))
        var findings: [ScanFinding] = []
        var finishedBytes: Int64 = -1
        for await event in engine.run(rules: [rule()]) {
            if case let .finding(f) = event { findings.append(f) }
            if case let .finished(_, bytes) = event { finishedBytes = bytes }
        }
        #expect(findings.count == 1)
        #expect(findings.first?.logicalSize == 1024)
        #expect(finishedBytes == 1024)
    }

    @Test func minimumAgeExcludesFreshFiles() async throws {
        defer { cleanup() }
        let file = tempRoot.appendingPathComponent("Library/Caches/AppX/fresh.log")
        try Data("fresh".utf8).write(to: file)
        let engine = ScanEngine(configuration: ScanConfiguration(home: tempRoot))
        var findings = 0
        for await event in engine.run(rules: [rule(minimumAgeDays: 7)]) {
            if case .finding = event { findings += 1 }
        }
        #expect(findings == 0, "file modified today must not match a 7-day rule")
    }

    @Test func missingRootYieldsFinishedNotError() async {
        defer { cleanup() }
        let engine = ScanEngine(configuration: ScanConfiguration(
            home: tempRoot.appendingPathComponent("does-not-exist")))
        var sawFinished = false
        for await event in engine.run(rules: [rule()]) {
            if case .finished = event { sawFinished = true }
        }
        #expect(sawFinished)
    }

    @Test func symlinkedDirectoryNotDescended() async throws {
        defer { cleanup() }
        let outside = tempRoot.appendingPathComponent("outside-dir")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: outside.appendingPathComponent("secret.txt"))
        let link = tempRoot.appendingPathComponent("Library/Caches/loop")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let engine = ScanEngine(configuration: ScanConfiguration(home: tempRoot))
        var paths: [String] = []
        for await event in engine.run(rules: [rule()]) {
            if case let .finding(f) = event { paths.append(f.url.path) }
        }
        #expect(!paths.contains { $0.contains("secret.txt") })
    }

    @Test func cancellationStopsStream() async throws {
        defer { cleanup() }
        for i in 0..<200 {
            try Data("x".utf8).write(
                to: tempRoot.appendingPathComponent("Library/Caches/AppX/f\(i).tmp"))
        }
        let engine = ScanEngine(configuration: ScanConfiguration(home: tempRoot))
        var count = 0
        for await event in engine.run(rules: [rule()]) {
            if case .finding = event {
                count += 1
                if count >= 5 { break }  // terminating the loop cancels the producer
            }
        }
        #expect(count == 5)
    }
}

@Suite("ScanRule matches filter")
struct ScanRuleMatchesTests {
    @Test func matchesPredicateFiltersFindings() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-match-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Downloads"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("x".utf8).write(to: root.appendingPathComponent("Downloads/file.crdownload"))
        try Data("x".utf8).write(to: root.appendingPathComponent("Downloads/document.pdf"))
        let rule = ScanRule(id: "t.partial", name: "t", category: "t", explanation: "t",
                            risk: .low, preselect: true,
                            matches: { $0.pathExtension == "crdownload" }) { home in
            [home.appendingPathComponent("Downloads")]
        }
        let engine = ScanEngine(configuration: ScanConfiguration(home: root))
        var found: [String] = []
        for await event in engine.run(rules: [rule]) {
            if case let .finding(f) = event { found.append(f.url.lastPathComponent) }
        }
        #expect(found == ["file.crdownload"])
    }
}
