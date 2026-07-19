import Testing
import Foundation
@testable import ScanCore

@Suite("DuplicateEngine")
struct DuplicateEngineTests {
    let root: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-dup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("sub"), withIntermediateDirectories: true)
    }

    private func cleanup() { try? FileManager.default.removeItem(at: root) }

    private func write(_ name: String, _ content: Data) throws -> URL {
        let url = root.appendingPathComponent(name)
        try content.write(to: url)
        return url
    }

    @Test func detectsIdenticalFilesAndSkipsUniques() async throws {
        defer { cleanup() }
        let payload = Data(repeating: 7, count: 2_000_000)
        _ = try write("a.bin", payload)
        _ = try write("sub/b.bin", payload)
        _ = try write("unique.bin", Data(repeating: 9, count: 2_000_000))
        // Same size, different content: must not group.
        _ = try write("samesize.bin", Data(repeating: 8, count: 2_000_000))

        var groups: [DuplicateGroup] = []
        var wasted: Int64 = -1
        for await event in DuplicateEngine(roots: [root]).run() {
            if case let .group(g) = event { groups.append(g) }
            if case let .finished(_, bytes) = event { wasted = bytes }
        }
        #expect(groups.count == 1)
        #expect(groups.first?.urls.count == 2)
        #expect(groups.first?.wastedBytes == 2_000_000)
        #expect(wasted == 2_000_000)
    }

    @Test func hardLinksNotTreatedAsDuplicates() async throws {
        defer { cleanup() }
        let original = try write("orig.bin", Data(repeating: 3, count: 2_000_000))
        let link = root.appendingPathComponent("hardlink.bin")
        try FileManager.default.linkItem(at: original, to: link)

        var groups = 0
        for await event in DuplicateEngine(roots: [root]).run() {
            if case .group = event { groups += 1 }
        }
        #expect(groups == 0, "two hard links to one inode are not duplicates")
    }

    @Test func filesBelowMinimumSizeIgnored() async throws {
        defer { cleanup() }
        let small = Data(repeating: 1, count: 10)
        _ = try write("s1.txt", small)
        _ = try write("s2.txt", small)
        var groups = 0
        for await event in DuplicateEngine(roots: [root], minimumSize: 1_000_000).run() {
            if case .group = event { groups += 1 }
        }
        #expect(groups == 0)
    }

    @Test func keeperPrefersShallowestPath() async throws {
        defer { cleanup() }
        let payload = Data(repeating: 5, count: 1_500_000)
        let top = try write("keep.bin", payload)
        _ = try write("sub/copy.bin", payload)
        var keeper: URL?
        for await event in DuplicateEngine(roots: [root]).run() {
            if case let .group(g) = event { keeper = g.keeper }
        }
        #expect(keeper?.resolvingSymlinksInPath().path == top.resolvingSymlinksInPath().path)
    }
}

@Suite("ScanConfiguration exclusions")
struct ScanExclusionTests {
    @Test func excludedSubtreeSkipped() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-excl-\(UUID().uuidString)")
        let cachesDir = root.appendingPathComponent("Library/Caches")
        try FileManager.default.createDirectory(
            at: cachesDir.appendingPathComponent("Excluded"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("x".utf8).write(to: cachesDir.appendingPathComponent("kept.dat"))
        try Data("x".utf8).write(to: cachesDir.appendingPathComponent("Excluded/hidden.dat"))

        let rule = ScanRule(id: "t", name: "t", category: "t", explanation: "t",
                            risk: .low, preselect: true) { home in
            [home.appendingPathComponent("Library/Caches")]
        }
        let config = ScanConfiguration(
            home: root, excludedPaths: [cachesDir.appendingPathComponent("Excluded").path])
        var names: [String] = []
        for await event in ScanEngine(configuration: config).run(rules: [rule]) {
            if case let .finding(f) = event { names.append(f.url.lastPathComponent) }
        }
        #expect(names == ["kept.dat"])
    }
}
