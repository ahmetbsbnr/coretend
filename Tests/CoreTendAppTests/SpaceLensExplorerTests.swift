// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
@testable import CoreTendApp

@MainActor
@Suite("SpaceLensViewModel — bounded scope, selection, drill, throttle")
struct SpaceLensExplorerTests {

    private func tree() -> SpaceNode {
        let leaf = SpaceNode(name: "leaf.bin", path: "/root/big/leaf.bin", isDirectory: false, size: 100)
        let big = SpaceNode(name: "big", path: "/root/big", isDirectory: true, size: 100, children: [leaf])
        let small = SpaceNode(name: "small.txt", path: "/root/small.txt", isDirectory: false, size: 5)
        return SpaceNode(name: "root", path: "/root", isDirectory: true, size: 105, children: [big, small])
    }

    @Test func scopeReflectsCurrentDirectoryAndIsBounded() {
        let m = SpaceLensViewModel()
        m.root = tree()
        let scope = m.scope(filter: "")
        #expect(scope.directoryID == "/root")
        #expect(scope.listNodes.map(\.displayName) == ["big", "small.txt"])
        #expect(scope.listNodes[0].isDrillable)          // big has a child
        #expect(scope.listNodes[1].isDrillable == false) // file
    }

    @Test func drillByIDDescendsIntoADirectoryAndClearsSelection() {
        let m = SpaceLensViewModel()
        m.root = tree()
        m.selectionID = "/root/big"
        m.drill(nodeID: "/root/big")
        #expect(m.current?.name == "big")
        #expect(m.selectionID == nil)
    }

    @Test func drillByIDRefusesFilesAndUnknownIDs() {
        let m = SpaceLensViewModel()
        m.root = tree()
        m.drill(nodeID: "/root/small.txt")       // a file
        #expect(m.current?.name == "root")
        m.drill(nodeID: "/root/nope")            // unknown
        #expect(m.current?.name == "root")
    }

    @Test func drillByIDRefusesTheSyntheticOtherBucket() {
        let m = SpaceLensViewModel()
        m.root = tree()
        m.drill(nodeID: "/root/\u{2026}other")
        #expect(m.current?.name == "root")
    }

    @Test func selectionIsASharedValueTheCanvasAndListBothUse() {
        // The model holds exactly one selection id; there is no separate
        // per-view selection to drift out of sync.
        let m = SpaceLensViewModel()
        m.root = tree()
        m.selectionID = "/root/big"
        #expect(m.scope(filter: "").listNodes.contains { $0.id == m.selectionID })
    }

    @Test func partialUpdatesAreThrottledByTheInjectedClock() {
        final class Clock: @unchecked Sendable { var now = Date(timeIntervalSince1970: 1_000) }
        let clock = Clock()
        let m = SpaceLensViewModel(partialThrottle: 1.0, clock: { clock.now })
        // Simulate the start of a scan (no navigation depth).
        m.pathStack = []

        func partial(_ bytes: Int64) -> SpaceNode {
            SpaceNode(name: "root", path: "/root", isDirectory: true, size: bytes,
                      children: [SpaceNode(name: "a", path: "/root/a", isDirectory: true, size: bytes)])
        }

        m.applyPartial(partial(10))   // first one publishes
        m.applyPartial(partial(20))   // within 1s window — dropped
        m.applyPartial(partial(30))   // dropped
        #expect(m.publishedPartialCount == 1)
        #expect(m.root?.size == 10)

        clock.now = clock.now.addingTimeInterval(1.5)
        m.applyPartial(partial(40))   // window elapsed — publishes
        #expect(m.publishedPartialCount == 2)
        #expect(m.root?.size == 40)
    }

    @Test func partialUpdatesStopOnceTheUserHasNavigated() {
        let m = SpaceLensViewModel(partialThrottle: 0)
        m.root = SpaceNode(name: "root", path: "/root", isDirectory: true, size: 1,
                           children: [SpaceNode(name: "a", path: "/root/a", isDirectory: true, size: 1,
                                                children: [SpaceNode(name: "x", path: "/root/a/x", isDirectory: false, size: 1)])])
        m.descend(into: m.root!.children[0])
        #expect(m.current?.name == "a")
        m.applyPartial(SpaceNode(name: "root", path: "/root", isDirectory: true, size: 999))
        // Navigation is not disturbed by a late partial.
        #expect(m.current?.name == "a")
    }

    @Test func friendlyLocationNeverExposesAFullPath() {
        let out = SpaceLensViewModel.friendlyLocation("/Users/someone/Library/Caches/com.example.app")
        #expect(!out.hasPrefix("/Users/someone"))
        #expect(out == "Library/Caches/com.example.app")
    }
}
