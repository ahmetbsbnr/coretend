import Foundation
import ScanCore

/// One detected browser profile and the *sizes* of its data. Only `cacheURLs`
/// is ever acted on (moved to Trash) — history/cookie bytes are reported for
/// transparency, never deleted (see Step 4 / PRIVACY_CLEANER docs: live-SQLite
/// deletion stays DEFERRED until a proven closed-browser+backup+restore path).
struct BrowserProfile: Identifiable, Sendable {
    let id: String
    let browser: String
    let bundleID: String
    let profileName: String
    let cacheURLs: [URL]
    let cacheBytes: Int64
    let historyBytes: Int64
    let cookieBytes: Int64
}

/// Real, non-fuzzy browser profile detection driven by a static catalog of the
/// well-known on-disk layouts. Chromium-family browsers all share the
/// "Default"/"Profile N" support-dir layout with a mirrored cache dir; Firefox
/// keeps one dir per profile; Safari is single-profile behind Full Disk Access.
/// Pure and filesystem-parameterized (`detect(home:)`) so it can be tested
/// against a fixture directory tree without touching the real home folder.
enum BrowserCatalog {
    enum Layout { case chromium, firefox, safari }

    struct Definition {
        let browser: String
        let bundleID: String
        let layout: Layout
        let supportSubpath: String   // relative to home
        let cacheSubpath: String     // relative to home
    }

    /// Only browsers whose layout we can read *without guessing* are listed.
    /// Opera/Arc use non-standard profile layouts — deliberately omitted rather
    /// than fuzzily matched.
    static let definitions: [Definition] = [
        .init(browser: "Google Chrome", bundleID: "com.google.Chrome", layout: .chromium,
              supportSubpath: "Library/Application Support/Google/Chrome",
              cacheSubpath: "Library/Caches/Google/Chrome"),
        .init(browser: "Microsoft Edge", bundleID: "com.microsoft.edgemac", layout: .chromium,
              supportSubpath: "Library/Application Support/Microsoft Edge",
              cacheSubpath: "Library/Caches/Microsoft Edge"),
        .init(browser: "Brave", bundleID: "com.brave.Browser", layout: .chromium,
              supportSubpath: "Library/Application Support/BraveSoftware/Brave-Browser",
              cacheSubpath: "Library/Caches/BraveSoftware/Brave-Browser"),
        .init(browser: "Vivaldi", bundleID: "com.vivaldi.Vivaldi", layout: .chromium,
              supportSubpath: "Library/Application Support/Vivaldi",
              cacheSubpath: "Library/Caches/Vivaldi"),
        .init(browser: "Chromium", bundleID: "org.chromium.Chromium", layout: .chromium,
              supportSubpath: "Library/Application Support/Chromium",
              cacheSubpath: "Library/Caches/Chromium"),
        .init(browser: "Firefox", bundleID: "org.mozilla.firefox", layout: .firefox,
              supportSubpath: "Library/Application Support/Firefox/Profiles",
              cacheSubpath: "Library/Caches/Firefox/Profiles"),
        .init(browser: "Safari", bundleID: "com.apple.Safari", layout: .safari,
              supportSubpath: "Library/Safari",
              cacheSubpath: "Library/Caches/com.apple.Safari"),
    ]

    static func detect(home: URL, fileManager fm: FileManager = .default) -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []
        for def in definitions {
            let support = home.appendingPathComponent(def.supportSubpath)
            let cacheRoot = home.appendingPathComponent(def.cacheSubpath)
            switch def.layout {
            case .chromium:
                guard fm.fileExists(atPath: support.path) else { continue }
                let entries = (try? fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil)) ?? []
                for entry in entries where entry.lastPathComponent == "Default"
                    || entry.lastPathComponent.hasPrefix("Profile ") {
                    let name = entry.lastPathComponent
                    let cacheDir = cacheRoot.appendingPathComponent(name)
                    let cookies = size(entry.appendingPathComponent("Cookies"), fm)
                    profiles.append(BrowserProfile(
                        id: "\(def.bundleID)-\(name)", browser: def.browser, bundleID: def.bundleID,
                        profileName: name,
                        cacheURLs: [cacheDir].filter { fm.fileExists(atPath: $0.path) },
                        cacheBytes: size(cacheDir, fm),
                        historyBytes: size(entry.appendingPathComponent("History"), fm),
                        cookieBytes: cookies > 0 ? cookies
                            : size(entry.appendingPathComponent("Network/Cookies"), fm)))
                }
            case .firefox:
                guard fm.fileExists(atPath: support.path) else { continue }
                let entries = (try? fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil)) ?? []
                for entry in entries {
                    let name = entry.lastPathComponent
                    let cacheDir = cacheRoot.appendingPathComponent(name)
                    profiles.append(BrowserProfile(
                        id: "\(def.bundleID)-\(name)", browser: def.browser, bundleID: def.bundleID,
                        profileName: name,
                        cacheURLs: [cacheDir].filter { fm.fileExists(atPath: $0.path) },
                        cacheBytes: size(cacheDir, fm),
                        historyBytes: size(entry.appendingPathComponent("places.sqlite"), fm),
                        cookieBytes: size(entry.appendingPathComponent("cookies.sqlite"), fm)))
                }
            case .safari:
                guard fm.fileExists(atPath: cacheRoot.path) else { continue }
                profiles.append(BrowserProfile(
                    id: def.bundleID, browser: def.browser, bundleID: def.bundleID,
                    profileName: "Default",
                    cacheURLs: [cacheRoot],
                    cacheBytes: size(cacheRoot, fm),
                    historyBytes: size(home.appendingPathComponent("Library/Safari/History.db"), fm),
                    cookieBytes: 0))
            }
        }
        return profiles.sorted { $0.cacheBytes > $1.cacheBytes }
    }

    static func detect(home: URL, fileManager fm: FileManager = .default,
                       pauseController: ScanPauseController?) async -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []
        for def in definitions {
            if Task.isCancelled { break }
            await pauseController?.waitIfPaused()
            let support = home.appendingPathComponent(def.supportSubpath)
            let cacheRoot = home.appendingPathComponent(def.cacheSubpath)
            switch def.layout {
            case .chromium:
                guard fm.fileExists(atPath: support.path) else { continue }
                let entries = (try? fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil)) ?? []
                for entry in entries where entry.lastPathComponent == "Default"
                    || entry.lastPathComponent.hasPrefix("Profile ") {
                    if Task.isCancelled { break }
                    await pauseController?.waitIfPaused()
                    let name = entry.lastPathComponent
                    let cacheDir = cacheRoot.appendingPathComponent(name)
                    let cookies = await size(entry.appendingPathComponent("Cookies"), fm, pauseController: pauseController)
                    profiles.append(BrowserProfile(
                        id: "\(def.bundleID)-\(name)", browser: def.browser, bundleID: def.bundleID,
                        profileName: name,
                        cacheURLs: [cacheDir].filter { fm.fileExists(atPath: $0.path) },
                        cacheBytes: await size(cacheDir, fm, pauseController: pauseController),
                        historyBytes: await size(entry.appendingPathComponent("History"), fm, pauseController: pauseController),
                        cookieBytes: cookies > 0 ? cookies
                            : await size(entry.appendingPathComponent("Network/Cookies"), fm, pauseController: pauseController)))
                }
            case .firefox:
                guard fm.fileExists(atPath: support.path) else { continue }
                let entries = (try? fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil)) ?? []
                for entry in entries {
                    if Task.isCancelled { break }
                    await pauseController?.waitIfPaused()
                    let name = entry.lastPathComponent
                    let cacheDir = cacheRoot.appendingPathComponent(name)
                    profiles.append(BrowserProfile(
                        id: "\(def.bundleID)-\(name)", browser: def.browser, bundleID: def.bundleID,
                        profileName: name,
                        cacheURLs: [cacheDir].filter { fm.fileExists(atPath: $0.path) },
                        cacheBytes: await size(cacheDir, fm, pauseController: pauseController),
                        historyBytes: await size(entry.appendingPathComponent("places.sqlite"), fm, pauseController: pauseController),
                        cookieBytes: await size(entry.appendingPathComponent("cookies.sqlite"), fm, pauseController: pauseController)))
                }
            case .safari:
                guard fm.fileExists(atPath: cacheRoot.path) else { continue }
                profiles.append(BrowserProfile(
                    id: def.bundleID, browser: def.browser, bundleID: def.bundleID,
                    profileName: "Default",
                    cacheURLs: [cacheRoot],
                    cacheBytes: await size(cacheRoot, fm, pauseController: pauseController),
                    historyBytes: await size(home.appendingPathComponent("Library/Safari/History.db"), fm, pauseController: pauseController),
                    cookieBytes: 0))
            }
        }
        return profiles.sorted { $0.cacheBytes > $1.cacheBytes }
    }

    /// Logical byte size of a file or directory tree; 0 if missing.
    static func size(_ url: URL, _ fm: FileManager) -> Int64 {
        guard fm.fileExists(atPath: url.path) else { return 0 }
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
           values.isDirectory != true { return Int64(values.fileSize ?? 0) }
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let item as URL in enumerator {
            total += Int64((try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }

    static func size(_ url: URL, _ fm: FileManager, pauseController: ScanPauseController?) async -> Int64 {
        guard fm.fileExists(atPath: url.path) else { return 0 }
        await pauseController?.waitIfPaused()
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
           values.isDirectory != true { return Int64(values.fileSize ?? 0) }
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        while let item = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            await pauseController?.waitIfPaused()
            total += Int64((try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }
}
