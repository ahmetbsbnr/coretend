import Foundation

/// One release an app's Sparkle feed announces.
public struct AppcastItem: Sendable, Equatable {
    public let version: String?
    public let shortVersion: String?
    public let minimumSystemVersion: String?
}

/// What a check found for one app. Only ever the result of a request the person started.
public enum AppUpdateResult: Sendable, Equatable {
    case available(version: String)
    case upToDate
    case unavailable(reason: String)
}

/// Reads a Sparkle appcast (RSS with the `sparkle:` namespace). Only versions are read; nothing in
/// the feed is followed, downloaded or run.
public enum AppcastReader {
    public static func items(from data: Data) -> [AppcastItem] {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }

    /// The newest release that runs on `system` and is newer than the installed build. Sparkle
    /// orders releases by `sparkle:version` (the bundle version), falling back to the short version.
    public static func newer(than installedBuild: String?, installedShort: String?, in items: [AppcastItem],
                             system: OperatingSystemVersion) -> AppcastItem? {
        let installed = installedBuild ?? installedShort
        guard let installed else { return nil }
        let candidates = items.filter { item in
            guard let key = item.version ?? item.shortVersion else { return false }
            if let minimum = item.minimumSystemVersion, VersionOrder.compare(minimum, systemString(system)) == .orderedDescending { return false }
            return VersionOrder.compare(key, installed) == .orderedDescending
        }
        return candidates.max { VersionOrder.compare($0.version ?? $0.shortVersion ?? "", $1.version ?? $1.shortVersion ?? "") == .orderedAscending }
    }

    static func systemString(_ version: OperatingSystemVersion) -> String {
        "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var items: [AppcastItem] = []
        private var inItem = false
        private var text = ""
        private var version: String?, shortVersion: String?, minimum: String?

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            text = ""
            if name == "item" { inItem = true; version = nil; shortVersion = nil; minimum = nil }
            guard inItem, name == "enclosure" else { return }
            version = version ?? attributes["sparkle:version"]
            shortVersion = shortVersion ?? attributes["sparkle:shortVersionString"]
            minimum = minimum ?? attributes["sparkle:minimumSystemVersion"]
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard inItem else { return }
            switch name {
            case "sparkle:version": if !value.isEmpty { version = value }
            case "sparkle:shortVersionString": if !value.isEmpty { shortVersion = value }
            case "sparkle:minimumSystemVersion": if !value.isEmpty { minimum = value }
            case "item":
                inItem = false
                if version != nil || shortVersion != nil {
                    items.append(AppcastItem(version: version, shortVersion: shortVersion, minimumSystemVersion: minimum))
                }
            default: break
            }
        }
    }
}

/// Dotted version order ("1.10" after "1.9"); non-numeric parts compare as text.
public enum VersionOrder {
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map(String.init), right = rhs.split(separator: ".").map(String.init)
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : "0", b = index < right.count ? right[index] : "0"
            if let x = Int(a), let y = Int(b) {
                if x != y { return x < y ? .orderedAscending : .orderedDescending }
            } else {
                let order = a.compare(b, options: .numeric)
                if order != .orderedSame { return order }
            }
        }
        return .orderedSame
    }
}

/// Checks each app's declared HTTPS Sparkle feed, a few at a time, through `fetch`. Started only
/// by the person (decision 0007); never in the background.
public struct AppUpdateCheck: Sendable {
    public typealias Fetch = @Sendable (URL) async throws -> Data
    private let fetch: Fetch
    private let system: OperatingSystemVersion

    public init(fetch: @escaping Fetch, system: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) {
        self.fetch = fetch
        self.system = system
    }

    public func check(_ apps: [ApplicationRecord], concurrency: Int = 6) async -> [String: AppUpdateResult] {
        let feeds: [(ApplicationRecord, URL)] = apps.compactMap { app in
            if case .declaredHTTPSFeed(let url) = app.updateSource { return (app, url) }
            return nil
        }
        var results: [String: AppUpdateResult] = [:]
        var index = 0
        await withTaskGroup(of: (String, AppUpdateResult).self) { group in
            func addNext() {
                guard index < feeds.count else { return }
                let (app, url) = feeds[index]; index += 1
                group.addTask { (app.id, await one(app, url)) }
            }
            for _ in 0..<min(concurrency, feeds.count) { addNext() }
            for await (id, result) in group { results[id] = result; addNext() }
        }
        return results
    }

    private func one(_ app: ApplicationRecord, _ url: URL) async -> AppUpdateResult {
        let info = NSDictionary(contentsOf: app.url.appendingPathComponent("Contents/Info.plist")) as? [String: Any] ?? [:]
        let build = info["CFBundleVersion"] as? String, short = info["CFBundleShortVersionString"] as? String ?? app.version
        guard let data = try? await fetch(url) else { return .unavailable(reason: "feed_unreachable") }
        let items = AppcastReader.items(from: data)
        guard !items.isEmpty else { return .unavailable(reason: "feed_unreadable") }
        if let newer = AppcastReader.newer(than: build, installedShort: short, in: items, system: system) {
            return .available(version: newer.shortVersion ?? newer.version ?? "?")
        }
        return .upToDate
    }
}
