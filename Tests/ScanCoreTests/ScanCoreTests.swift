import Foundation
import XCTest
import CoreGraphics
import ImageIO
import ProductContract
@testable import ScanCore

final class SimilarImageEngineTests: XCTestCase {
    func testReportsVisualCopiesAndSkipsSymlinkWithoutChangingFixture() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-images-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.png")
        let second = root.appendingPathComponent("second.png")
        let opposite = root.appendingPathComponent("opposite.png")
        let link = root.appendingPathComponent("link.png")
        try writePattern(to: first, reversed: false)
        try FileManager.default.copyItem(at: first, to: second)
        try writePattern(to: opposite, reversed: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: first)
        let before = try Data(contentsOf: first)

        let report = try await SimilarImageEngine().findSimilar(in: [first, second, opposite, link])
        XCTAssertEqual(report.candidates.count, 1)
        XCTAssertEqual(report.candidates.first?.first, first)
        XCTAssertEqual(report.candidates.first?.second, second)
        XCTAssertEqual(report.skippedCount, 1)
        XCTAssertEqual(try Data(contentsOf: first), before)
    }

    func testCandidateLimitIsReported() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-images-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.png")
        let second = root.appendingPathComponent("second.png")
        try writePattern(to: first, reversed: false)
        try FileManager.default.copyItem(at: first, to: second)
        let report = try await SimilarImageEngine(maximumCandidates: 1).findSimilar(in: [first, second])
        XCTAssertTrue(report.candidates.isEmpty)
        XCTAssertEqual(report.skippedCount, 1)
    }

    private func writePattern(to url: URL, reversed: Bool) throws {
        var pixels = [UInt8](repeating: 255, count: 9 * 8 * 4)
        for y in 0..<8 { for x in 0..<9 {
            let value = UInt8((reversed ? 8 - x : x) * 28)
            let index = (y * 9 + x) * 4
            pixels[index] = value; pixels[index + 1] = value; pixels[index + 2] = value
        }}
        guard let context = CGContext(data: &pixels, width: 9, height: 8, bitsPerComponent: 8, bytesPerRow: 36,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}

final class ScanCoreTests: XCTestCase {
    func testMissingScanRootReportsMissingCause() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-missing-scan-\(UUID())", isDirectory: true)
        var failures: [(String, String)] = []
        for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: .explore)])) {
            if case .itemFailure(let path, let reason) = event { failures.append((path, reason)) }
        }
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures.first?.0, root.path)
        XCTAssertEqual(failures.first?.1, "missing")
    }

    func testSymlinkScanRootIsReportedWithoutTraversingTarget() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-symlink-root-\(UUID())", isDirectory: true)
        let target = base.appendingPathComponent("target", isDirectory: true)
        let link = base.appendingPathComponent("link", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = target.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: file)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        var failures: [(String, String)] = []
        var results: [URL] = []
        for try await event in LocalScanEngine().scan(.init(roots: [.init(url: link, ruleID: .explore)])) {
            switch event {
            case .itemFailure(let path, let reason): failures.append((path, reason))
            case .result(let result): results.append(result.url)
            default: break
            }
        }
        XCTAssertEqual(failures.map(\.1), ["root_symlink"])
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), Data("keep".utf8))
    }

    func testExcludedRootReportsSettingsExclusion() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-excluded-root-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var failures: [String] = []
        for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: .explore)], exclusions: [root])) {
            if case .itemFailure(_, let reason) = event { failures.append(reason) }
        }
        XCTAssertEqual(failures, ["root_excluded"])
    }

    func testScanFindsFixtureFilesAndHonorsExclusionsWithoutChangingTree() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-scan-\(UUID())", isDirectory: true)
        let excluded = root.appendingPathComponent("excluded", isDirectory: true)
        try FileManager.default.createDirectory(at: excluded, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let candidate = root.appendingPathComponent("candidate.tmp")
        let ignored = excluded.appendingPathComponent("ignored.tmp")
        try Data(repeating: 7, count: 32).write(to: candidate)
        try Data("ignore".utf8).write(to: ignored)
        let engine = LocalScanEngine()
        let request = ScanRequest(roots: [ScanRoot(url: root, ruleID: .explore)], exclusions: [excluded])
        var results: [ScanResult] = []
        for try await event in engine.scan(request) { if case .result(let value) = event { results.append(value) } }
        XCTAssertEqual(results.map { $0.url.resolvingSymlinksInPath().path }, [candidate.resolvingSymlinksInPath().path])
        XCTAssertEqual(try Data(contentsOf: candidate).count, 32)
        XCTAssertTrue(FileManager.default.fileExists(atPath: ignored.path))
    }

    func testScanReportsSymlinkAsNoCandidate() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-scan-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("target.txt")
        let link = root.appendingPathComponent("linked.txt")
        try Data("source".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let engine = LocalScanEngine()
        var urls: [URL] = []
        for try await event in engine.scan(.init(roots: [.init(url: root, ruleID: .explore)])) {
            if case .result(let result) = event { urls.append(result.url) }
        }
        XCTAssertEqual(urls.map { $0.resolvingSymlinksInPath().path }, [target.resolvingSymlinksInPath().path])
    }
}

final class TreemapLayoutTests: XCTestCase {
    func testKnownByteAreasAreProportionalAndCoverCanvas() {
        let tiles = TreemapLayout.tiles(for: [.init(id: "large", bytes: 300), .init(id: "small", bytes: 100)],
                                        size: CGSize(width: 400, height: 200))
        XCTAssertEqual(tiles.count, 2)
        XCTAssertEqual(tiles.first(where: { $0.id == "large" })?.areaShare ?? 0, 0.75, accuracy: 0.0001)
        XCTAssertEqual(tiles.first(where: { $0.id == "small" })?.areaShare ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertEqual(tiles.reduce(0) { $0 + $1.frame.width * $1.frame.height }, 80_000, accuracy: 0.1)
    }

    func testUnknownAndNonpositiveMeasurementsCannotReceiveTileArea() {
        let tiles = TreemapLayout.tiles(for: [.init(id: "known", bytes: 80), .init(id: "zero", bytes: 0), .init(id: "negative", bytes: -5)],
                                        size: CGSize(width: 200, height: 100))
        XCTAssertEqual(tiles.map(\.id), ["known"])
        XCTAssertEqual(tiles.first?.areaShare, 1)
    }
}

final class ExplorePresetTests: XCTestCase {
    func testLargePresetUsesKnownAllocatedBytesAndInclusiveGiBThreshold() {
        let root = FileManager.default.temporaryDirectory
        let atThreshold = result(root.appendingPathComponent("threshold"), allocated: .known(1_073_741_824), modified: nil)
        let below = result(root.appendingPathComponent("below"), allocated: .known(1_073_741_823), modified: nil)
        let unknown = result(root.appendingPathComponent("unknown"), allocated: .unknown(reason: "cloud"), modified: nil)
        XCTAssertTrue(ExplorePreset.largeLocal.matches(atThreshold, evaluatedAt: .distantPast))
        XCTAssertFalse(ExplorePreset.largeLocal.matches(below, evaluatedAt: .distantPast))
        XCTAssertFalse(ExplorePreset.largeLocal.matches(unknown, evaluatedAt: .distantPast))
    }

    func testOlderPresetUsesExplicit365DayCutoffAndRequiresKnownDate() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let cutoff = now.addingTimeInterval(-365 * 24 * 60 * 60)
        let old = result(FileManager.default.temporaryDirectory.appendingPathComponent("old"), allocated: .known(1), modified: cutoff)
        let recent = result(FileManager.default.temporaryDirectory.appendingPathComponent("recent"), allocated: .known(1), modified: cutoff.addingTimeInterval(1))
        let unknown = result(FileManager.default.temporaryDirectory.appendingPathComponent("unknown-date"), allocated: .known(1), modified: nil)
        XCTAssertTrue(ExplorePreset.olderThan365Days.matches(old, evaluatedAt: now))
        XCTAssertFalse(ExplorePreset.olderThan365Days.matches(recent, evaluatedAt: now))
        XCTAssertFalse(ExplorePreset.olderThan365Days.matches(unknown, evaluatedAt: now))
    }

    private func result(_ url: URL, allocated: ProductMeasurement<Int64>, modified: Date?) -> ScanResult {
        ScanResult(url: url, ruleID: .explore, logicalBytes: .unknown(reason: "unused"), allocatedBytes: allocated, modifiedAt: modified, risk: .low)
    }
}

final class DuplicateEngineTests: XCTestCase {
    func testFindsExactCopiesAndKeepsOneCandidate() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-duplicates-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.bin")
        let second = root.appendingPathComponent("second.bin")
        let unrelated = root.appendingPathComponent("unrelated.bin")
        try Data(repeating: 1, count: 128 * 1024).write(to: first)
        try Data(repeating: 1, count: 128 * 1024).write(to: second)
        try Data(repeating: 2, count: 128 * 1024).write(to: unrelated)
        let candidates = [first, second, unrelated].map { ScanResult(url: $0, ruleID: .explore, logicalBytes: .known(131072), allocatedBytes: .known(131072), modifiedAt: nil, risk: .low) }
        let report = try await DuplicateEngine().findGroups(in: candidates)
        XCTAssertEqual(report.groups.count, 1)
        XCTAssertEqual(report.groups[0].files.count, 2)
        XCTAssertEqual(report.groups[0].suggestedKeeper, first)
        XCTAssertTrue(report.groups[0].files.contains(second))
        let firstContents = try Data(contentsOf: first)
        let secondContents = try Data(contentsOf: second)
        XCTAssertEqual(firstContents, secondContents)
    }

    func testHardLinksDoNotAppearAsSeparateDuplicateFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-hardlinks-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.bin")
        let link = root.appendingPathComponent("hardlink.bin")
        try Data("same inode".utf8).write(to: first)
        try FileManager.default.linkItem(at: first, to: link)
        let candidates = [first, link].map { ScanResult(url: $0, ruleID: .explore, logicalBytes: .known(10), allocatedBytes: .known(10), modifiedAt: nil, risk: .low) }
        let report = try await DuplicateEngine().findGroups(in: candidates)
        XCTAssertTrue(report.groups.isEmpty)
    }

    func testSymlinkCandidateIsRejectedInsteadOfHashingTarget() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-symlink-duplicates-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("target.bin")
        let alias = root.appendingPathComponent("alias.bin")
        try Data(repeating: 9, count: 1024).write(to: target)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
        let candidates = [target, alias].map { ScanResult(url: $0, ruleID: .duplicates, logicalBytes: .known(1024), allocatedBytes: .known(1024), modifiedAt: nil, risk: .low) }
        let report = try await DuplicateEngine().findGroups(in: candidates)
        XCTAssertTrue(report.groups.isEmpty)
        XCTAssertEqual(report.issues.first?.reason, "hash_failed_or_file_changed")
        XCTAssertEqual(try Data(contentsOf: target).count, 1024)
    }
}

final class CleanupRuleCatalogTests: XCTestCase {
    func testSevenCleanupRulesStayScopedUnderInjectedHome() throws {
        let home = URL(fileURLWithPath: "/tmp/coretend-fixture-home", isDirectory: true)
        XCTAssertEqual(CleanupRuleCatalog.rules.count, 7)
        for rule in CleanupRuleCatalog.rules {
            XCTAssertTrue(rule.root(homeDirectory: home).path.hasPrefix(home.path + "/"))
        }
        let downloads = try XCTUnwrap(CleanupRuleCatalog.rule(.incompleteDownloads))
        XCTAssertTrue(downloads.includes(URL(fileURLWithPath: home.appendingPathComponent("Downloads/item.download").path)))
        XCTAssertFalse(downloads.includes(URL(fileURLWithPath: home.appendingPathComponent("Downloads/report.pdf").path)))
        let logs = try XCTUnwrap(CleanupRuleCatalog.rule(.userLogs))
        let logsRoot = logs.root(homeDirectory: home)
        XCTAssertFalse(logs.includes(logsRoot.appendingPathComponent("DiagnosticReports/app.crash"), rootURL: logsRoot))
        let crashReports = try XCTUnwrap(CleanupRuleCatalog.rule(.crashReports))
        XCTAssertTrue(crashReports.includes(URL(fileURLWithPath: "/tmp/crashes/app.ips")))
        XCTAssertFalse(crashReports.includes(URL(fileURLWithPath: "/tmp/crashes/readme.txt")))
    }

    func testIncompleteDownloadsScanReturnsOnlyDownloadPartials() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-downloads-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let partial = root.appendingPathComponent("unfinished.download")
        let document = root.appendingPathComponent("keep.pdf")
        try Data("partial".utf8).write(to: partial)
        try Data("user document".utf8).write(to: document)
        var paths: [String] = []
        for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: .incompleteDownloads)])) {
            if case .result(let result) = event { paths.append(result.url.lastPathComponent) }
        }
        XCTAssertEqual(paths, ["unfinished.download"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: document.path))
    }
}
