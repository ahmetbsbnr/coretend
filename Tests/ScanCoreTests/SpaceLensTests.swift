// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import ScanCore

@Suite("SpaceLensEngine")
struct SpaceLensTests {
    @Test func sizesTreeAndBucketsSmallItems() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-lens-\(UUID().uuidString)")
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

    @Test func symbolicLinksAreNeverFollowedOrCounted() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-lens-\(UUID().uuidString)")
        let real = root.appendingPathComponent("real")
        let view = root.appendingPathComponent("view")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: view, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 0, count: 400_000).write(to: real.appendingPathComponent("blob.bin"))
        // A symlink inside `view` pointing at the big `real` tree.
        try FileManager.default.createSymbolicLink(
            at: view.appendingPathComponent("link"), withDestinationURL: real)

        var result: SpaceNode?
        for await event in SpaceLensEngine(root: view, minChildSize: 1).run() {
            if case let .finished(node) = event { result = node }
        }
        let node = try #require(result)
        // The symlink is skipped entirely: no child, and its target's bytes
        // are not double-counted into `view`.
        #expect(node.children.isEmpty)
        #expect(node.size == 0)
    }

    @Test func nestedDirectorySizesRollUpToParent() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-lens-\(UUID().uuidString)")
        let a = root.appendingPathComponent("a")
        let b = a.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 1, count: 300_000).write(to: a.appendingPathComponent("x.bin"))
        try Data(repeating: 1, count: 200_000).write(to: b.appendingPathComponent("y.bin"))

        var result: SpaceNode?
        for await event in SpaceLensEngine(root: root, minChildSize: 1).run() {
            if case let .finished(node) = event { result = node }
        }
        let node = try #require(result)
        // Parent total is at least the sum of both descendants.
        #expect(node.size >= 500_000)
        let aNode = try #require(node.children.first { $0.name == "a" })
        #expect(aNode.size >= 500_000)
    }

    @Test func depthCapUsesShallowSizeAndStillCountsBytes() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-lens-\(UUID().uuidString)")
        let deep = root.appendingPathComponent("dir/sub")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 2, count: 250_000).write(to: deep.appendingPathComponent("z.bin"))

        var result: SpaceNode?
        // maxDepth 1 forces the top-level "dir" to be measured via shallowSize
        // instead of recursed — bytes below the cap must still be counted.
        for await event in SpaceLensEngine(root: root, maxDepth: 1, minChildSize: 1).run() {
            if case let .finished(node) = event { result = node }
        }
        let node = try #require(result)
        #expect(node.size >= 250_000)
        let dir = try #require(node.children.first { $0.name == "dir" })
        #expect(dir.size >= 250_000)
        // Depth cap: the deep child is not materialized as a node.
        #expect(dir.children.isEmpty)
    }

    @Test func emptyAndZeroSizeContentsDoNotCrashAndBucketToOther() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-lens-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("empty"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("zero.txt"))

        var result: SpaceNode?
        for await event in SpaceLensEngine(root: root, minChildSize: 100).run() {
            if case let .finished(node) = event { result = node }
        }
        let node = try #require(result)
        // Nothing meets the threshold; no "Other" bucket is fabricated from zero bytes.
        #expect(node.size == 0)
        #expect(!node.children.contains { $0.name == "Other (small items)" })
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
