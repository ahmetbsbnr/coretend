import Foundation

/// Metadata for one installed application.
public struct InstalledApp: Sendable, Identifiable {
    public let id: String              // bundle path
    public let name: String
    public let bundleIdentifier: String?
    public let version: String?
    public let path: URL
    public let sizeBytes: Int64
    public let architectures: [String]
    public let lastUsedDate: Date?

    public init(name: String, bundleIdentifier: String?, version: String?,
                path: URL, sizeBytes: Int64, architectures: [String], lastUsedDate: Date? = nil) {
        self.id = path.path
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.path = path
        self.sizeBytes = sizeBytes
        self.architectures = architectures
        self.lastUsedDate = lastUsedDate
    }

    /// Best-effort publisher label derived from the bundle identifier's second
    /// component (e.g. "com.apple.Safari" → "Apple"). Real signal, not a guess
    /// beyond what the identifier itself encodes.
    public var publisher: String {
        guard let bundleIdentifier, let part = bundleIdentifier.split(separator: ".").dropFirst().first,
              !part.isEmpty else { return "Unknown" }
        return part.prefix(1).uppercased() + part.dropFirst()
    }

    /// True when the app has no bundle identifier, meaning MacCare cannot do
    /// exact-match lookup of its Application Support/Caches/Containers data —
    /// its data location is genuinely ambiguous, not merely unlabeled.
    public var isDataLocationAmbiguous: Bool { bundleIdentifier == nil }
}

/// A file or directory associated with an app (caches, prefs, containers…).
public struct AssociatedItem: Sendable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case applicationSupport = "Application Support"
        case caches = "Caches"
        case preferences = "Preferences"
        case logs = "Logs"
        case savedState = "Saved Application State"
        case containers = "Containers"
    }

    public let id: String
    public let kind: Kind
    public let url: URL
    public let sizeBytes: Int64

    public init(kind: Kind, url: URL, sizeBytes: Int64) {
        self.id = url.path
        self.kind = kind
        self.url = url
        self.sizeBytes = sizeBytes
    }
}

/// Discovers installed applications and their associated files.
/// Discovery is read-only; deletion goes through SafetyCore elsewhere.
public struct AppDiscovery: Sendable {
    public let home: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    public var applicationRoots: [URL] {
        [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
    }

    /// Enumerates .app bundles (top level + one subdirectory level for suites).
    public func discoverApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fm = FileManager.default
        for root in applicationRoots {
            guard let entries = try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            for entry in entries {
                if entry.pathExtension == "app" {
                    if let app = inspect(bundle: entry) { apps.append(app) }
                } else if (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    let nested = (try? fm.contentsOfDirectory(
                        at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                    for sub in nested where sub.pathExtension == "app" {
                        if let app = inspect(bundle: sub) { apps.append(app) }
                    }
                }
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func inspect(bundle: URL) -> InstalledApp? {
        let plistURL = bundle.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? bundle.deletingPathExtension().lastPathComponent
        let version = plist["CFBundleShortVersionString"] as? String ?? plist["CFBundleVersion"] as? String
        let lastUsed = try? bundle.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate
        return InstalledApp(
            name: name,
            bundleIdentifier: plist["CFBundleIdentifier"] as? String,
            version: version,
            path: bundle,
            sizeBytes: Self.directorySize(bundle),
            architectures: Self.architectures(of: bundle, plist: plist),
            lastUsedDate: lastUsed ?? nil)
    }

    /// Finds files associated with a bundle identifier using exact-id matching only.
    /// Exact matching keeps confidence high; fuzzy name matching is deliberately omitted.
    public func associatedItems(bundleID: String) -> [AssociatedItem] {
        var items: [AssociatedItem] = []
        let library = home.appendingPathComponent("Library")
        let fm = FileManager.default

        let candidates: [(AssociatedItem.Kind, URL)] = [
            (.applicationSupport, library.appendingPathComponent("Application Support/\(bundleID)")),
            (.caches, library.appendingPathComponent("Caches/\(bundleID)")),
            (.preferences, library.appendingPathComponent("Preferences/\(bundleID).plist")),
            (.logs, library.appendingPathComponent("Logs/\(bundleID)")),
            (.savedState, library.appendingPathComponent("Saved Application State/\(bundleID).savedState")),
            (.containers, library.appendingPathComponent("Containers/\(bundleID)")),
        ]
        for (kind, url) in candidates where fm.fileExists(atPath: url.path) {
            items.append(AssociatedItem(kind: kind, url: url, sizeBytes: Self.directorySize(url)))
        }
        return items
    }

    /// Leftover candidates: entries in Library locations whose reverse-DNS name
    /// matches no installed app. Only exact-format bundle-id names are considered.
    public func leftovers(installedBundleIDs: Set<String>) -> [AssociatedItem] {
        var results: [AssociatedItem] = []
        let library = home.appendingPathComponent("Library")
        let fm = FileManager.default
        let locations: [(AssociatedItem.Kind, URL)] = [
            (.applicationSupport, library.appendingPathComponent("Application Support")),
            (.caches, library.appendingPathComponent("Caches")),
            (.savedState, library.appendingPathComponent("Saved Application State")),
        ]
        // Apple's own domains are never leftovers.
        let protectedPrefixes = ["com.apple.", "group.com.apple."]
        for (kind, root) in locations {
            guard let entries = try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for entry in entries {
                var candidate = entry.lastPathComponent
                if kind == .savedState { candidate = candidate.replacingOccurrences(of: ".savedState", with: "") }
                guard Self.looksLikeBundleID(candidate),
                      !protectedPrefixes.contains(where: { candidate.hasPrefix($0) }),
                      !installedBundleIDs.contains(candidate)
                else { continue }
                results.append(AssociatedItem(kind: kind, url: entry, sizeBytes: Self.directorySize(entry)))
            }
        }
        return results.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    static func looksLikeBundleID(_ name: String) -> Bool {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } }
    }

    static func directorySize(_ url: URL) -> Int64 {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
           values.isDirectory != true {
            return Int64(values.fileSize ?? 0)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let item as URL in enumerator {
            guard let values = try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    static func architectures(of bundle: URL, plist: [String: Any]) -> [String] {
        let executableName = plist["CFBundleExecutable"] as? String
            ?? bundle.deletingPathExtension().lastPathComponent
        let executable = bundle.appendingPathComponent("Contents/MacOS/\(executableName)")
        guard let handle = try? FileHandle(forReadingFrom: executable),
              let header = try? handle.read(upToCount: 8) else { return [] }
        try? handle.close()
        guard header.count >= 8 else { return [] }
        let magic = header.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        switch magic {
        case 0xCAFEBABE, 0xBEBAFECA: return ["universal"]
        case 0xCFFAEDFE: // MH_MAGIC_64 little-endian on disk
            let cpu = UInt32(header[4]) | (UInt32(header[5]) << 8) | (UInt32(header[6]) << 16) | (UInt32(header[7]) << 24)
            return cpu == 0x0100000C ? ["arm64"] : cpu == 0x01000007 ? ["x86_64"] : ["unknown"]
        default: return []
        }
    }
}
