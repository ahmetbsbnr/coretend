// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore
import Persistence

/// The single definition of "turn a completed Cleanup scan into Timeline
/// category samples". Extracted from `CleanupView` so a scheduled scan
/// records an *identical, comparable* `cleanup`-scope snapshot rather than a
/// hand-copied variant that could drift from the interactive one.
enum CleanupTimeline {
    static func samples(from findings: [ScanFinding]) -> [TimelineCategorySample] {
        var byRule: [String: [ScanFinding]] = [:]
        for finding in findings { byRule[finding.ruleID, default: []].append(finding) }
        return byRule.map { ruleID, group in
            TimelineCategorySample(
                category: ruleID,
                engine: "cleanup",
                logicalBytes: group.reduce(0) { $0 + $1.logicalSize },
                // Same pairing rule CleanupView applies: a physical total
                // only when every finding in the group carries an allocated
                // size from this same pass — never a partial sum.
                physicalBytes: group.totalAllocatedSizeIfFullyKnown,
                fileCount: group.count,
                risk: group.first?.risk.rawValue ?? "unknown")
        }
    }
}
