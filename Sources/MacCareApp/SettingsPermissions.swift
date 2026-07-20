import Foundation
import UserNotifications
import MalwareEngine

/// Honest permission/state model for the Settings screen. Derivation is pure
/// and unit-testable; the system probes that feed it live in `SettingsPermissionProbe`.
enum PermissionState: Equatable {
    case granted
    case notGranted
    case denied
    case notApplicable
}

struct SettingsPermissionRow: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let state: PermissionState
}

enum SettingsPermissions {
    /// Full Disk Access: PermissionProbe.hasFullDiskAccess() only returns true
    /// when a TCC-protected folder was actually readable — never assumed.
    static func fullDiskAccessRow(granted: Bool) -> SettingsPermissionRow {
        SettingsPermissionRow(
            id: "fda", title: "Full Disk Access",
            detail: granted
                ? "Granted — Mail, Safari and other protected folders can be scanned."
                : "Not granted — some folders can't be scanned. The app still works.",
            state: granted ? .granted : .notGranted)
    }

    /// ClamAV presence is a filesystem fact (binary found or not) — not tied
    /// to any granted/denied permission semantics.
    static func clamAVRow(available: Bool) -> SettingsPermissionRow {
        SettingsPermissionRow(
            id: "clamav", title: "Malware engine (ClamAV)",
            detail: available
                ? "Installed — local malware scanning is available."
                : "Not installed — `brew install clamav` to enable scanning.",
            state: available ? .granted : .notGranted)
    }

    /// MacCare Local never installs a privileged helper or launch daemon —
    /// cleaning only ever uses Trash moves and other user-level file ops.
    static func privilegedHelperRow() -> SettingsPermissionRow {
        SettingsPermissionRow(
            id: "helper", title: "Privileged helper",
            detail: "Not used. MacCare Local never installs a root helper or launch daemon — all file operations run as your user account.",
            state: .notApplicable)
    }

    static func notificationRow(status: UNAuthorizationStatus) -> SettingsPermissionRow {
        let state: PermissionState
        let detail: String
        switch status {
        case .authorized, .provisional, .ephemeral:
            state = .granted
            detail = "Allowed — MacCare can post system notifications."
        case .denied:
            state = .denied
            detail = "Denied in System Settings. Re-enable there to allow notifications."
        default:
            state = .notGranted
            detail = "Not requested yet. MacCare does not currently send notifications."
        }
        return SettingsPermissionRow(id: "notifications", title: "Notifications", detail: detail, state: state)
    }

    static func menuBarRow(enabled: Bool) -> SettingsPermissionRow {
        SettingsPermissionRow(
            id: "menubar", title: "Menu bar agent",
            detail: enabled ? "Enabled — samples system metrics only while its panel is open." : "Disabled.",
            state: enabled ? .granted : .notApplicable)
    }

    static func folderAccessRow(exclusionCount: Int) -> SettingsPermissionRow {
        SettingsPermissionRow(
            id: "folders", title: "Folder exclusions",
            detail: exclusionCount == 0
                ? "No excluded folders — all non-system locations are eligible for scan."
                : "\(exclusionCount) folder\(exclusionCount == 1 ? "" : "s") excluded from scanning and cleaning.",
            state: .notApplicable)
    }
}

/// Live system probes. Kept separate from the pure derivation above so the
/// derivation logic can be unit-tested without touching TCC/UNUserNotificationCenter.
enum SettingsPermissionProbe {
    static func hasFullDiskAccess() -> Bool { PermissionProbe.hasFullDiskAccess() }

    static func clamAVAvailable() -> Bool { ClamAVScanner().isAvailable }

    static func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
