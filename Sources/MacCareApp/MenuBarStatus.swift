import Foundation
import Persistence

/// Pure derivation of the menu bar's protection + last-run rows from the
/// activity log. Kept separate from the view so it's unit-testable without
/// SwiftUI, and so it never becomes a second metrics/scan pipeline — it only
/// reads what Smart Care / Protection already recorded.
enum MenuBarStatus {
    struct ProtectionStatus: Equatable {
        let text: String
        let isWarning: Bool
    }

    /// Never claims protection is active when ClamAV isn't installed, even if
    /// a clean scan was recorded previously (the binary could have been
    /// removed since).
    static func protectionStatus(clamAvailable: Bool, activity: [ActivityRecord]) -> ProtectionStatus {
        guard clamAvailable else {
            return ProtectionStatus(text: "ClamAV not installed — protection inactive", isWarning: true)
        }
        guard let last = activity.first(where: { $0.summary.hasPrefix("Malware scan") }) else {
            return ProtectionStatus(text: "No malware scan run yet", isWarning: false)
        }
        if last.kind == .error {
            return ProtectionStatus(text: last.summary, isWarning: true)
        }
        return ProtectionStatus(text: "Protected — \(relativeTime(last.date)) scan clean", isWarning: false)
    }

    /// Most recent Smart Care cleanup-scan summary, or nil if none recorded.
    static func lastSmartCareSummary(activity: [ActivityRecord]) -> String? {
        guard let last = activity.first(where: { $0.summary.hasPrefix("Smart Care") }) else { return nil }
        return "\(last.summary) — \(relativeTime(last.date))"
    }

    static func relativeTime(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(seconds / 60))m ago"
        case ..<86400: return "\(Int(seconds / 3600))h ago"
        default: return "\(Int(seconds / 86400))d ago"
        }
    }
}
