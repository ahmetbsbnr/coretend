// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Observation

/// The bridge from a finished Smart Scan into the existing Recovery Plan
/// screen. Smart Scan never deletes; its post-scan action is "Review Recovery
/// Plan", and that must land in a Recovery Plan populated with the *same*
/// prepared candidates the scan already produced — never a second scan, never
/// a re-derived eligibility.
///
/// `SmartScanModel` publishes here when a run completes (not when cancelled).
/// `RecoveryPlanViewModel.preparePlan()` reads `candidates` first and only
/// falls back to a fresh `RecoveryPlanService.prepareCandidates()` when there
/// is no fresh handoff (the user opened Recovery Plan directly).
@MainActor
@Observable
final class SmartScanHandoff {
    static let shared = SmartScanHandoff()
    private init() {}

    /// The memoised candidate set from the last completed Smart Scan.
    @ObservationIgnored private(set) var cache: SmartScanRecoveryCandidates?
    private(set) var report: SmartScanReport?
    private(set) var preparedAt: Date?

    /// How long a handoff stays "fresh". After this, Recovery Plan re-scans
    /// rather than acting on a stale picture of the disk.
    static let freshness: TimeInterval = 10 * 60

    var isFresh: Bool {
        guard let preparedAt else { return false }
        return Date().timeIntervalSince(preparedAt) < Self.freshness
    }

    func record(cache: SmartScanRecoveryCandidates, report: SmartScanReport, at date: Date = Date()) {
        self.cache = cache
        self.report = report
        self.preparedAt = date
    }

    /// Returns the prepared candidates iff the handoff is still fresh.
    func freshCandidates() async -> [RecoveryPlanCandidateData]? {
        guard isFresh, let cache else { return nil }
        return await cache.candidates()
    }

    func clear() {
        cache = nil
        report = nil
        preparedAt = nil
    }
}
