// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

@Suite("System authorization")
struct SystemAuthorizationTests {
    private let home = URL(fileURLWithPath: "/Users/tester")

    /// Builds an environment from a map of path -> errno (nil errno = readable).
    /// A path absent from the map does not exist at all.
    private func environment(
        _ paths: [String: Int32?],
        volumes: [String] = []
    ) -> SystemAuthorization.Environment {
        let full = Dictionary(uniqueKeysWithValues: paths.map { (home.appendingPathComponent($0).path, $1) })
        let all = full.merging(
            Dictionary(uniqueKeysWithValues: volumes.map { ($0, Int32?.none) }),
            uniquingKeysWith: { a, _ in a })
        return SystemAuthorization.Environment(
            exists: { all.keys.contains($0) },
            listErrno: { all[$0] ?? ENOENT },
            removableVolumePaths: { volumes },
            home: home
        )
    }

    // MARK: - The bug this type exists to prevent

    /// The old `hasFullDiskAccess()` returned false when neither probe path
    /// existed, which a Settings screen then rendered as "Not granted" —
    /// telling the user to fix a permission that was never refused.
    @Test func noProbePathMeansUndetermined_notDenied() {
        let report = SystemAuthorization.probe(environment([:]))
        #expect(report.grant(for: .fullDisk) == .undetermined)
        #expect(report.grant(for: .fullDisk).needsAttention == false)
        #expect(report.denied.isEmpty, "an unprobeable Mac must raise nothing")
    }

    @Test func aMissingFolderIsNotADenial() {
        let report = SystemAuthorization.probe(environment(["Library/Safari": nil]))
        // No Desktop/Documents/Downloads in the map at all.
        for capability in [SystemAuthorization.Capability.desktop, .documents, .downloads] {
            #expect(report.grant(for: capability) == .undetermined, "\(capability) wrongly classified")
        }
        #expect(report.isComplete)
    }

    /// ENOENT is not EPERM. Classifying "it vanished" as "you are refused"
    /// produces a permanent, unfixable warning.
    @Test func onlyPermissionErrnosCountAsDenial() {
        #expect(SystemAuthorization.classify(errno: nil) == .granted)
        #expect(SystemAuthorization.classify(errno: EPERM) == .denied)
        #expect(SystemAuthorization.classify(errno: EACCES) == .denied)
        #expect(SystemAuthorization.classify(errno: ENOENT) == .undetermined)
        #expect(SystemAuthorization.classify(errno: EIO) == .undetermined)
    }

    // MARK: - Full Disk Access

    @Test func oneReadableProtectedPathProvesFullDiskAccess() {
        let report = SystemAuthorization.probe(environment([
            "Library/Safari": EPERM,   // this Mac refuses Safari's folder
            "Library/Mail": nil,       // but Mail reads fine
        ]))
        #expect(report.grant(for: .fullDisk) == .granted)
        #expect(report.hasFullDiskAccess)
    }

    @Test func refusalOnEveryExistingProtectedPathIsADenial() {
        let report = SystemAuthorization.probe(environment([
            "Library/Safari": EPERM,
            "Library/Mail": EPERM,
        ]))
        #expect(report.grant(for: .fullDisk) == .denied)
        #expect(report.hasFullDiskAccess == false)
        #expect(report.denied.contains(.fullDisk))
    }

    // MARK: - Per-folder grants are independent of FDA

    /// macOS stopped having one permission. A user can decline Full Disk
    /// Access and still have granted Desktop; reporting that Mac as locked out
    /// of Desktop is simply false.
    @Test func folderGrantsAreIndependentOfFullDiskAccess() {
        let report = SystemAuthorization.probe(environment([
            "Library/Safari": EPERM,
            "Library/Mail": EPERM,
            "Desktop": nil,
            "Documents": EPERM,
            "Downloads": nil,
        ]))
        #expect(report.grant(for: .fullDisk) == .denied)
        #expect(report.grant(for: .desktop) == .granted)
        #expect(report.grant(for: .documents) == .denied)
        #expect(report.grant(for: .downloads) == .granted)
        #expect(Set(report.denied) == [.fullDisk, .documents])
    }

    // MARK: - Removable volumes

    @Test func noExternalDiskIsNotApplicable_neverADenial() {
        let report = SystemAuthorization.probe(environment(["Desktop": nil]))
        #expect(report.grant(for: .removableVolumes) == .notApplicable)
        #expect(report.grant(for: .removableVolumes).needsAttention == false)
    }

    /// The removable-media grant is per-app, not per-disk. One readable volume
    /// proves CoreTend has it, so a second unreadable disk is that disk's
    /// problem and must not be reported as a missing authorization.
    @Test func oneReadableVolumeProvesTheGrant() {
        let env = SystemAuthorization.Environment(
            exists: { _ in false },
            listErrno: { $0 == "/Volumes/Good" ? nil : EPERM },
            removableVolumePaths: { ["/Volumes/Good", "/Volumes/Locked"] },
            home: home
        )
        #expect(SystemAuthorization.probe(env).grant(for: .removableVolumes) == .granted)
    }

    @Test func everyVolumeRefusedIsADenial() {
        let env = SystemAuthorization.Environment(
            exists: { _ in false },
            listErrno: { _ in EPERM },
            removableVolumePaths: { ["/Volumes/A", "/Volumes/B"] },
            home: home
        )
        #expect(SystemAuthorization.probe(env).grant(for: .removableVolumes) == .denied)
    }

    // MARK: - Presentation contract

    /// Fixing Full Disk Access fixes the folders under it, so it must be the
    /// first thing offered when several things are refused.
    @Test func fullDiskAccessIsOfferedFirst() {
        let report = SystemAuthorization.probe(environment([
            "Library/Safari": EPERM,
            "Documents": EPERM,
        ]))
        #expect(report.actionable.first?.capability == .fullDisk)
    }

    /// Only Full Disk Access has a Settings pane that can grant it. Offering
    /// "Open System Settings" for a per-folder grant sends the user somewhere
    /// they cannot fix anything.
    @Test func onlyFullDiskAccessOffersASettingsPane() {
        for capability in SystemAuthorization.Capability.allCases {
            #expect(capability.hasDirectSettingsPane == (capability == .fullDisk))
        }
        #expect(SystemAuthorization.fullDiskAccessSettingsURL != nil)
    }

    @Test func everyCapabilityHasBothLocalizedStrings() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for lang in ["Base", "fr"] {
            let text = try String(
                contentsOf: root.appendingPathComponent(
                    "Sources/CoreTendApp/Resources/\(lang).lproj/Localizable.strings"),
                encoding: .utf16)
            for capability in SystemAuthorization.Capability.allCases {
                #expect(text.contains("\"\(capability.titleKey)\""), "\(lang): \(capability.titleKey)")
                #expect(text.contains("\"\(capability.impactKey)\""), "\(lang): \(capability.impactKey)")
            }
        }
    }
}
