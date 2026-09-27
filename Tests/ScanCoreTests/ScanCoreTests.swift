import Foundation
import XCTest
import Darwin
import CoreGraphics
import ImageIO
import ProductContract
@testable import ScanCore

private final class ScanProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [DuplicateScanProgress] = []

    func append(_ progress: DuplicateScanProgress) {
        lock.lock(); defer { lock.unlock() }
        stored.append(progress)
    }

    var values: [DuplicateScanProgress] {
        lock.lock(); defer { lock.unlock() }
        return stored
    }
}

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

        let progress = ScanProgressRecorder()
        let report = try await SimilarImageEngine().findSimilar(in: [first, second, opposite, link], progress: progress.append)
        XCTAssertEqual(report.candidates.count, 1)
        XCTAssertEqual(report.candidates.first?.first, first)
        XCTAssertEqual(report.candidates.first?.second, second)
        XCTAssertEqual(report.skippedCount, 1)
        XCTAssertEqual(try Data(contentsOf: first), before)
        XCTAssertTrue(progress.values.contains(.imageCandidates(completedCandidates: 4, totalCandidates: 4)))
        XCTAssertTrue(progress.values.contains(.imageComparisons(completedPairs: 3, totalPairs: 3)))
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
    func testCloudBackedFixtureKeepsLogicalSizeAndDoesNotChangeFileData() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-cloud-scan-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("placeholder.txt")
        let contents = Data("locally available fixture bytes".utf8)
        try contents.write(to: file)

        let engine = LocalScanEngine(metadataReader: FixtureUbiquitousItemMetadataReader(cloudBackedPaths: [file.standardizedFileURL.path]))
        var result: ScanResult?
        for try await event in engine.scan(.init(roots: [.init(url: root, ruleID: .explore)])) {
            if case .result(let value) = event { result = value }
        }

        XCTAssertEqual(result?.logicalBytes, .known(Int64(contents.count)))
        XCTAssertEqual(result?.allocatedBytes, .unknown(reason: "cloud_backed_local_bytes_unverified"))
        XCTAssertEqual(try Data(contentsOf: file), contents)
    }

    func testLocalFixtureRetainsMeasuredAllocatedBytes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-local-scan-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("local.txt")
        try Data("local fixture".utf8).write(to: file)

        var result: ScanResult?
        for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: .explore)])) {
            if case .result(let value) = event { result = value }
        }

        guard let result else { return XCTFail("Expected the local fixture to be scanned") }
        if case .known(let allocatedBytes) = result.allocatedBytes {
            XCTAssertGreaterThan(allocatedBytes, 0)
        } else {
            XCTFail("Expected local allocated bytes to remain known")
        }
    }

    func testSparseFixtureKeepsLogicalAndAllocatedSizesDistinct() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-sparse-scan-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("sparse.bin")
        let descriptor = open(file.path, O_CREAT | O_WRONLY | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { close(descriptor) }
        guard ftruncate(descriptor, 8 * 1_024 * 1_024) == 0,
              pwrite(descriptor, [UInt8(1)], 1, 0) == 1 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        var result: ScanResult?
        for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: .explore)])) {
            if case .result(let value) = event { result = value }
        }
        guard let result,
              case .known(let logicalBytes) = result.logicalBytes,
              case .known(let allocatedBytes) = result.allocatedBytes else {
            return XCTFail("Expected both sparse file measurements to be known")
        }
        XCTAssertEqual(logicalBytes, 8 * 1_024 * 1_024)
        XCTAssertGreaterThan(allocatedBytes, 0)
        XCTAssertLessThan(allocatedBytes, logicalBytes)
    }

    func testHardLinkResultsSharePhysicalAllocationIdentity() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-hardlink-scan-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.bin")
        let alias = root.appendingPathComponent("second.bin")
        try Data(repeating: 8, count: 4_096).write(to: first)
        try FileManager.default.linkItem(at: first, to: alias)

        var results: [ScanResult] = []
        for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: .explore)])) {
            if case .result(let value) = event { results.append(value) }
        }
        XCTAssertEqual(results.count, 2)
        XCTAssertNotNil(results[0].allocationIdentity)
        XCTAssertEqual(results[0].allocationIdentity, results[1].allocationIdentity)
        XCTAssertEqual(results[0].allocatedBytes, results[1].allocatedBytes)
    }

    func testConsumerCancellationStopsScanBeforeNextFixtureFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-cancel-scan-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("first fixture".utf8).write(to: root.appendingPathComponent("first.txt"))
        try Data("second fixture".utf8).write(to: root.appendingPathComponent("second.txt"))
        let before = try fixtureTreeSnapshot(root)
        let reader = BlockingFixtureMetadataReader()
        let workerFinished = DispatchSemaphore(value: 0)
        let consumer = Task {
            var emittedFinished = false
            var failed = false
            do {
                for try await event in LocalScanEngine(metadataReader: reader, workerDidFinish: { workerFinished.signal() }).scan(
                    .init(roots: [.init(url: root, ruleID: .explore)])
                ) {
                    if case .finished = event { emittedFinished = true }
                }
            } catch { failed = true }
            return (emittedFinished, failed)
        }
        defer {
            consumer.cancel()
            reader.releaseFirstRead.signal()
        }

        await fulfillment(of: [reader.firstReadStarted], timeout: 2)
        consumer.cancel()
        reader.releaseFirstRead.signal()
        let (emittedFinished, failed) = await consumer.value
        XCTAssertEqual(workerFinished.wait(timeout: .now() + 2), .success)

        XCTAssertFalse(emittedFinished)
        XCTAssertFalse(failed)
        XCTAssertEqual(reader.readCount, 1)
        XCTAssertEqual(try fixtureTreeSnapshot(root), before)
    }

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
        let before = try fixtureTreeSnapshot(root)
        let engine = LocalScanEngine()
        let request = ScanRequest(roots: [ScanRoot(url: root, ruleID: .explore)], exclusions: [excluded])
        var results: [ScanResult] = []
        for try await event in engine.scan(request) { if case .result(let value) = event { results.append(value) } }
        XCTAssertEqual(results.map { $0.url.resolvingSymlinksInPath().path }, [candidate.resolvingSymlinksInPath().path])
        XCTAssertEqual(try fixtureTreeSnapshot(root), before)
    }

    private func fixtureTreeSnapshot(_ root: URL) throws -> [String: String] {
        var snapshot: [String: String] = [:]
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else {
            throw CocoaError(.fileReadUnknown)
        }
        for url in [root] + (enumerator.allObjects as? [URL] ?? []) {
            let values = try url.resourceValues(forKeys: Set(keys))
            let relative = url == root ? "." : String(url.path.dropFirst(root.path.count + 1))
            let content: String
            if values.isRegularFile == true {
                content = try Data(contentsOf: url).base64EncodedString()
            } else if values.isSymbolicLink == true {
                content = try FileManager.default.destinationOfSymbolicLink(atPath: url.path)
            } else {
                content = ""
            }
            var info = stat()
            guard lstat(url.path, &info) == 0 else { throw CocoaError(.fileReadUnknown) }
            snapshot[relative] = "dir=\(values.isDirectory == true);file=\(values.isRegularFile == true);link=\(values.isSymbolicLink == true);size=\(values.fileSize ?? -1);device=\(info.st_dev);inode=\(info.st_ino);mode=\(info.st_mode);mtime=\(info.st_mtimespec.tv_sec).\(info.st_mtimespec.tv_nsec);ctime=\(info.st_ctimespec.tv_sec).\(info.st_ctimespec.tv_nsec);content=\(content)"
        }
        return snapshot
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

private struct FixtureUbiquitousItemMetadataReader: UbiquitousItemMetadataReading {
    let cloudBackedPaths: Set<String>

    func isUbiquitousItem(at url: URL) -> Bool? {
        cloudBackedPaths.contains(url.standardizedFileURL.path)
    }
}

private final class BlockingFixtureMetadataReader: UbiquitousItemMetadataReading, @unchecked Sendable {
    let firstReadStarted = XCTestExpectation(description: "first metadata read started")
    let releaseFirstRead = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var reads = 0

    var readCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return reads
    }

    func isUbiquitousItem(at url: URL) -> Bool? {
        lock.lock()
        reads += 1
        let currentRead = reads
        lock.unlock()

        if currentRead == 1 {
            firstReadStarted.fulfill()
            releaseFirstRead.wait()
        }
        return false
    }
}

final class TreemapLayoutTests: XCTestCase {
    func testHardLinksContributePhysicalAllocationOnlyOnce() {
        let alias = TreemapInput(id: "/fixture/alias", bytes: 512, allocationIdentity: "device-1:inode-7")
        let canonical = TreemapInput(id: "/fixture/canonical", bytes: 512, allocationIdentity: "device-1:inode-7")
        let unique = TreemapInput(id: "/fixture/unique", bytes: 512, allocationIdentity: "device-1:inode-8")

        let tiles = TreemapLayout.tiles(for: [alias, unique, canonical], size: CGSize(width: 300, height: 120))

        XCTAssertEqual(tiles.map(\.id), ["/fixture/alias", "/fixture/unique"])
        XCTAssertEqual(tiles.reduce(Int64(0)) { $0 + $1.bytes }, 1_024)
    }

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
    func testExploreCategoriesUseExplicitCaseInsensitiveExtensionsAndUnknownFallback() {
        XCTAssertTrue(ExploreFileCategory.images.matches(URL(fileURLWithPath: "/fixture/PHOTO.HEIC")))
        XCTAssertTrue(ExploreFileCategory.videos.matches(URL(fileURLWithPath: "/fixture/clip.mov")))
        XCTAssertTrue(ExploreFileCategory.audio.matches(URL(fileURLWithPath: "/fixture/voice.flac")))
        XCTAssertTrue(ExploreFileCategory.documents.matches(URL(fileURLWithPath: "/fixture/report.PDF")))
        XCTAssertTrue(ExploreFileCategory.archives.matches(URL(fileURLWithPath: "/fixture/backup.7z")))
        XCTAssertTrue(ExploreFileCategory.other.matches(URL(fileURLWithPath: "/fixture/data.custom")))
        XCTAssertTrue(ExploreFileCategory.other.matches(URL(fileURLWithPath: "/fixture/README")))
        XCTAssertFalse(ExploreFileCategory.images.matches(URL(fileURLWithPath: "/fixture/report.pdf")))
        XCTAssertTrue(ExploreFileCategory.all.matches(URL(fileURLWithPath: "/fixture/README")))
    }

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
        let progress = ScanProgressRecorder()
        let report = try await DuplicateEngine().findGroups(in: candidates, progress: progress.append)
        XCTAssertEqual(report.groups.count, 1)
        XCTAssertEqual(report.groups[0].files.count, 2)
        XCTAssertEqual(report.groups[0].suggestedKeeper, first)
        XCTAssertTrue(report.groups[0].files.contains(second))
        let firstContents = try Data(contentsOf: first)
        let secondContents = try Data(contentsOf: second)
        XCTAssertEqual(firstContents, secondContents)
        XCTAssertEqual(progress.values.first, .duplicateHashing(completedCandidates: 0, totalCandidates: 3))
        XCTAssertEqual(progress.values.last, .duplicateHashing(completedCandidates: 3, totalCandidates: 3))
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
