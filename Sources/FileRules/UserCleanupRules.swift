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

    public static let all: [ScanRule] = [
        userCaches, userLogs, crashReports, xcodeDerivedData,
        incompleteDownloads, xcodeDeviceSupport, iosBackups,
    ]

    /// Allowed deletion roots corresponding to the rules above.
    public static func allowedRoots(home: URL) -> [URL] {
        [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
            home.appendingPathComponent("Library/Application Support/MobileSync/Backup"),
            home.appendingPathComponent("Downloads"),
        ]
    }
}
