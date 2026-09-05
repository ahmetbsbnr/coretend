// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
@testable import CoreTendApp

private func dir(_ name: String, _ bytes: Int64, children: [SpaceNode] = []) -> SpaceNode {
    SpaceNode(name: name, path: "/root/\(name)", isDirectory: true, size: bytes, children: children)
}
private func file(_ name: String, _ bytes: Int64) -> SpaceNode {
    SpaceNode(name: name, path: "/root/\(name)", isDirectory: false, size: bytes)
}

@Suite("SpaceLensAggregator — bounded, deterministic presentation model")
struct SpaceLensAggregatorTests {

    @Test func ordersByBytesDescendingThenPathForTies() {
        let root = dir("root", 60, children: [
            file("b", 10), file("a", 10), file("big", 40),
        ])
        let scope = SpaceLensAggregator.scope(for: root, parentID: nil, depth: 0)
        #expect(scope.listNodes.map(\.displayName) == ["big", "a", "b"])
    }

    @Test func percentagesAreOfScopeTotal() {
        let root = dir("root", 100, children: [file("x", 25), file("y", 75)])
        let scope = SpaceLensAggregator.scope(for: root, parentID: nil, depth: 0)
        #expect(abs(scope.listNodes[0].percentageOfScope - 0.75) < 0.0001)
        #expect(abs(scope.listNodes[1].percentageOfScope - 0.25) < 0.0001)
    }

    @Test func boundsToTheVisualLimitAndFoldsTheRestIntoExactlyOneOther() {
        let kids = (0..<200).map { file(String(format: "f%03d", $0), Int64(1000 - $0)) }
        let root = dir("root", kids.reduce(0) { $0 + $1.size }, children: kids)
        let scope = SpaceLensAggregator.scope(
            for: root, parentID: nil, depth: 0, visualLimit: 40, listLimit: 120)

        #expect(scope.visualNodes.filter { !$0.isOther }.count == 40)
        #expect(scope.visualNodes.filter { $0.isOther }.count == 1)
        #expect(scope.listNodes.filter { !$0.isOther }.count == 120)
        #expect(scope.listNodes.filter { $0.isOther }.count == 1)

        let other = scope.listNodes.last!
        #expect(other.isOther)
        #expect(other.isDrillable == false)
        #expect(other.childCount == 80)            // 200 - 120 folded
        #expect(scope.foldedIntoOther == 80)
        // Other's bytes == the sum of the folded tail.
        let folded = kids.sorted { $0.size > $1.size }.dropFirst(120).reduce(Int64(0)) { $0 + $1.size }
        #expect(other.logicalBytes == folded)
    }

    @Test func mergesTheEnginesOwnOtherBucketIntoOurs() {
        let root = dir("root", 130, children: [
            file("keep", 100),
            SpaceNode(name: "Other (small items)", path: "/root/\u{2026}other", isDirectory: false, size: 30),
        ])
        let scope = SpaceLensAggregator.scope(for: root, parentID: nil, depth: 0)
        #expect(scope.listNodes.filter { $0.isOther }.count == 1)
        #expect(scope.listNodes.last!.logicalBytes == 30)
        #expect(scope.realChildCount == 1)        // the engine bucket is not a "real" child
    }

    @Test func noOtherNodeWhenNothingOverflows() {
        let root = dir("root", 30, children: [file("a", 20), file("b", 10)])
        let scope = SpaceLensAggregator.scope(for: root, parentID: nil, depth: 0)
        #expect(scope.listNodes.allSatisfy { !$0.isOther })
    }

    @Test func stableIdentityAcrossRuns() {
        let kids = (0..<50).map { file("f\($0)", Int64(100 - $0)) }
        let root = dir("root", 5000, children: kids)
        let a = SpaceLensAggregator.scope(for: root, parentID: nil, depth: 0, visualLimit: 10, listLimit: 20)
        let b = SpaceLensAggregator.scope(for: root, parentID: nil, depth: 0, visualLimit: 10, listLimit: 20)
        #expect(a.listNodes.map(\.id) == b.listNodes.map(\.id))
        #expect(a.visualNodes.map(\.id) == b.visualNodes.map(\.id))
        // The "Other" id is deterministic too.
        #expect(a.listNodes.last!.id == b.listNodes.last!.id)
    }

    @Test func filterKeepsOnlyMatchingRealChildren() {
        let root = dir("root", 60, children: [
            file("report.pdf", 30), file("photo.jpg", 20), file("notes.txt", 10),
        ])
        // Case-insensitive substring: "PO" matches "rePOrt.pdf" only.
        let report = SpaceLensAggregator.scope(for: root, parentID: nil, depth: 0, filter: "PO")
        #expect(report.listNodes.map(\.displayName) == ["report.pdf"])
        // "OT" matches "phOTo.jpg" and "nOTes.txt".
        let ot = SpaceLensAggregator.scope(for: root, parentID: nil, depth: 0, filter: "OT")
        #expect(Set(ot.listNodes.map(\.displayName)) == ["photo.jpg", "notes.txt"])
    }

    @Test func drillabilityIsDirectoryWithChildrenAndNotOther() {
        let withKids = dir("a", 10, children: [file("x", 5)])
        let empty = dir("b", 0)
        let leaf = file("c", 5)
        let root = dir("root", 20, children: [withKids, empty, leaf])
        let scope = SpaceLensAggregator.scope(for: root, parentID: nil, depth: 0)
        let byName = Dictionary(uniqueKeysWithValues: scope.listNodes.map { ($0.displayName, $0) })
        #expect(byName["a"]?.isDrillable == true)
        #expect(byName["b"]?.isDrillable == false)
        #expect(byName["c"]?.isDrillable == false)
    }

    // MARK: - 500k stress

    @Test func fiveHundredThousandChildrenStayBoundedAndFast() {
        let n = 500_000
        var kids: [SpaceNode] = []
        kids.reserveCapacity(n)
        var total: Int64 = 0
        for i in 0..<n {
            let size = Int64((i % 997) + 1)          // varied, deterministic
            total += size
            kids.append(SpaceNode(name: "f\(i)", path: "/root/f\(i)", isDirectory: false, size: size))
        }
        let root = SpaceNode(name: "root", path: "/root", isDirectory: true, size: total, children: kids)

        let clock = ContinuousClock()
        let start = clock.now
        let scope = SpaceLensAggregator.scope(
            for: root, parentID: nil, depth: 0, visualLimit: 40, listLimit: 120)
        let elapsed = start.duration(to: clock.now)

        // Bounded render model — NOT one node per filesystem entry.
        #expect(scope.visualNodes.count <= 41)
        #expect(scope.listNodes.count <= 121)
        #expect(scope.visualNodes.filter { $0.isOther }.count == 1)
        #expect(scope.foldedIntoOther == n - 120)
        #expect(scope.realChildCount == n)

        // Aggregation is exact: kept bytes + Other bytes == scope total.
        let keptListBytes = scope.listNodes.reduce(Int64(0)) { $0 + $1.logicalBytes }
        #expect(keptListBytes == total)

        // Single pass over the children, no quadratic blowup.
        #expect(elapsed < .seconds(5), "aggregation of \(n) entries took \(elapsed)")
    }
}
