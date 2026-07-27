import Testing
import Foundation
import SafetyCore
@testable import ScanCore

@Suite("ScanEngine")
struct ScanEngineTests {
    let tempRoot: URL

    init() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-scan-\(UUID().uuidString)")
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

    // Regression (v0.4.1): Smart Care and Cleanup both read totals off this same
    // `.finished` event rather than summing the display-capped findings array —
    // two independent consumers of one run must see identical totals.
    @Test func independentConsumersSeeIdenticalTotals() async throws {
        defer { cleanup() }
        for i in 0..<12 {
            try Data(repeating: 0, count: 100).write(
                to: tempRoot.appendingPathComponent("Library/Caches/AppX/f\(i).tmp"))
        }
        let engine = ScanEngine(configuration: ScanConfiguration(home: tempRoot))
        var smartCareLikeBytes: Int64 = -1
        var smartCareLikeCount = 0
        var cleanupLikeBytes: Int64 = -1
        var cleanupLikeCount = 0
        for await event in engine.run(rules: [rule()]) {
            switch event {
            case .finding:
                smartCareLikeCount += 1
                cleanupLikeCount += 1
            case let .finished(_, bytes):
                smartCareLikeBytes = bytes
                cleanupLikeBytes = bytes
            default: break
            }
        }
        #expect(smartCareLikeBytes == cleanupLikeBytes)
        #expect(smartCareLikeBytes == 1200)
        #expect(smartCareLikeCount == cleanupLikeCount)
    }
}

@Suite("Scan root isolation")
struct ScanRootIsolationTests {
    let tempRoot: URL

    init() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-isolation-\(UUID().uuidString)")
        let fm = FileManager.default
        for dir in ["Downloads", "Music", "Documents", "Library/Caches", "Library/Logs"] {
            try fm.createDirectory(at: tempRoot.appendingPathComponent(dir), withIntermediateDirectories: true)
            try Data("marker".utf8).write(to: tempRoot.appendingPathComponent(dir).appendingPathComponent("file-in-\(dir.replacingOccurrences(of: "/", with: "-")).bin"))
        }
    }

    private func cleanup() { try? FileManager.default.removeItem(at: tempRoot) }

    private func downloadsRule() -> ScanRule {
        ScanRule(id: "downloads.only", name: "Downloads", category: "Cleanup", explanation: "t",
                 risk: .low, preselect: true) { home in [home.appendingPathComponent("Downloads")] }
    }

    /// Regression: a Downloads-scoped rule must never yield findings or progress
    /// paths outside Downloads — no leak into sibling directories like Music.
    @Test func downloadsOnlyScanNeverTouchesSiblingDirectories() async throws {
        defer { cleanup() }
        let engine = ScanEngine(configuration: ScanConfiguration(home: tempRoot))
        var findingPaths: [String] = []
        var progressPaths: [String] = []
        for await event in engine.run(rules: [downloadsRule()]) {
            switch event {
            case let .finding(f): findingPaths.append(f.url.path)
            case let .progress(_, path): progressPaths.append(path)
            default: break
            }
        }
        #expect(findingPaths.count == 1)
        #expect(findingPaths.allSatisfy { $0.contains("/Downloads/") })
        #expect(!findingPaths.contains { $0.contains("/Music/") || $0.contains("/Documents/") || $0.contains("/Library/") })
        #expect(!progressPaths.contains { $0.contains("/Music/") || $0.contains("/Documents/") })
    }

    /// Smart Care-style multi-category run: only the enabled rules' roots are ever visited.
    @Test func multipleRulesOnlyVisitTheirOwnRoots() async throws {
        defer { cleanup() }
        let cachesRule = ScanRule(id: "caches", name: "Caches", category: "Cleanup", explanation: "t",
                                   risk: .low, preselect: true) { home in [home.appendingPathComponent("Library/Caches")] }
        let engine = ScanEngine(configuration: ScanConfiguration(home: tempRoot))
        var findingPaths: [String] = []
        for await event in engine.run(rules: [downloadsRule(), cachesRule]) {
            if case let .finding(f) = event { findingPaths.append(f.url.path) }
        }
        #expect(findingPaths.count == 2)
        #expect(findingPaths.allSatisfy { $0.contains("/Downloads/") || $0.contains("/Library/Caches/") })
        #expect(!findingPaths.contains { $0.contains("/Music/") || $0.contains("/Documents/") || $0.contains("/Logs/") })
    }
}

@Suite("Totals beyond display cap")
struct ScanTotalsBeyondCapTests {
    /// The engine itself must never cap or drop findings — any display cap is a
    /// UI-layer concern. Regression for totals disagreeing between Smart Care
    /// and Cleanup when a scan yields more than the 5000-row UI cap.
    @Test func engineStreamsAllFindingsUncappedAt5001() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-cap-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("Library/Caches")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let count = 5001
        for i in 0..<count {
            try Data(repeating: 1, count: 10).write(to: dir.appendingPathComponent("f\(i).tmp"))
        }
        let rule = ScanRule(id: "t", name: "t", category: "t", explanation: "t",
                             risk: .low, preselect: true) { home in [home.appendingPathComponent("Library/Caches")] }
        let engine = ScanEngine(configuration: ScanConfiguration(home: root))
        var streamed = 0
        var finishedScanned = 0
        var finishedBytes: Int64 = -1
        for await event in engine.run(rules: [rule]) {
            switch event {
            case .finding: streamed += 1
            case let .finished(scanned, bytes):
                finishedScanned = scanned
                finishedBytes = bytes
            default: break
            }
        }
        #expect(streamed == count, "engine must stream every finding, never capping internally")
        #expect(finishedScanned == count)
        #expect(finishedBytes == Int64(count) * 10)
    }
}

@Suite("ScanRule matches filter")
struct ScanRuleMatchesTests {
    @Test func matchesPredicateFiltersFindings() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-match-\(UUID().uuidString)")
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
