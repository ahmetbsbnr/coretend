// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
@testable import CoreTendApp

/// Large & Old is read-only (reveal / Quick Look only, no deletion path).
/// The one seam the UI depends on is `sortedFindings` — the exact projection
/// the results List renders. These tests pin its size/age ordering.
@Suite("My Clutter (Large & Old) sorting")
@MainActor
struct MyClutterSortTests {
    private func finding(_ name: String, size: Int64, modified: Date?) -> ScanFinding {
        ScanFinding(url: URL(fileURLWithPath: "/tmp/\(name)"), logicalSize: size,
                    allocatedSize: size, modificationDate: modified,
                    ruleID: "clutter.largeold", category: "My Clutter",
                    explanation: "", confidence: 0.9, risk: .high, preselected: false)
    }

    @Test func sortsBySizeLargestFirst() {
        let m = MyClutterViewModel()
        m.sortOption = .size
        m.findings = [finding("small", size: 10, modified: .now),
                      finding("big", size: 1000, modified: .now),
                      finding("mid", size: 100, modified: .now)]
        #expect(m.sortedFindings.map(\.logicalSize) == [1000, 100, 10])
    }

    @Test func sortsByAgeOldestFirstMissingDatesLast() {
        let m = MyClutterViewModel()
        m.sortOption = .age
        let old = Date(timeIntervalSince1970: 0)
        let recent = Date(timeIntervalSince1970: 1_000_000)
        m.findings = [finding("recent", size: 1, modified: recent),
                      finding("nodate", size: 1, modified: nil),
                      finding("old", size: 1, modified: old)]
        #expect(m.sortedFindings.map { $0.url.lastPathComponent } == ["old", "recent", "nodate"])
    }

    @Test func searchNarrowsSortedFindingsWithoutRescanning() {
        let m = MyClutterViewModel()
        m.findings = [finding("vacation.mov", size: 100, modified: .now),
                      finding("invoice.pdf", size: 50, modified: .now)]
        m.searchText = "vacation"
        #expect(m.sortedFindings.map { $0.url.lastPathComponent } == ["vacation.mov"])
        m.searchText = ""
        #expect(m.sortedFindings.count == 2) // original scan preserved, not re-run
    }

    private struct FixedVolumeResolver: VolumeResolving {
        let table: [String: VolumeInfo]
        func volumeInfo(for url: URL) -> VolumeInfo? { table[url.path] }
    }

    @Test func volumeFilterNarrowsToSelectedVolumeOnly() {
        let resolver = FixedVolumeResolver(table: [
            "/tmp/internal.dat": VolumeInfo(id: "internal-uuid", name: "Macintosh HD"),
            "/tmp/external.dat": VolumeInfo(id: "external-uuid", name: "Backup"),
        ])
        let m = MyClutterViewModel(volumeResolver: resolver)
        m.findings = [finding("internal.dat", size: 10, modified: .now),
                      finding("external.dat", size: 10, modified: .now)]
        #expect(m.availableVolumes.map(\.id).sorted() == ["external-uuid", "internal-uuid"])
        m.selectedVolumeID = "external-uuid"
        #expect(m.sortedFindings.map { $0.url.lastPathComponent } == ["external.dat"])
    }
}
