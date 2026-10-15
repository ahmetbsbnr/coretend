import Foundation
import Darwin

/// An app the person dragged to the Trash, with the files it left in the Library.
public struct TrashedApp: Sendable, Equatable, Identifiable {
    public var id: URL { trashURL }
    public let trashURL: URL
    public let name: String
    public let bundleIdentifier: String
    public let leftovers: [AppLeftover]
    public var bytes: Int64 { leftovers.reduce(0) { $0 + $1.bytes } }
}

/// Finds apps sitting in the home folder's Trash whose leftovers are still in the Library. An app
/// still installed elsewhere under the same identifier is skipped: its files are in use.
public struct TrashedAppFinder: Sendable {
    private let home: URL
    private let isInstalledElsewhere: @Sendable (String) -> Bool

    public init(home: URL, isInstalledElsewhere: @escaping @Sendable (String) -> Bool) {
        self.home = home.standardizedFileURL
        self.isInstalledElsewhere = isInstalledElsewhere
    }

    public var trash: URL { home.appendingPathComponent(".Trash", isDirectory: true) }

    public func find() -> [TrashedApp] {
        let finder = AppLeftoverFinder(home: home)
        var found: [TrashedApp] = []
        var seen = Set<String>()
        for bundle in appBundles() {
            guard let info = NSDictionary(contentsOf: bundle.appendingPathComponent("Contents/Info.plist")) as? [String: Any],
                  let id = info["CFBundleIdentifier"] as? String, AppLeftoverFinder.offersLeftovers(for: id),
                  seen.insert(id).inserted, !isInstalledElsewhere(id) else { continue }
            let name = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String)
                ?? bundle.deletingPathExtension().lastPathComponent
            let leftovers = finder.find(bundleIdentifier: id, displayName: name)
            guard !leftovers.isEmpty else { continue }
            found.append(TrashedApp(trashURL: bundle, name: name, bundleIdentifier: id, leftovers: leftovers))
        }
        return found.sorted { $0.bytes > $1.bytes }
    }

    /// `.app` bundles directly in the Trash, or one folder down (a folder dragged with its app).
    private func appBundles() -> [URL] {
        let manager = FileManager.default
        guard let top = try? manager.contentsOfDirectory(at: trash, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return [] }
        var bundles: [URL] = []
        for entry in top where !Self.isLink(entry) {
            if entry.pathExtension == "app" { bundles.append(entry); continue }
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let inner = try? manager.contentsOfDirectory(at: entry, includingPropertiesForKeys: [.isSymbolicLinkKey]) else { continue }
            bundles += inner.filter { $0.pathExtension == "app" && !Self.isLink($0) }
        }
        return bundles
    }

    private static func isLink(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) != 0 || (info.st_mode & S_IFMT) == S_IFLNK
    }
}

/// What CoreTend may tell the person on its own, once they turned alerts on. Each one is a fact
/// measured on this Mac, with the threshold it crossed; nothing is scored or guessed.
public enum CareAlert: String, CaseIterable, Sendable {
    case lowDiskSpace, heavyTrash, trashedAppLeftovers
}

public struct CareAlertReading: Sendable, Equatable {
    public var freeBytes: Int64?
    public var totalBytes: Int64?
    public var trashBytes: Int64?
    public var trashedAppsWithLeftovers: Int

    public init(freeBytes: Int64?, totalBytes: Int64?, trashBytes: Int64?, trashedAppsWithLeftovers: Int) {
        self.freeBytes = freeBytes; self.totalBytes = totalBytes
        self.trashBytes = trashBytes; self.trashedAppsWithLeftovers = trashedAppsWithLeftovers
    }
}

public struct CareAlertPolicy: Sendable {
    /// Free space under this share of the volume, and under `lowDiskFloor`, is "almost full".
    public var lowDiskFraction = 0.10
    public var lowDiskFloor: Int64 = 20_000_000_000
    public var heavyTrash: Int64 = 5_000_000_000
    /// The same subject is never repeated within this interval.
    public var quietInterval: TimeInterval = 24 * 60 * 60

    public init() {}

    /// The alerts whose condition holds now and that were not shown in the quiet interval.
    public func due(_ reading: CareAlertReading, lastShown: [CareAlert: Date], now: Date) -> [CareAlert] {
        CareAlert.allCases.filter { alert in
            guard holds(alert, reading) else { return false }
            guard let last = lastShown[alert] else { return true }
            return now.timeIntervalSince(last) >= quietInterval
        }
    }

    public func holds(_ alert: CareAlert, _ reading: CareAlertReading) -> Bool {
        switch alert {
        case .lowDiskSpace:
            guard let free = reading.freeBytes, let total = reading.totalBytes, total > 0 else { return false }
            return free < lowDiskFloor && Double(free) / Double(total) < lowDiskFraction
        case .heavyTrash:
            guard let bytes = reading.trashBytes else { return false }
            return bytes >= heavyTrash
        case .trashedAppLeftovers:
            return reading.trashedAppsWithLeftovers > 0
        }
    }
}

public enum TrashMeasure {
    /// Allocated bytes in the home folder's Trash, or nil when macOS does not let CoreTend read it.
    public static func bytes(home: URL) -> Int64? {
        let trash = home.appendingPathComponent(".Trash", isDirectory: true)
        guard (try? FileManager.default.contentsOfDirectory(atPath: trash.path)) != nil else { return nil }
        return AppLeftoverFinder.allocatedBytes(trash)
    }
}
