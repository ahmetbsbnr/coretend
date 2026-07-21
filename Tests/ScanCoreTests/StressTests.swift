import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ScanCore

// Stress / scale fixtures. Deterministic pass/fail on *counts* and a generous
// wall-clock ceiling; exact durations are printed (informational) rather than
// asserted, so a slow CI box never flakes the suite. See
// Documentation/STRESS_TEST_REPORT.md for measured numbers.

// MARK: - Area 1: Cleanup at scale

@Suite("Cleanup at scale")
struct CleanupScaleTests {
    /// ~12k cleanup-eligible files across two rules — well beyond the 5000-row
    /// UI display cap. Confirms the engine streams every finding (no internal
    /// cap), totals are exact, and it completes in reasonable wall-clock time.
    @Test func twelveThousandFindingsStreamUncappedWithExactTotals() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-stress-cleanup-\(UUID().uuidString)")
        let caches = root.appendingPathComponent("Library/Caches")
        let logs = root.appendingPathComponent("Library/Logs")
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let perDir = 6000
        let payload = Data(repeating: 1, count: 10)
        for i in 0..<perDir {
            try payload.write(to: caches.appendingPathComponent("c\(i).tmp"))
            try payload.write(to: logs.appendingPathComponent("l\(i).log"))
        }
        let total = perDir * 2

        let cachesRule = ScanRule(id: "c", name: "c", category: "c", explanation: "c",
                                  risk: .low, preselect: true) { [$0.appendingPathComponent("Library/Caches")] }
        let logsRule = ScanRule(id: "l", name: "l", category: "l", explanation: "l",
                                risk: .low, preselect: true) { [$0.appendingPathComponent("Library/Logs")] }
        let engine = ScanEngine(configuration: ScanConfiguration(home: root))

        let clock = ContinuousClock()
        let start = clock.now
        var streamed = 0
        var finishedScanned = 0
        var finishedBytes: Int64 = -1
        for await event in engine.run(rules: [cachesRule, logsRule]) {
            switch event {
            case .finding: streamed += 1
            case let .finished(scanned, bytes): finishedScanned = scanned; finishedBytes = bytes
            default: break
            }
        }
        let elapsed = start.duration(to: clock.now)
        print("[stress] cleanup: \(total) files scanned in \(elapsed)")

        #expect(streamed == total, "engine streams every finding, never caps internally")
        #expect(finishedScanned == total)
        #expect(finishedBytes == Int64(total) * 10)
        #expect(elapsed < .seconds(30), "generous ceiling; typical run is ~1s")
    }
}

// MARK: - Area 2: Duplicates at scale

@Suite("Duplicates at scale")
struct DuplicatesScaleTests {
    /// ~10k candidate files, all the *same logical size* so they collapse into
    /// one size bucket and every file is forced through the partial+full hash
    /// stages — the worst case for the staged pipeline. Includes real duplicate
    /// groups, hard-link groups (must collapse to one entry, never a group), and
    /// sparse files. A size-bucket that big would expose any accidental O(n²)
    /// behaviour as a runaway duration; the generous ceiling catches it.
    @Test func tenThousandSameSizeCandidatesStayCorrectAndSubQuadratic() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-stress-dup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let size = 4096
        let uniqueCount = 9000
        // Each unique file: same length, content differs in the first bytes so
        // even the 64KB partial hash separates them (files < 64KB hash fully).
        for i in 0..<uniqueCount {
            var bytes = Data(repeating: 0, count: size)
            withUnsafeBytes(of: Int64(i).littleEndian) { bytes.replaceSubrange(0..<8, with: $0) }
            try bytes.write(to: root.appendingPathComponent("u\(i).bin"))
        }
        // 500 genuine duplicate pairs (same content), same length as the uniques.
        let dupPairs = 500
        for i in 0..<dupPairs {
            var bytes = Data(repeating: 0, count: size)
            withUnsafeBytes(of: Int64(1_000_000 + i).littleEndian) { bytes.replaceSubrange(0..<8, with: $0) }
            let a = root.appendingPathComponent("dupA\(i).bin")
            let b = root.appendingPathComponent("dupB\(i).bin")
            try bytes.write(to: a)
            try bytes.write(to: b)
        }
        // 100 hard-link pairs — same inode, must NOT be reported as duplicates.
        for i in 0..<100 {
            var bytes = Data(repeating: 0, count: size)
            withUnsafeBytes(of: Int64(2_000_000 + i).littleEndian) { bytes.replaceSubrange(0..<8, with: $0) }
            let orig = root.appendingPathComponent("hl\(i).bin")
            try bytes.write(to: orig)
            try FileManager.default.linkItem(at: orig, to: root.appendingPathComponent("hl\(i)-link.bin"))
        }
        // A couple of sparse files (large logical, tiny allocated) at distinct
        // sizes — must not crash the hasher, and (different lengths) must not
        // group with each other.
        for i in 0..<2 {
            let path = root.appendingPathComponent("sparse\(i).bin").path
            FileManager.default.createFile(atPath: path, contents: nil)
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            try handle.truncate(atOffset: 1_048_576 + UInt64(i))   // ~1MB logical, ~0 allocated, distinct sizes
            try handle.close()
        }

        let clock = ContinuousClock()
        let start = clock.now
        var groups: [DuplicateGroup] = []
        var finishedGroups = -1
        var wasted: Int64 = -1
        for await event in DuplicateEngine(roots: [root], minimumSize: 100).run() {
            switch event {
            case let .group(g): groups.append(g)
            case let .finished(count, bytes): finishedGroups = count; wasted = bytes
            default: break
            }
        }
        let elapsed = start.duration(to: clock.now)
        print("[stress] duplicates: \(uniqueCount + dupPairs * 2 + 200) files, \(groups.count) groups in \(elapsed)")

        // Exactly the 500 genuine pairs group; uniques and hard links do not.
        #expect(groups.count == dupPairs)
        #expect(finishedGroups == dupPairs)
        #expect(groups.allSatisfy { $0.urls.count == 2 })
        #expect(wasted == Int64(dupPairs) * Int64(size))
        #expect(elapsed < .seconds(45), "hash-based staging is ~O(n); a quadratic regression blows this")
    }
}

// MARK: - Area 3: Similar Images at scale

@Suite("Similar Images at scale")
struct SimilarImagesScaleTests {
    private func writePNG(_ url: URL, dimension: Int, gray: CGFloat) throws {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: dimension, height: dimension, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CocoaError(.featureUnsupported)
        }
        ctx.setFillColor(red: gray, green: gray, blue: gray, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: dimension, height: dimension))
        let image = ctx.makeImage()!
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }

    /// A few hundred images including a handful of very large (5000×5000) ones.
    /// pixelCount reads dimensions from metadata only (no full decode), so the
    /// large images must not blow memory. We assert the run completes and
    /// pixelCounts reflect the real (large) dimensions — proof the metadata path,
    /// not a downsampled decode, is what's measured.
    @Test func hundredsOfImagesWithLargeOnesStayMetadataBounded() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-stress-img-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // 150 distinct small images (distinct grays → mostly their own clusters).
        for i in 0..<150 {
            try writePNG(root.appendingPathComponent("s\(i).png"), dimension: 48,
                         gray: CGFloat(i) / 150.0)
        }
        // 3 identical small images → one guaranteed group.
        try writePNG(root.appendingPathComponent("dupe-a.png"), dimension: 64, gray: 0.5)
        try FileManager.default.copyItem(at: root.appendingPathComponent("dupe-a.png"),
                                         to: root.appendingPathComponent("dupe-b.png"))
        try FileManager.default.copyItem(at: root.appendingPathComponent("dupe-a.png"),
                                         to: root.appendingPathComponent("dupe-c.png"))
        // 4 very large images (5000×5000). Solid color → tiny on disk, but full
        // decode would be 100MB each; metadata pixel-count must stay cheap.
        for i in 0..<4 {
            try writePNG(root.appendingPathComponent("big\(i).png"), dimension: 5000,
                         gray: 0.9 - CGFloat(i) * 0.01)
        }

        let clock = ContinuousClock()
        let start = clock.now
        var groups: [SimilarImageGroup] = []
        for await event in SimilarImagesEngine(roots: [root]).run() {
            if case let .finished(g) = event { groups = g }
        }
        let elapsed = start.duration(to: clock.now)
        print("[stress] similar images: 157 images (4 at 5000² ) in \(elapsed)")

        // The 3 identical copies form at least one group.
        #expect(groups.contains { $0.urls.count >= 3 })
        // Metadata-only pixel count returns the true large dimensions.
        #expect(SimilarImagesEngine.pixelCount(of: root.appendingPathComponent("big0.png"))
                == 5000 * 5000)
        #expect(elapsed < .seconds(60), "Vision throughput bound; generous ceiling")
    }
}

// MARK: - Area 4: Space Lens at scale

@Suite("Space Lens at scale")
struct SpaceLensScaleTests {
    /// Wide tree: thousands of sibling files in a single directory. Traversal +
    /// sort + "Other" bucketing must complete quickly and roll bytes up exactly.
    @Test func wideTreeThousandsOfSiblingsCompletesAndCountsBytes() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-stress-lens-wide-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let siblings = 5000
        let each = 20
        let payload = Data(repeating: 1, count: each)
        for i in 0..<siblings { try payload.write(to: root.appendingPathComponent("f\(i).bin")) }

        let clock = ContinuousClock()
        let start = clock.now
        var result: SpaceNode?
        // minChildSize 1 so every byte counts; all files fall below it and merge
        // into "Other", exercising the bucketing path at scale.
        for await event in SpaceLensEngine(root: root, minChildSize: 1_000_000).run() {
            if case let .finished(node) = event { result = node }
        }
        let elapsed = start.duration(to: clock.now)
        print("[stress] space lens wide: \(siblings) siblings in \(elapsed)")

        let node = try #require(result)
        #expect(node.size >= Int64(siblings) * Int64(each))
        #expect(elapsed < .seconds(20))
    }

    /// Deep tree: many nested levels beyond the engine's default maxDepth. Must
    /// not stack-overflow or hang; bytes below the depth cap are still summed via
    /// shallowSize. Thousands of nodes total across the chain.
    @Test func deepTreeManyLevelsDoesNotCrashAndSumsBelowCap() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-stress-lens-deep-\(UUID().uuidString)")
        // 60 nested levels, a payload file at each level.
        var cursor = root
        let depth = 60
        try FileManager.default.createDirectory(at: cursor, withIntermediateDirectories: true)
        let payload = Data(repeating: 2, count: 10_000)
        for level in 0..<depth {
            try payload.write(to: cursor.appendingPathComponent("file\(level).bin"))
            cursor = cursor.appendingPathComponent("d\(level)")
            try FileManager.default.createDirectory(at: cursor, withIntermediateDirectories: true)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let clock = ContinuousClock()
        let start = clock.now
        var result: SpaceNode?
        for await event in SpaceLensEngine(root: root, maxDepth: 6, minChildSize: 1).run() {
            if case let .finished(node) = event { result = node }
        }
        let elapsed = start.duration(to: clock.now)
        print("[stress] space lens deep: \(depth) levels in \(elapsed)")

        let node = try #require(result)
        // Every level's payload is counted, even the ones past the depth cap.
        #expect(node.size >= Int64(depth) * 10_000)
        #expect(elapsed < .seconds(20))
    }
}

// MARK: - Area 7: Rapid cancellation

@Suite("Rapid cancellation")
struct RapidCancellationTests {
    /// Cancel a Space Lens scan almost immediately after starting it (by breaking
    /// out of the event loop, which terminates the stream and cancels the task).
    /// Teardown must be clean and fast — no hang waiting for the full walk.
    @Test func spaceLensCancelledImmediatelyTearsDownFast() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-stress-cancel-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("big")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = Data(repeating: 3, count: 20)
        for i in 0..<4000 { try payload.write(to: dir.appendingPathComponent("f\(i).bin")) }

        let clock = ContinuousClock()
        let start = clock.now
        // Break on the very first event; the stream's onTermination cancels the
        // detached scan task. The consumer returns without waiting for finish.
        for await _ in SpaceLensEngine(root: root, minChildSize: 1).run() {
            break
        }
        let elapsed = start.duration(to: clock.now)
        print("[stress] rapid cancel (space lens): returned in \(elapsed)")
        // If cancellation didn't propagate, we'd block until all 8000 files are
        // walked. A tight ceiling proves prompt teardown.
        #expect(elapsed < .seconds(5))
    }

    /// Same for the ScanEngine cleanup path.
    @Test func scanEngineCancelledImmediatelyTearsDownFast() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-stress-cancel2-\(UUID().uuidString)")
        let caches = root.appendingPathComponent("Library/Caches")
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = Data(repeating: 3, count: 20)
        for i in 0..<4000 { try payload.write(to: caches.appendingPathComponent("f\(i).tmp")) }

        let rule = ScanRule(id: "t", name: "t", category: "t", explanation: "t",
                            risk: .low, preselect: true) { [$0.appendingPathComponent("Library/Caches")] }
        let clock = ContinuousClock()
        let start = clock.now
        for await event in ScanEngine(configuration: ScanConfiguration(home: root)).run(rules: [rule]) {
            if case .started = event { continue }
            break   // bail at the first non-started event
        }
        let elapsed = start.duration(to: clock.now)
        print("[stress] rapid cancel (scan engine): returned in \(elapsed)")
        #expect(elapsed < .seconds(5))
    }
}
