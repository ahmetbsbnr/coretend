import Foundation

/// Pure grouping logic for the Applications constellation view. No I/O, no
/// SwiftUI — safe to call from any actor and to unit test directly.
public enum AppGroupMode: String, CaseIterable, Sendable {
    case publisher = "Publisher"
    case size = "Size"
    case updateState = "Update state"
    case lastUsed = "Last used"
}

public enum AppUpdateState: String, Sendable {
    case appStore = "App Store"
    case sparkle = "Sparkle feed"
    case manual = "In-app / manual"
}

public enum AppGrouping {
    /// Classifies an app's update mechanism from its bundle contents. Mirrors
    /// AppUpdatesView's detection (App Store receipt, then Sparkle feed URL).
    public static func updateState(for app: InstalledApp) -> AppUpdateState {
        let fm = FileManager.default
        if fm.fileExists(atPath: app.path.appendingPathComponent("Contents/_MASReceipt").path) {
            return .appStore
        }
        let plistURL = app.path.appendingPathComponent("Contents/Info.plist")
        if let data = try? Data(contentsOf: plistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let feedString = plist["SUFeedURL"] as? String,
           let feedURL = URL(string: feedString), feedURL.scheme == "https" {
            return .sparkle
        }
        return .manual
    }

    private static let sizeBuckets: [(String, Int64)] = [
        ("Under 100 MB", 100 * 1_000_000),
        ("100 MB – 500 MB", 500 * 1_000_000),
        ("500 MB – 1 GB", 1_000_000_000),
        ("1 GB – 5 GB", 5_000_000_000),
        ("Over 5 GB", Int64.max),
    ]

    public static func sizeBucket(for bytes: Int64) -> String {
        for (label, ceiling) in sizeBuckets where bytes < ceiling { return label }
        return sizeBuckets.last!.0
    }

    private static func lastUsedBucket(for date: Date?, now: Date) -> String {
        guard let date else { return "Unknown" }
        let days = now.timeIntervalSince(date) / 86400
        switch days {
        case ..<7: return "This week"
        case ..<30: return "This month"
        case ..<180: return "Last 6 months"
        case ..<365: return "This year"
        default: return "Over a year ago"
        }
    }

    /// Groups apps into labeled buckets per `mode`, sorted by descending
    /// combined size within a stable, mode-appropriate bucket order.
    public static func grouped(_ apps: [InstalledApp], by mode: AppGroupMode, now: Date = Date()) -> [(label: String, apps: [InstalledApp])] {
        let keyed: [(String, InstalledApp)] = apps.map { app in
            switch mode {
            case .publisher: return (app.publisher, app)
            case .size: return (sizeBucket(for: app.sizeBytes), app)
            case .updateState: return (updateState(for: app).rawValue, app)
            case .lastUsed: return (lastUsedBucket(for: app.lastUsedDate, now: now), app)
            }
        }
        var buckets: [String: [InstalledApp]] = [:]
        for (label, app) in keyed { buckets[label, default: []].append(app) }
        return buckets.map { (label: $0.key, apps: $0.value.sorted { $0.sizeBytes > $1.sizeBytes }) }
            .sorted { lhs, rhs in
                let l = lhs.apps.reduce(0) { $0 + $1.sizeBytes }
                let r = rhs.apps.reduce(0) { $0 + $1.sizeBytes }
                return l != r ? l > r : lhs.label < rhs.label
            }
    }

    /// VoiceOver summary for a group bucket — real counts/bytes, never decorative.
    public static func accessibilityDescription(label: String, apps: [InstalledApp]) -> String {
        let totalBytes = apps.reduce(0) { $0 + $1.sizeBytes }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let sizeString = formatter.string(fromByteCount: totalBytes)
        let ambiguousCount = apps.filter(\.isDataLocationAmbiguous).count
        var text = "\(label): \(apps.count) app\(apps.count == 1 ? "" : "s"), \(sizeString) total."
        if ambiguousCount > 0 {
            text += " \(ambiguousCount) with ambiguous data location."
        }
        return text
    }
}
