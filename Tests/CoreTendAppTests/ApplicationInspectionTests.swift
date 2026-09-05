// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
import AppDiscovery
import IntegrityCore
@testable import CoreTendApp

// MARK: - Fixture helpers

private func fixtureApp(bundleID: String? = "com.acme.App", name: String = "App",
                        path: URL = URL(fileURLWithPath: "/Applications/App.app"),
                        sizeBytes: Int64 = 0, architectures: [String] = []) -> InstalledApp {
    InstalledApp(name: name, bundleIdentifier: bundleID, version: "1.0", path: path,
                sizeBytes: sizeBytes, architectures: architectures)
}

private func fixtureItem(kind: AssociatedItem.Kind, name: String, sizeBytes: Int64 = 1_000) -> AssociatedItem {
    AssociatedItem(kind: kind, url: URL(fileURLWithPath: "/Library/\(kind.rawValue)/\(name)"), sizeBytes: sizeBytes)
}

private func fixtureLoginItem(label: String, programPath: String?) -> LoginItem {
    LoginItem(label: label, programPath: programPath, scope: .userAgent, plistPath: "/Library/LaunchAgents/\(label).plist")
}

/// Writes a minimal fat Mach-O header (magic + count + N fat_arch entries) to
/// `url`, big-endian, matching the real on-disk layout `UniversalBinaryAnalyzer`
/// parses. `entries` is `(cpuType, offset, size)`.
private func writeFatHeader(to url: URL, entries: [(UInt32, UInt32, UInt32)], totalFileSize: Int) throws {
    var bytes: [UInt8] = []
    func appendBE32(_ value: UInt32) {
        bytes.append(UInt8((value >> 24) & 0xFF))
        bytes.append(UInt8((value >> 16) & 0xFF))
        bytes.append(UInt8((value >> 8) & 0xFF))
        bytes.append(UInt8(value & 0xFF))
    }
    appendBE32(0xCAFE_BABE)
    appendBE32(UInt32(entries.count))
    for (cpuType, offset, size) in entries {
        appendBE32(cpuType)
        appendBE32(0)       // cpusubtype
        appendBE32(offset)
        appendBE32(size)
        appendBE32(0)       // align
    }
    while bytes.count < totalFileSize { bytes.append(0) }
    try Data(bytes).write(to: url)
}

@Suite("UniversalBinaryAnalyzer")
struct UniversalBinaryAnalyzerTests {
    private let arm64: UInt32 = 0x0100_000C
    private let x86_64: UInt32 = 0x0100_0007

    @Test func parsesTwoRealSlices() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fat-\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        // header (28 bytes for 2 entries) then arm64 slice at 4096, x86_64 at 8192.
        try writeFatHeader(to: url, entries: [(arm64, 4096, 1000), (x86_64, 8192, 2000)], totalFileSize: 10192)

        let slices = try #require(UniversalBinaryAnalyzer.slices(at: url))
        #expect(slices.count == 2)
        #expect(slices[0] == MachOSlice(architecture: "arm64", sizeBytes: 1000))
        #expect(slices[1] == MachOSlice(architecture: "x86_64", sizeBytes: 2000))
    }

    @Test func thinBinaryIsNotUniversalYieldsNil() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("thin-\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        // Mach-O 64 thin magic (0xCFFAEDFE), not the fat magic.
        try Data([0xCF, 0xFA, 0xED, 0xFE, 0, 0, 0, 0]).write(to: url)
        #expect(UniversalBinaryAnalyzer.slices(at: url) == nil)
    }

    @Test func unsupportedCPUTypeReportsUnknownRatherThanFailing() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fat-unknown-\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        try writeFatHeader(to: url, entries: [(0x9999_9999, 4096, 500)], totalFileSize: 4596)
        let slices = try #require(UniversalBinaryAnalyzer.slices(at: url))
        #expect(slices == [MachOSlice(architecture: "unknown", sizeBytes: 500)])
    }

    @Test func malformedHeaderTooShortFailsClosed() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("short-\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data([0xCA, 0xFE]).write(to: url)
        #expect(UniversalBinaryAnalyzer.slices(at: url) == nil)
    }

    @Test func truncatedArchTableFailsClosed() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("truncated-\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        // Claims 2 entries but the file ends right after the header.
        var bytes: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE, 0, 0, 0, 2]
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 8)) // only half of one fat_arch entry
        try Data(bytes).write(to: url)
        #expect(UniversalBinaryAnalyzer.slices(at: url) == nil)
    }

    @Test func implausibleSliceCountFailsClosed() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("huge-count-\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data([0xCA, 0xFE, 0xBA, 0xBE, 0xFF, 0xFF, 0xFF, 0xFF]).write(to: url) // nfatArch == UInt32.max
        #expect(UniversalBinaryAnalyzer.slices(at: url) == nil)
    }

    /// `offset`/`size` are read from 32-bit fields, so `offset + size` as a
    /// `UInt64` addition can never actually overflow (max ≈ 2×2^32, far below
    /// `UInt64.max`) — but a header claiming implausibly huge 32-bit values
    /// against a tiny real file must still fail closed via the bounds check,
    /// which is what this exercises (the overflow guard itself is
    /// defense-in-depth for this data width, not reachable here).
    @Test func implausiblyLargeOffsetAndSizeFailsClosed() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("large-offset-\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        try writeFatHeader(to: url, entries: [(arm64, UInt32.max, UInt32.max)], totalFileSize: 100)
        #expect(UniversalBinaryAnalyzer.slices(at: url) == nil)
    }

    @Test func sliceExtendingPastRealFileSizeFailsClosed() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("past-eof-\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        // Header claims a slice at offset 4096 sized 1000, but the file is only 100 bytes.
        var bytes: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE, 0, 0, 0, 1]
        func appendBE32(_ value: UInt32) {
            bytes.append(UInt8((value >> 24) & 0xFF)); bytes.append(UInt8((value >> 16) & 0xFF))
            bytes.append(UInt8((value >> 8) & 0xFF)); bytes.append(UInt8(value & 0xFF))
        }
        appendBE32(arm64); appendBE32(0); appendBE32(4096); appendBE32(1000); appendBE32(0)
        while bytes.count < 100 { bytes.append(0) }
        try Data(bytes).write(to: url)
        #expect(UniversalBinaryAnalyzer.slices(at: url) == nil)
    }

    @Test func zeroSlicesFailsClosed() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zero-\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data([0xCA, 0xFE, 0xBA, 0xBE, 0, 0, 0, 0]).write(to: url)
        #expect(UniversalBinaryAnalyzer.slices(at: url) == nil)
    }

    @Test func missingFileYieldsNilNeverThrows() {
        let url = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString).bin")
        #expect(UniversalBinaryAnalyzer.slices(at: url) == nil)
    }
}

@Suite("AssociatedItemConfidence")
struct AssociatedItemConfidenceTests {
    @Test func exactBundleIdentifierMatchIsExactAndNeverShared() {
        let association = AssociatedItemConfidence.classifyExact(fixtureItem(kind: .caches, name: "com.acme.App"))
        #expect(association.confidence == .exact)
        #expect(association.method == .exactBundleIdentifier)
        #expect(!association.isShared)
    }

    @Test func groupContainerHeuristicIsNeverExact() {
        let candidate = AppDiscovery.GroupContainerCandidate(
            item: fixtureItem(kind: .groupContainers, name: "group.com.acme.suite"), sharingAppCount: 1)
        let association = AssociatedItemConfidence.classify(candidate)
        #expect(association.confidence == .probable)
        #expect(association.method == .vendorPrefixHeuristic)
        #expect(!association.isShared)
    }

    @Test func groupContainerSharedByMultipleAppsIsFlaggedShared() {
        let candidate = AppDiscovery.GroupContainerCandidate(
            item: fixtureItem(kind: .groupContainers, name: "group.com.acme.suite"), sharingAppCount: 2)
        #expect(AssociatedItemConfidence.classify(candidate).isShared)
    }
}

@Suite("ApplicationStorageBreakdown")
struct ApplicationStorageBreakdownTests {
    @Test func sumsBytesPerKindAndOverall() {
        let associations = [
            AssociatedItemConfidence.classifyExact(fixtureItem(kind: .caches, name: "a", sizeBytes: 100)),
            AssociatedItemConfidence.classifyExact(fixtureItem(kind: .caches, name: "b", sizeBytes: 50)),
            AssociatedItemConfidence.classifyExact(fixtureItem(kind: .applicationSupport, name: "c", sizeBytes: 200)),
        ]
        let breakdown = ApplicationStorageBreakdown.build(applicationBytes: 1000, associations: associations)
        #expect(breakdown.applicationBytes == 1000)
        #expect(breakdown.knownAssociatedStorageBytes == 350)
        let cachesTotal = breakdown.byKind.first { $0.kind == .caches }?.bytes
        #expect(cachesTotal == 150)
    }

    @Test func noAssociatedItemsIsAMeasuredZeroNotMissing() {
        let breakdown = ApplicationStorageBreakdown.build(applicationBytes: 500, associations: [])
        #expect(breakdown.knownAssociatedStorageBytes == 0)
        #expect(breakdown.byKind.isEmpty)
    }
}

@Suite("LaunchItemAssociator")
struct LaunchItemAssociatorTests {
    private let app = fixtureApp(bundleID: "com.acme.App", path: URL(fileURLWithPath: "/Applications/App.app"))

    @Test func programPathInsideBundleIsExact() {
        let item = fixtureLoginItem(label: "com.acme.helper", programPath: "/Applications/App.app/Contents/Library/LoginItems/Helper.app")
        let associations = LaunchItemAssociator.associations(for: app, in: [item])
        #expect(associations.count == 1)
        #expect(associations.first?.confidence == .exact)
    }

    @Test func exactBundleIdentifierLabelIsHigh() {
        let item = fixtureLoginItem(label: "com.acme.App", programPath: "/usr/local/bin/unrelated")
        let associations = LaunchItemAssociator.associations(for: app, in: [item])
        #expect(associations.count == 1)
        #expect(associations.first?.confidence == .high)
    }

    @Test func bundleIdentifierPrefixedLabelIsHigh() {
        let item = fixtureLoginItem(label: "com.acme.App.UpdateHelper", programPath: nil)
        let associations = LaunchItemAssociator.associations(for: app, in: [item])
        #expect(associations.count == 1)
        #expect(associations.first?.confidence == .high)
    }

    @Test func nameResemblanceAloneIsNotSurfacedAtAll() {
        // "App Helper" merely looks like the app by name — no bundle-id or
        // in-bundle-path evidence — so it must not appear at any confidence.
        let item = fixtureLoginItem(label: "com.other.AppHelper", programPath: "/Library/Application Support/AppHelper/helper")
        #expect(LaunchItemAssociator.associations(for: app, in: [item]).isEmpty)
    }

    @Test func unrelatedLaunchItemIsOmitted() {
        let item = fixtureLoginItem(label: "com.unrelated.thing", programPath: "/usr/local/bin/thing")
        #expect(LaunchItemAssociator.associations(for: app, in: [item]).isEmpty)
    }

    @Test func appWithNoBundleIdentifierYieldsNoAssociations() {
        let noID = fixtureApp(bundleID: nil)
        let item = fixtureLoginItem(label: "com.acme.App", programPath: nil)
        #expect(LaunchItemAssociator.associations(for: noID, in: [item]).isEmpty)
    }
}

@Suite("ApplicationRuntimeInspector")
struct ApplicationRuntimeInspectorTests {
    @Test func runningWhenBundleIDInLiveSet() {
        #expect(ApplicationRuntimeInspector.classify(bundleIdentifier: "com.acme.App", runningBundleIdentifiers: ["com.acme.App"]) == .running)
    }

    @Test func notRunningWhenBundleIDAbsentFromLiveSet() {
        #expect(ApplicationRuntimeInspector.classify(bundleIdentifier: "com.acme.App", runningBundleIdentifiers: ["com.other.App"]) == .notRunning)
    }

    @Test func unknownWhenNoBundleIdentifier() {
        #expect(ApplicationRuntimeInspector.classify(bundleIdentifier: nil, runningBundleIdentifiers: ["com.acme.App"]) == .unknown)
    }
}

@Suite("AssociatedItemAdvisory")
struct AssociatedItemAdvisoryTests {
    @Test func sharedItemIsAlwaysHighRiskRegardlessOfKind() {
        let association = AssociatedItemAssociation(
            item: fixtureItem(kind: .caches, name: "shared"), confidence: .probable,
            method: .vendorPrefixHeuristic, isShared: true)
        #expect(AssociatedItemAdvisory.advise(association).risk == .high)
    }

    @Test func nonSharedCacheIsLowRisk() {
        let association = AssociatedItemAssociation(
            item: fixtureItem(kind: .caches, name: "own"), confidence: .exact,
            method: .exactBundleIdentifier, isShared: false)
        #expect(AssociatedItemAdvisory.advise(association).risk == .low)
    }

    @Test func everyAdvisoryIsTrashReversibleNeverSomethingStronger() {
        let association = AssociatedItemConfidence.classifyExact(fixtureItem(kind: .preferences, name: "com.acme.App"))
        #expect(AssociatedItemAdvisory.advise(association).reversibility == .trash)
    }
}
