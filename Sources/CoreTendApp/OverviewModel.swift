// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence

/// What the Overview is allowed to say.
///
/// Everything here is either measured by macOS (volume capacity) or recorded
/// by CoreTend at the time it did the work. Nothing is projected, estimated or
/// summed across unlike things.
///
/// The design reference for this screen showed tiles reading "Storage
/// Reclaimable 3.55 GB" and a stacked bar split into Applications / Documents
/// / Media / System / Photos. Neither exists: reclaimable is the quantity this
/// app has decided it cannot compute, and a per-category breakdown of a whole
/// volume is not something macOS exposes — it would take a full scan of every
/// directory, including ones no app can read. The composition is kept; the
/// figures are the ones CoreTend owns.
enum OverviewFacts {

    /// A volume as a Visual Beta scenario states it.
    ///
    /// The seam exists because "this Mac is 98% full" and "there are three
    /// volumes mounted" are layouts the app must survive, and neither is a
    /// state a developer's machine can be put into on demand. Nil in every
    /// normal launch, so production reads the real hardware and nothing about
    /// this type is reachable outside test mode.
    struct FixtureVolume {
        let name: String
        let isInternal: Bool
        let total: Int64
        let free: Int64
    }

    /// The volumes a fixture is imposing, or nil to read real hardware.
    nonisolated(unsafe) static var fixtureVolumes: [FixtureVolume]?

    /// Whether a fixture is reporting Full Disk Access as missing.
    nonisolated(unsafe) static var fixtureDeniesFullDiskAccess = false

    /// A scan CoreTend has actually run, with what it found at the time.
    ///
    /// `bytes` is what that scan *found*, not what was removed, and the UI
    /// labels it that way. A scan that has never run has no figure at all
    /// rather than a zero, because zero is a finding and "never asked" is not.
    struct ScanResult: Equatable {
        let module: ModuleID
        let date: Date
        let bytes: Int64
        let itemCount: Int
    }

    /// The prefix each module writes in its scan summary. Matching on it is
    /// how a scan row finds its module, so the two live together here rather
    /// than as a string repeated at both ends.
    static func summaryPrefix(for module: ModuleID) -> String {
        switch module {
        case .cleanup: "Cleanup scan:"
        case .duplicates: "Duplicate scan:"
        case .spaceLens: "Large & Old scan:"
        case .applications: "Applications scan:"
        default: module.rawValue
        }
    }

    /// The most recent scan of each module, from the activity table.
    ///
    /// Pure so the mapping from a recorded sentence to a module is testable
    /// without a database: the sentences were written by the modules, and a
    /// rename on one side has silently broken this kind of lookup before.
    static func lastScans(from events: [ActivityRecord],
                          modules: [ModuleID] = ModuleID.allCases.filter(\.hasScan)) -> [ScanResult] {
        modules.compactMap { module in
            let prefix = summaryPrefix(for: module)
            guard let latest = events
                .filter({ $0.kind == .scan && $0.summary.hasPrefix(prefix) })
                .max(by: { $0.date < $1.date })
            else { return nil }
            return ScanResult(module: module, date: latest.date,
                              bytes: latest.bytes, itemCount: latest.itemCount)
        }
    }

    /// One volume's three real quantities, plus the part of it CoreTend has
    /// looked at.
    struct VolumeBreakdown: Equatable {
        let total: Int64
        let free: Int64
        /// What the most recent Cleanup scan found on this Mac. A fraction of
        /// "used", drawn inside it — never added to anything.
        let foundByLastScan: Int64?

        var used: Int64 { max(0, total - free) }
        var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
        /// The found portion as a fraction of the whole volume, clamped so a
        /// stale figure larger than current usage cannot draw past the bar.
        var foundFraction: Double {
            guard let foundByLastScan, total > 0 else { return 0 }
            return min(Double(foundByLastScan) / Double(total), usedFraction)
        }
    }
}
