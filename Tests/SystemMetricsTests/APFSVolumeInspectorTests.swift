// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import SystemMetrics

@Suite("APFSMetric")
struct APFSMetricTests {
    @Test func measuredCarriesItsValue() {
        let metric = APFSMetric.measured(42)
        #expect(metric.value == 42)
        #expect(metric.isAvailable)
    }

    @Test func unavailableCarriesNoValueButARealReason() {
        let metric: APFSMetric<Int> = .unavailable(reason: "test reason")
        #expect(metric.value == nil)
        #expect(!metric.isAvailable)
        guard case let .unavailable(reason) = metric else {
            Issue.record("expected .unavailable")
            return
        }
        #expect(reason == "test reason")
    }

    @Test func fromNilProducesUnavailableNeverZero() {
        let metric: APFSMetric<Int64> = .from(nil, reason: "missing")
        #expect(metric.value == nil, "a missing measurement must never silently become 0")
    }

    @Test func fromNonNilProducesMeasured() {
        let metric: APFSMetric<Int64> = .from(1_000, reason: "unused")
        #expect(metric == .measured(1_000))
    }
}

/// Assumes the machine running these tests boots from an APFS volume — true
/// for every Mac able to run macOS 14+, the project's own minimum deployment
/// target (Package.swift `platforms: [.macOS(.v14)]`). This is the only
/// filesystem type these tests can exercise without a mounted non-APFS
/// volume (HFS+/ExFAT/SMB/a disk image) — see
/// `Documentation/APFS_INTELLIGENCE.md` for that documented limitation.
@Suite("APFSVolumeInspector — real volume")
struct APFSVolumeInspectorRealVolumeTests {
    @Test func inspectingTheBootVolumeReportsAPFSWithPlausibleCapacity() {
        let info = APFSVolumeInspector.inspect(path: URL(fileURLWithPath: "/"))
        #expect(info.filesystemTypeRaw == "apfs")
        #expect(info.isAPFS)
        // 10 GB floor: comfortably below any real Mac's boot volume, so this
        // never becomes a flaky assumption about a specific disk size.
        #expect((info.totalCapacity.value ?? 0) > 10_000_000_000)
        #expect(info.availableCapacity.isAvailable)
    }

    @Test func homeDirectoryReportsTheSameFilesystemTypeAsRoot() {
        let home = APFSVolumeInspector.inspect(path: FileManager.default.homeDirectoryForCurrentUser)
        #expect(home.filesystemTypeRaw == "apfs", "the test machine's home volume is expected to be APFS")
    }

    @Test func usedFractionIsBetweenZeroAndOneWhenMeasured() {
        let info = APFSVolumeInspector.inspect(path: URL(fileURLWithPath: "/"))
        if case let .measured(fraction) = info.usedFraction {
            #expect(fraction >= 0 && fraction <= 1)
        }
        // No else-fail: a real environment could plausibly lack one of the
        // two capacities; usedFraction's own unavailable-propagation is what
        // nonexistentPathReportsEverythingUnavailable below actually proves.
    }
}

@Suite("APFSVolumeInspector — failure paths")
struct APFSVolumeInspectorFailureTests {
    @Test func nonexistentPathReportsEverythingUnavailableNeverAFabricatedNumber() {
        let bogus = URL(fileURLWithPath: "/this/path/does/not/exist/\(UUID().uuidString)")
        let info = APFSVolumeInspector.inspect(path: bogus)
        #expect(info.filesystemTypeRaw == "unknown")
        #expect(!info.isAPFS)
        #expect(!info.totalCapacity.isAvailable)
        #expect(!info.availableCapacity.isAvailable)
        #expect(!info.availableCapacityForImportantUsage.isAvailable)
        #expect(!info.availableCapacityForOpportunisticUsage.isAvailable)
        if case let .unavailable(fractionReason) = info.usedFraction {
            #expect(!fractionReason.isEmpty)
        } else {
            Issue.record("usedFraction must be unavailable when its inputs are")
        }
    }

    @Test func filesystemTypeRawIsNilForANonexistentPath() {
        let bogus = "/this/path/does/not/exist/\(UUID().uuidString)"
        #expect(APFSVolumeInspector.filesystemTypeRaw(atPath: bogus) == nil)
    }
}
