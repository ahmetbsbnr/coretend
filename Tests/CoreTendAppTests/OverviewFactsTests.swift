// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
import Persistence
@testable import CoreTendApp

@Suite("The Overview only states what was measured")
struct OverviewFactsTests {
    private func scan(_ summary: String, daysAgo: Int, bytes: Int64 = 1_000, items: Int = 5) -> ActivityRecord {
        ActivityRecord(kind: .scan,
                       date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
                       summary: summary, itemCount: items, bytes: bytes)
    }

    @Test func aModuleWithNoScanHasNoRow() {
        #expect(OverviewFacts.lastScans(from: []).isEmpty)
    }

    /// Never scanned is not the same as found nothing. A module that has never
    /// run is absent, so the screen can say "never" rather than print a zero
    /// that reads as a finding.
    @Test func neverScannedIsAbsentRatherThanZero() {
        let scans = OverviewFacts.lastScans(from: [scan("Cleanup scan: 4 items found", daysAgo: 1)])
        #expect(scans.map(\.module) == [.cleanup])
    }

    @Test func theLatestScanOfEachModuleWins() {
        let scans = OverviewFacts.lastScans(from: [
            scan("Cleanup scan: old", daysAgo: 9, bytes: 10),
            scan("Cleanup scan: new", daysAgo: 1, bytes: 99),
            scan("Duplicate scan: 3 groups", daysAgo: 4, bytes: 50),
        ])
        #expect(scans.count == 2)
        #expect(scans.first { $0.module == .cleanup }?.bytes == 99)
    }

    /// The lookup matches the sentence each module writes. If a module renames
    /// its summary without changing the prefix here, the Overview quietly
    /// stops knowing that scan ever happened — which is exactly the kind of
    /// silent break this pins down.
    @Test func everyScannableModuleHasAPrefixThatMatchesWhatItWrites() {
        for (module, written) in [(ModuleID.cleanup, "Cleanup scan: 12 items found"),
                                  (.duplicates, "Duplicate scan: 3 groups"),
                                  (.spaceLens, "Large & Old scan: 8 files")] {
            #expect(written.hasPrefix(OverviewFacts.summaryPrefix(for: module)),
                    "\(module) writes \"\(written)\" but the Overview looks for \"\(OverviewFacts.summaryPrefix(for: module))\"")
        }
    }

    @Test func aVolumeReportsUsedAndFree() {
        let v = OverviewFacts.VolumeBreakdown(total: 1_000, free: 400, foundByLastScan: nil)
        #expect(v.used == 600)
        #expect(abs(v.usedFraction - 0.6) < 0.001)
        #expect(v.foundFraction == 0)
    }

    /// A scan from last month can report more than the disk currently holds.
    /// Drawn unclamped, that segment runs past the end of the bar.
    @Test func aStaleFindingCannotDrawPastTheUsedPortion() {
        let v = OverviewFacts.VolumeBreakdown(total: 1_000, free: 900, foundByLastScan: 800)
        #expect(v.foundFraction == v.usedFraction)
    }

    @Test func anEmptyVolumeDividesByNothing() {
        let v = OverviewFacts.VolumeBreakdown(total: 0, free: 0, foundByLastScan: 100)
        #expect(v.usedFraction == 0)
        #expect(v.foundFraction == 0)
    }
}

/// "Which modules scan" is one fact.
///
/// The toolbar's scan button, the Overview's scan rows and the summary-prefix
/// lookup each carried their own list, and they had already drifted: one of
/// them still expected Applications to be unscannable. `ModuleID.hasScan` is
/// the single answer, and this keeps the prefix table honest against it.
@Suite("Scannable modules are listed once")
struct ScannableModuleTests {
    @Test func everyScannableModuleHasASummaryPrefix() {
        for module in ModuleID.allCases where module.hasScan {
            let prefix = OverviewFacts.summaryPrefix(for: module)
            #expect(prefix != module.rawValue || module == .applications,
                    "\(module) falls through to its raw value — add its real prefix")
            #expect(!prefix.isEmpty)
        }
    }

    @Test func modulesWithoutAScanAreNotOfferedOne() {
        for module in [ModuleID.smartCare, .record, .protection, .performance] {
            #expect(!module.hasScan, "\(module) would show a Scan button that does nothing")
        }
    }
}
