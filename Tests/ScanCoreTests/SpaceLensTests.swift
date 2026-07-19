import Testing
import Foundation
@testable import ScanCore

@Suite("SpaceLensEngine")
struct SpaceLensTests {
    @Test func sizesTreeAndBucketsSmallItems() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-lens-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("big"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 0, count: 500_000).write(to: root.appendingPathComponent("big/blob.bin"))
        try Data("tiny".utf8).write(to: root.appendingPathComponent("small.txt"))

        var result: SpaceNode?
        for await event in SpaceLensEngine(root: root, minChildSize: 100_000).run() {
            if case let .finished(node) = event { result = node }
        }
        let node = try #require(result)
        #expect(node.size >= 500_000)
        #expect(node.children.contains { $0.name == "big" })
        // small.txt merged into "Other".
        #expect(!node.children.contains { $0.name == "small.txt" })
    }

    @Test func treemapLayoutCoversBoundsProportionally() {
        let nodes = [
            SpaceNode(name: "a", path: "/a", isDirectory: true, size: 750),
            SpaceNode(name: "b", path: "/b", isDirectory: false, size: 250),
        ]
        let rects = TreemapLayout.layout(nodes: nodes, in: CGRect(x: 0, y: 0, width: 400, height: 100))
        #expect(rects.count == 2)
        #expect(abs(rects[0].frame.width - 300) < 0.5)
        #expect(abs(rects[1].frame.width - 100) < 0.5)
    }
}
