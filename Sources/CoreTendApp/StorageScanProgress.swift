// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore

/// Structured, real progress for a live Storage scan.
///
/// Every field is fed from actual `ScanEvent`s. There is deliberately **no**
/// `fractionComplete` / percentage: `ScanEngine` walks an unbounded set and
/// never reports a total, so any percentage would be fabricated. The UI
/// shows the real counters and an indeterminate indicator instead.
///
/// This type is a plain value + a pure reducer so it can live in the domain
/// and be exhaustively unit-tested without a SwiftUI view.
public struct StorageScanProgress: Equatable, Sendable {
    public enum Phase: String, Equatable, Sendable {
        case idle, scanning, paused, finalizing, done, cancelled, failed
    }

    public var phase: Phase
    /// Filesystem entries the engine has walked (`ScanEvent.progress.scanned`).
    public var itemsInspected: Int
    /// Findings flagged so far.
    public var findingsDetected: Int
    /// Running total of flagged bytes that are auto-plannable (low/medium risk).
    public var reclaimableBytesSoFar: Int64
    /// Running total of flagged bytes that will need individual review (high risk).
    public var reviewRequiredBytesSoFar: Int64
    /// The path the engine is currently under (`ScanEvent.progress.currentPath`).
    public var currentPath: String
    public var startedAt: Date?
    /// Wall-clock elapsed, supplied by the caller's clock (kept out of the
    /// reducer so it stays pure).
    public var elapsed: TimeInterval
    /// True only when a real `ScanPauseController` is attached to the run.
    public var isPausable: Bool
    public var failureMessage: String?

    public init(
        phase: Phase = .idle,
        itemsInspected: Int = 0,
        findingsDetected: Int = 0,
        reclaimableBytesSoFar: Int64 = 0,
        reviewRequiredBytesSoFar: Int64 = 0,
        currentPath: String = "",
        startedAt: Date? = nil,
        elapsed: TimeInterval = 0,
        isPausable: Bool = false,
        failureMessage: String? = nil
    ) {
        self.phase = phase
        self.itemsInspected = itemsInspected
        self.findingsDetected = findingsDetected
        self.reclaimableBytesSoFar = reclaimableBytesSoFar
        self.reviewRequiredBytesSoFar = reviewRequiredBytesSoFar
        self.currentPath = currentPath
        self.startedAt = startedAt
        self.elapsed = elapsed
        self.isPausable = isPausable
        self.failureMessage = failureMessage
    }

    public var isCancellable: Bool { phase == .scanning || phase == .paused }
    public var detectedBytesSoFar: Int64 { reclaimableBytesSoFar + reviewRequiredBytesSoFar }

    /// Fold one engine event into the progress value. Pure; `elapsed` and
    /// `phase` transitions driven by pause/cancel are applied separately by
    /// the caller (they are not engine events).
    public func applying(_ event: ScanEvent) -> StorageScanProgress {
        var next = self
        switch event {
        case .started:
            next.phase = .scanning
        case let .progress(scanned, currentPath):
            next.itemsInspected = scanned
            next.currentPath = currentPath
        case let .finding(finding):
            next.findingsDetected += 1
            if StorageScanSummary.isReviewRequired(finding) {
                next.reviewRequiredBytesSoFar += finding.logicalSize
            } else {
                next.reclaimableBytesSoFar += finding.logicalSize
            }
        case .error:
            break  // a per-path error does not change progress or fail the scan
        case let .finished(scanned, _):
            next.itemsInspected = max(next.itemsInspected, scanned)
            next.phase = .done
            next.currentPath = ""
        default:
            // ScanEvent may carry a `.cancelled` case in this build; a
            // cancelled scan is a Partial state, never `.done`.
            next.phase = .cancelled
            next.currentPath = ""
        }
        return next
    }

    /// Explicit non-engine transitions.
    public mutating func markPaused() { if phase == .scanning { phase = .paused } }
    public mutating func markResumed() { if phase == .paused { phase = .scanning } }
    public mutating func markCancelled() { phase = .cancelled; currentPath = "" }
    public mutating func markFailed(_ message: String) { phase = .failed; failureMessage = message }
}
