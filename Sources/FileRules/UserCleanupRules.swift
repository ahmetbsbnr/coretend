// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore
import SafetyCore

/// Built-in low-risk cleanup rules limited to reversible, user-domain locations.
public enum UserCleanupRules {
    public static let userCaches = ScanRule(
        id: "user.caches",
        name: "User caches",
        category: "Cleanup",
        explanation: "Application cache files in ~/Library/Caches. Apps rebuild these automatically.",
        minimumAgeDays: 0,
        risk: .low,
        preselect: true
    ) { home in
        [home.appendingPathComponent("Library/Caches")]
    }

    public static let userLogs = ScanRule(
        id: "user.logs",
        name: "User logs",
        category: "Cleanup",
        explanation: "Log files in ~/Library/Logs older than 7 days.",
        minimumAgeDays: 7,
        risk: .low,
        preselect: true
    ) { home in
        [home.appendingPathComponent("Library/Logs")]
    }

    public static let crashReports = ScanRule(
        id: "user.crashreports",
        name: "Crash reports",
        category: "Cleanup",
        explanation: "Diagnostic reports older than 30 days in ~/Library/Logs/DiagnosticReports.",
        minimumAgeDays: 30,
        risk: .low,
        preselect: true
    ) { home in
        [home.appendingPathComponent("Library/Logs/DiagnosticReports")]
    }

    public static let xcodeDerivedData = ScanRule(
        id: "dev.xcode.deriveddata",
        name: "Xcode DerivedData",
        category: "Cleanup",
        explanation: "Xcode build intermediates. Rebuilt on next build; safe to remove.",
        minimumAgeDays: 0,
        risk: .low,
        preselect: true
    ) { home in
        [home.appendingPathComponent("Library/Developer/Xcode/DerivedData")]
    }

    public static let incompleteDownloads = ScanRule(
        id: "user.incompletedownloads",
        name: "Incomplete downloads",
        category: "Cleanup",
        explanation: "Partial download files (.download, .crdownload, .part) in ~/Downloads older than 7 days.",
        minimumAgeDays: 7,
        risk: .low,
        preselect: true,
        matches: { url in
            ["download", "crdownload", "part", "partial"].contains(url.pathExtension.lowercased())
        }
    ) { home in
        [home.appendingPathComponent("Downloads")]
    }

    public static let xcodeDeviceSupport = ScanRule(
        id: "dev.xcode.devicesupport",
        name: "Xcode device support",
        category: "Cleanup",
        explanation: "Debug symbols for old iOS devices. Regenerated when a device reconnects.",
        minimumAgeDays: 90,
        risk: .medium,
        preselect: false
    ) { home in
        [home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport")]
    }

    public static let iosBackups = ScanRule(
        id: "user.iosbackups",
        name: "iOS device backups",
        category: "Cleanup",
        explanation: "Local iPhone/iPad backups older than 180 days. Verify you no longer need them before removing.",
        minimumAgeDays: 180,
        risk: .high,
        preselect: false
    ) { home in
        [home.appendingPathComponent("Library/Application Support/MobileSync/Backup")]
    }

    /// Old disk-image / package installers left in ~/Downloads. Never preselected:
    /// the user may still need them, and they can be re-downloaded but not restored
    /// from a rebuild. Downloads only — never system roots.
    public static let oldInstallers = ScanRule(
        id: "user.oldinstallers",
        name: "Old installers",
        category: "Cleanup",
        explanation: "Disk images and installer packages (.dmg/.pkg/.mpkg) in ~/Downloads older than 30 days. Review each — never auto-selected.",
        minimumAgeDays: 30,
        risk: .medium,
        preselect: false,
        matches: { url in
            ["dmg", "pkg", "mpkg"].contains(url.pathExtension.lowercased())
        }
    ) { home in
        [home.appendingPathComponent("Downloads")]
    }

    /// Old archives in ~/Downloads. Never auto-extracted or opened; matched by
    /// extension only (no archive parsing), size + age gated, never preselected.
    public static let oldArchives = ScanRule(
        id: "user.oldarchives",
        name: "Old archives",
        category: "Cleanup",
        explanation: "Archive files (.zip/.tar/.gz/.bz2/.xz/.7z/.rar) in ~/Downloads older than 30 days. Contents are never inspected; review before removing.",
        minimumAgeDays: 30,
        risk: .medium,
        preselect: false,
        matches: { url in
            ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar"].contains(url.pathExtension.lowercased())
        },
        minimumSizeBytes: 1_048_576
    ) { home in
        [home.appendingPathComponent("Downloads")]
    }

    /// Xcode archives (build products from Organizer). Recent ones are unchecked
    /// by default and never auto-deleted; they may hold the only copy of a build.
    public static let xcodeArchives = ScanRule(
        id: "dev.xcode.archives",
        name: "Xcode archives",
        category: "Cleanup",
        explanation: "Archived builds in ~/Library/Developer/Xcode/Archives older than 30 days. May contain your only copy of a shipped build — review before removing.",
        minimumAgeDays: 30,
        risk: .medium,
        preselect: false
    ) { home in
        [home.appendingPathComponent("Library/Developer/Xcode/Archives")]
    }

    public static let all: [ScanRule] = [
        userCaches, userLogs, crashReports, xcodeDerivedData,
        incompleteDownloads, xcodeDeviceSupport, iosBackups,
        oldInstallers, oldArchives, xcodeArchives,
    ]

    /// The only findings any automated flow may act on without a per-item
    /// review: reversible, low-risk, and already preselected. Medium/high-risk
    /// rules (all the installer/archive/Xcode-archive rules ship
    /// `preselect: false` + `risk >= .medium`) are structurally excluded here,
    /// so a bug that left one preselected still cannot make it auto-executable.
    /// Pure, so the invariant is unit-testable without a store or a filesystem.
    public static func autoExecutable(_ findings: [ScanFinding]) -> [ScanFinding] {
        findings.filter { $0.preselected && $0.risk == .low }
    }

    /// Allowed deletion roots corresponding to the rules above.
    public static func allowedRoots(home: URL) -> [URL] {
        [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
            home.appendingPathComponent("Library/Developer/Xcode/Archives"),
            home.appendingPathComponent("Library/Application Support/MobileSync/Backup"),
            home.appendingPathComponent("Downloads"),
        ]
    }
}
