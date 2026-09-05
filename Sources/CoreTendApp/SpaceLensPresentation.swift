// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore

/// One node as the Space Lens UI sees it — a flat, bounded, value-typed
/// projection of a `SpaceNode`, never the raw filesystem hierarchy. SwiftUI
/// only ever renders these; there are at most a few dozen per scope no
/// matter how many files were scanned.
struct SpaceLensNode: Identifiable, Equatable, Sendable {
    /// Stable across rescans of the same scope (it is the node's path, or a
    /// deterministic synthetic id for the "Other" bucket).
    let id: String
    let displayName: String
    let isDirectory: Bool
    let logicalBytes: Int64
    /// 0…1 of the current scope's total bytes.
    let percentageOfScope: Double
    /// Direct children count (0 for files; the folded count for "Other").
    let childCount: Int
    let parentID: String?
    let depth: Int
    let category: SpaceNodeCategory
    /// The real filesystem path to act on / navigate into. Empty for "Other".
    let sourcePath: String
    /// True for the synthetic aggregate bucket — never a real directory,
    /// never drillable, never deletable.
    let isOther: Bool
    let isAccessDenied: Bool
    let isCloudPlaceholder: Bool

    var isDrillable: Bool { isDirectory && !isOther && childCount > 0 }
}

/// The bounded set of nodes for one directory scope: the largest few, plus a
/// single "Other" bucket for everything that did not make the cut. Two
/// bounds — a tighter one for the bubble canvas, a looser one for the
/// precise list — both derived from the same deterministic ordering.
struct SpaceLensScope: Equatable, Sendable {
    let directoryID: String
    let directoryName: String
    let totalBytes: Int64
    /// Full listable set (≤ `listLimit` real nodes + optional Other).
    let listNodes: [SpaceLensNode]
    /// Canvas set (≤ `visualLimit` real nodes + optional Other).
    let visualNodes: [SpaceLensNode]
    /// How many real children were folded into "Other" for the list bound.
    let foldedIntoOther: Int
    /// How many real children exist in total (before any bounding).
    let realChildCount: Int

    static let empty = SpaceLensScope(
        directoryID: "", directoryName: "", totalBytes: 0,
        listNodes: [], visualNodes: [], foldedIntoOther: 0, realChildCount: 0)
}

/// Turns a raw `SpaceNode` directory into a bounded `SpaceLensScope`.
///
/// The bound is deliberate and tested, not arbitrary: a scope renders at
/// most `visualLimit` (default 40) bubbles and `listLimit` (default 120)
/// rows. Everything past that — plus the engine's own "Other (small items)"
/// child — folds into exactly one synthetic "Other" node carrying the
/// aggregate bytes and the folded child count. This is what keeps Space
/// Lens usable when a directory has hundreds of thousands of entries: the
/// engine already merges sub-`minChildSize` items, and this merges the long
/// tail of whatever survives that.
enum SpaceLensAggregator {
    static let defaultVisualLimit = 40
    static let defaultListLimit = 120

    /// `filter` (a lowercased search term) keeps only matching real children;
    /// an empty string keeps all. "Other" is only shown when the (possibly
    /// filtered) set actually overflows the bound.
    static func scope(for directory: SpaceNode,
                      parentID: String?,
                      depth: Int,
                      filter: String = "",
                      visualLimit: Int = defaultVisualLimit,
                      listLimit: Int = defaultListLimit) -> SpaceLensScope {
        let term = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Split the engine's own synthetic bucket out — it always folds into
        // ours so a scope never shows two "Other"s.
        var engineOtherBytes: Int64 = 0
        var realChildren: [SpaceNode] = []
        for child in directory.children {
            if child.path.hasSuffix("\u{2026}other") { engineOtherBytes += child.size }
            else { realChildren.append(child) }
        }

        let matched = term.isEmpty
            ? realChildren
            : realChildren.filter { $0.name.lowercased().contains(term) }

        // Deterministic order: bytes desc, then path asc for ties.
        let ordered = matched.sorted {
            $0.size != $1.size ? $0.size > $1.size : $0.path < $1.path
        }

        let total = max(directory.size, 1)
        func project(_ node: SpaceNode) -> SpaceLensNode {
            SpaceLensNode(
                id: node.path,
                displayName: node.name,
                isDirectory: node.isDirectory,
                logicalBytes: node.size,
                percentageOfScope: Double(node.size) / Double(total),
                childCount: node.children.filter { !$0.path.hasSuffix("\u{2026}other") }.count,
                parentID: directory.path,
                depth: depth + 1,
                category: SpaceNodeCategory.of(node),
                sourcePath: node.path,
                isOther: false,
                isAccessDenied: node.isAccessDenied,
                isCloudPlaceholder: node.isCloudPlaceholder)
        }

        func bound(_ limit: Int) -> (kept: [SpaceLensNode], foldedCount: Int, foldedBytes: Int64) {
            guard ordered.count > limit else {
                return (ordered.map(project), 0, 0)
            }
            let kept = ordered.prefix(limit).map(project)
            let tail = ordered.dropFirst(limit)
            let bytes = tail.reduce(Int64(0)) { $0 + $1.size }
            return (kept, tail.count, bytes)
        }

        func otherNode(foldedCount: Int, foldedBytes: Int64) -> SpaceLensNode? {
            let bytes = foldedBytes + (term.isEmpty ? engineOtherBytes : 0)
            let count = foldedCount + (term.isEmpty && engineOtherBytes > 0 ? 1 : 0)
            guard bytes > 0 else { return nil }
            return SpaceLensNode(
                id: directory.path + "/\u{2026}other",
                displayName: L("spacelens.other_bucket"),
                isDirectory: false,
                logicalBytes: bytes,
                percentageOfScope: Double(bytes) / Double(total),
                childCount: count,
                parentID: directory.path,
                depth: depth + 1,
                category: .other,
                sourcePath: "",
                isOther: true,
                isAccessDenied: false,
                isCloudPlaceholder: false)
        }

        let listBound = bound(listLimit)
        var listNodes = listBound.kept
        if let other = otherNode(foldedCount: listBound.foldedCount, foldedBytes: listBound.foldedBytes) {
            listNodes.append(other)
        }

        let visualBound = bound(visualLimit)
        var visualNodes = visualBound.kept
        if let other = otherNode(foldedCount: visualBound.foldedCount, foldedBytes: visualBound.foldedBytes) {
            visualNodes.append(other)
        }

        return SpaceLensScope(
            directoryID: directory.path,
            directoryName: directory.name,
            totalBytes: directory.size,
            listNodes: listNodes,
            visualNodes: visualNodes,
            foldedIntoOther: listBound.foldedCount,
            realChildCount: realChildren.count)
    }
}
