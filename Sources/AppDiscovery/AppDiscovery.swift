import Foundation
import CoreServices

/// Metadata for one installed application.
public struct InstalledApp: Sendable, Identifiable {
    public let id: String              // bundle path
    public let name: String
    public let bundleIdentifier: String?
    public let version: String?
    public let path: URL
    public let sizeBytes: Int64
    public let architectures: [String]
    /// Spotlight's `kMDItemLastUsedDate` for the bundle, when indexed. Real
    /// signal, not synthesized — `nil` means genuinely unknown (Spotlight
    /// disabled/not yet indexed), never guessed.
    public let lastUsedDate: Date?
    /// True when the bundle carries `com.apple.quarantine` (i.e. it arrived
    /// via a browser/mail download and passed Gatekeeper) — a real xattr,
    /// used as an honest provenance signal rather than a guess.
    public let isQuarantined: Bool

    public init(name: String, bundleIdentifier: String?, version: String?,
                path: URL, sizeBytes: Int64, architectures: [String],
                lastUsedDate: Date? = nil, isQuarantined: Bool = false) {
        self.id = path.path
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.path = path
        self.sizeBytes = sizeBytes
        self.architectures = architectures
        self.lastUsedDate = lastUsedDate
        self.isQuarantined = isQuarantined
    }
}

/// How an installed app can be updated, derived only from on-disk signals.
/// No network is ever touched; `.unknown` is returned honestly rather than
/// guessing a mechanism that may not exist.
public enum UpdateMechanism: Sendable, Equatable {
    /// Carries a Mac App Store receipt (`Contents/_MASReceipt/receipt`).
    case appStore
    /// Self-updates via Sparkle. `feedURL` is populated only when the app's
    /// `SUFeedURL` is a safe https URL; otherwise `nil` (framework present but
    /// no surfaced feed) — we never surface an unsafe or malformed feed.
    case sparkle(feedURL: URL?)
    /// Installed by Homebrew Cask. `token` is the exact cask token from the
    /// Caskroom metadata (non-fuzzy: matched by exact `.app` artifact name).
    case homebrewCask(token: String)
    /// A known download origin recorded by macOS (`kMDItemWhereFroms`).
    case manual(source: String)
    /// No reliable update mechanism could be determined on disk.
    case unknown

    /// Non-overpromising action label. We only ever offer to *show* options —
    /// we never claim an update "is available" because no version comparison
    /// or network check has happened.
    public var actionLabel: String {
        switch self {
        case .appStore: return "Open in App Store"
        case .homebrewCask: return "Managed by Homebrew"
        case .sparkle(let url): return url == nil ? "Update Options Unavailable" : "Show Update Options"
        case .manual: return "Show Download Source"
        case .unknown: return "Update Mechanism Unavailable"
        }
    }
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
        return InstalledApp(
            name: name,
            bundleIdentifier: plist["CFBundleIdentifier"] as? String,
            version: version,
            path: bundle,
            sizeBytes: Self.directorySize(bundle),
            architectures: Self.architectures(of: bundle, plist: plist),
            lastUsedDate: Self.lastUsedDate(of: bundle),
            isQuarantined: Self.isQuarantined(bundle))
    }

    /// Reads Spotlight's real "last used" attribute; `nil` if unindexed.
    static func lastUsedDate(of bundle: URL) -> Date? {
        guard let item = MDItemCreate(nil, bundle.path as CFString) else { return nil }
        guard let value = MDItemCopyAttribute(item, kMDItemLastUsedDate) else { return nil }
        return value as? Date
    }

    /// True when the bundle still carries the quarantine xattr set by
    /// browsers/mail on download.
    static func isQuarantined(_ bundle: URL) -> Bool {
        (try? bundle.resourceValues(forKeys: [.quarantinePropertiesKey]))?.quarantineProperties != nil
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

    /// Determines an app's update source from real on-disk signals only.
    /// Pass a prebuilt `caskIndex` (built once for the whole app list) to also
    /// detect Homebrew Cask origin.
    public func updateMechanism(for bundle: URL, caskIndex: HomebrewCaskIndex? = nil) -> UpdateMechanism {
        let fm = FileManager.default
        let hasReceipt = fm.fileExists(
            atPath: bundle.appendingPathComponent("Contents/_MASReceipt/receipt").path)
        let plistURL = bundle.appendingPathComponent("Contents/Info.plist")
        let plist = (try? Data(contentsOf: plistURL)).flatMap {
            try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any]
        } ?? [:]
        let hasSparkle = fm.fileExists(
            atPath: bundle.appendingPathComponent("Contents/Frameworks/Sparkle.framework").path)
        return Self.classify(hasMASReceipt: hasReceipt, plist: plist,
                             hasSparkleFramework: hasSparkle,
                             whereFroms: Self.whereFromsURL(of: bundle),
                             caskToken: caskIndex?.token(forAppNamed: bundle.lastPathComponent))
    }

    /// Pure classification core (no filesystem) — the unit-testable heart.
    static func classify(hasMASReceipt: Bool, plist: [String: Any],
                         hasSparkleFramework: Bool, whereFroms: String?,
                         caskToken: String? = nil) -> UpdateMechanism {
        if hasMASReceipt { return .appStore }
        // A cask is the canonical "how do I update this" answer (brew upgrade),
        // so it outranks Sparkle/manual origin signals.
        if let caskToken { return .homebrewCask(token: caskToken) }
        if let feed = plist["SUFeedURL"] as? String {
            return .sparkle(feedURL: safeFeedURL(feed))
        }
        if hasSparkleFramework { return .sparkle(feedURL: nil) }
        if let source = whereFroms, safeFeedURL(source) != nil { return .manual(source: source) }
        return .unknown
    }

    /// Accepts only well-formed https URLs with a host. Rejects http, file,
    /// javascript, and any other scheme as unsafe/untrustworthy → `nil`.
    static func safeFeedURL(_ string: String) -> URL? {
        guard let url = URL(string: string),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// Reads macOS's real download-origin attribute via Spotlight; `nil` if absent.
    static func whereFromsURL(of bundle: URL) -> String? {
        guard let item = MDItemCreate(nil, bundle.path as CFString),
              let value = MDItemCopyAttribute(item, kMDItemWhereFroms),
              let list = value as? [String] else { return nil }
        return list.first { safeFeedURL($0) != nil }
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

/// Maps installed `.app` bundle names to their Homebrew Cask token by reading
/// the Caskroom install metadata — a concrete, non-fuzzy signal. Homebrew writes
/// `<Caskroom>/<token>/.metadata/<version>/<ts>/Casks/<token>.json`, whose
/// `artifacts` array carries an exact `{"app": ["Name.app"]}` stanza. We match
/// only on that exact bundle name (including a rename `target`), never by fuzzy
/// string similarity. No network, no shelling out to `brew`.
public struct HomebrewCaskIndex: Sendable {
    private let appNameToToken: [String: String]

    public init(appNameToToken: [String: String]) { self.appNameToToken = appNameToToken }

    public var isEmpty: Bool { appNameToToken.isEmpty }

    /// `name` is a bundle name like "AlDente.app".
    public func token(forAppNamed name: String) -> String? { appNameToToken[name] }

    public static let caskroomRoots = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]

    /// Scans the real Caskroom(s). Returns an empty index if Homebrew Cask isn't
    /// installed — the caller then simply gets no cask origins, never a guess.
    public static func build(roots: [String] = caskroomRoots,
                             fileManager fm: FileManager = .default) -> HomebrewCaskIndex {
        var map: [String: String] = [:]
        for root in roots {
            let rootURL = URL(fileURLWithPath: root)
            guard let casks = try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil) else { continue }
            for caskDir in casks where caskDir.hasDirectoryPath {
                let metadata = caskDir.appendingPathComponent(".metadata")
                guard let jsonURLs = caskJSONURLs(under: metadata, fm: fm) else { continue }
                let token = caskDir.lastPathComponent
                for jsonURL in jsonURLs {
                    for appName in appArtifactNames(inCaskJSONAt: jsonURL) {
                        map[appName] = token
                    }
                }
            }
        }
        return HomebrewCaskIndex(appNameToToken: map)
    }

    /// All `Casks/*.json` files under a cask's `.metadata` tree.
    static func caskJSONURLs(under metadata: URL, fm: FileManager) -> [URL]? {
        guard let enumerator = fm.enumerator(at: metadata, includingPropertiesForKeys: nil) else { return nil }
        var result: [URL] = []
        for case let url as URL in enumerator
        where url.pathExtension == "json" && url.deletingLastPathComponent().lastPathComponent == "Casks" {
            result.append(url)
        }
        return result.isEmpty ? nil : result
    }

    /// Extracts the exact `.app` names from a cask JSON's `artifacts` array.
    /// Handles both `{"app": ["Name.app"]}` and a rename form
    /// `{"app": ["Src.app", {"target": "Installed.app"}]}` — the installed name
    /// is the `target` when present, otherwise the source string.
    static func appArtifactNames(inCaskJSONAt url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let artifacts = root["artifacts"] as? [[String: Any]] else { return [] }
        return appArtifactNames(fromArtifacts: artifacts)
    }

    /// Pure parser split out for testing without touching disk.
    static func appArtifactNames(fromArtifacts artifacts: [[String: Any]]) -> [String] {
        var names: [String] = []
        for artifact in artifacts {
            guard let appEntries = artifact["app"] as? [Any] else { continue }
            var pendingSource: String?
            for entry in appEntries {
                if let source = entry as? String {
                    if let pendingSource { names.append(pendingSource) }
                    pendingSource = source
                } else if let dict = entry as? [String: Any], let target = dict["target"] as? String {
                    // rename: the target is what actually lands in /Applications.
                    names.append(target)
                    pendingSource = nil
                }
            }
            if let pendingSource { names.append(pendingSource) }
        }
        return names.filter { $0.hasSuffix(".app") }
    }
}
