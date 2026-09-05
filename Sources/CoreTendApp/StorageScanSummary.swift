// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore
import SafetyCore

/// The distinct quantities a Storage scan produces.
///
/// They are deliberately *different kinds of number*. The UI and every test
/// must keep them apart:
///
///   itemsInspected      — filesystem entries the engine walked (a progress
///                          metric; not bytes, not deletable).
///   detectedBytes       — total logical size of everything the engine
///                          flagged. A ceiling, not an intention.
///   reclaimableBytes    — the subset of `detected` that is safe to plan
///                          automatically (not high-risk).
///   reviewRequiredBytes — the subset of `detected` a person must decide on
///                          item by item (high-risk findings).
///   selectedBytes       — what the user has actually ticked. THE ONLY number
///                          a "Move to Trash" action is allowed to spend.
///   recoveredBytes      — filled in *after* execution from real outcomes;
///                          `nil` until then. Never equal to `selected` by
///                          assumption — a move can fail or free less.
///
/// Invariants (asserted by `StorageScanSummaryTests`):
///   detectedBytes == reclaimableBytes + reviewRequiredBytes
///   selectedBytes <= detectedBytes
///   recoveredBytes ?? 0 <= selectedBytes
public struct StorageScanSummary: Equatable, Sendable {
    public var itemsInspected: Int
    public var detectedCount: Int
    public var detectedBytes: Int64
    public var reclaimableBytes: Int64
    public var reviewRequiredBytes: Int64
    public var selectedBytes: Int64
    public var recoveredBytes: Int64?

    public init(
        itemsInspected: Int = 0,
        detectedCount: Int = 0,
        detectedBytes: Int64 = 0,
        reclaimableBytes: Int64 = 0,
        reviewRequiredBytes: Int64 = 0,
        selectedBytes: Int64 = 0,
        recoveredBytes: Int64? = nil
    ) {
        self.itemsInspected = itemsInspected
        self.detectedCount = detectedCount
        self.detectedBytes = detectedBytes
        self.reclaimableBytes = reclaimableBytes
        self.reviewRequiredBytes = reviewRequiredBytes
        self.selectedBytes = selectedBytes
        self.recoveredBytes = recoveredBytes
    }

    /// True when there is nothing ticked — a destructive CTA MUST be disabled.
    public var hasSelection: Bool { selectedBytes > 0 }

    /// A finding needs individual review when its risk is `.high`; everything
    /// else is auto-planning eligible. This is the per-screen distinction —
    /// the *global* (cross-module) reclaimable figure additionally goes
    /// through `RecoveryPlanEligibility`'s overlap-aware logic.
    public static func isReviewRequired(_ finding: ScanFinding) -> Bool {
        finding.risk == .high
    }

    /// Build a summary from a full findings set plus the current selection.
    /// `itemsInspected` comes from the engine's progress events, not from
    /// `findings.count` (findings are capped for display).
    public static func from(
        findings: [ScanFinding],
        itemsInspected: Int,
        totalDetectedCount: Int,
        totalDetectedBytes: Int64,
        selectedIDs: Set<UUID>,
        recoveredBytes: Int64? = nil
    ) -> StorageScanSummary {
        var reviewBytes: Int64 = 0
        var reclaimBytes: Int64 = 0
        var selected: Int64 = 0
        for f in findings {
            if isReviewRequired(f) { reviewBytes += f.logicalSize } else { reclaimBytes += f.logicalSize }
            if selectedIDs.contains(f.id) { selected += f.logicalSize }
        }
        // If the display was truncated, attribute the un-shown remainder to
        // "reclaimable" rather than inflating "review required" — it is a
        // ceiling estimate and the user cannot have selected an un-shown item.
        let shownBytes = reviewBytes + reclaimBytes
        if totalDetectedBytes > shownBytes {
            reclaimBytes += totalDetectedBytes - shownBytes
        }
        return StorageScanSummary(
            itemsInspected: itemsInspected,
            detectedCount: totalDetectedCount,
            detectedBytes: totalDetectedBytes,
            reclaimableBytes: reclaimBytes,
            reviewRequiredBytes: reviewBytes,
            selectedBytes: selected,
            recoveredBytes: recoveredBytes
        )
    }
}
