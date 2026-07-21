import Testing
import Foundation
import SafetyCore
@testable import MacCareApp

@Suite("Browser profile detection")
struct BrowserDetectionTests {
    private let fm = FileManager.default

    /// Builds a throwaway fake home directory tree the detector can walk.
    private func makeHome() throws -> URL {
        let home = fm.temporaryDirectory.appendingPathComponent("browserfx-\(UUID())")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    private func write(_ url: URL, bytes: Int) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0, count: bytes).write(to: url)
    }

    @Test func detectsChromiumFamilyEdgeAndBraveNotJustChrome() throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        // Chrome: Default + Profile 1
        try write(home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/History"), bytes: 10)
        try write(home.appendingPathComponent("Library/Application Support/Google/Chrome/Profile 1/History"), bytes: 10)
        try write(home.appendingPathComponent("Library/Caches/Google/Chrome/Default/cache.bin"), bytes: 5000)
        // Edge
        try write(home.appendingPathComponent("Library/Application Support/Microsoft Edge/Default/History"), bytes: 10)
        try write(home.appendingPathComponent("Library/Caches/Microsoft Edge/Default/cache.bin"), bytes: 2000)
        // Brave
        try write(home.appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser/Default/History"), bytes: 10)

        let profiles = BrowserCatalog.detect(home: home)
        let browsers = Set(profiles.map(\.browser))
        #expect(browsers.contains("Google Chrome"))
        #expect(browsers.contains("Microsoft Edge"))
        #expect(browsers.contains("Brave"))
        // Chrome contributes two profiles (Default + Profile 1).
        #expect(profiles.filter { $0.browser == "Google Chrome" }.count == 2)
    }

    @Test func onlyMirroredCacheDirIsActionableNeverHistoryFile() throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let hist = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/History")
        try write(hist, bytes: 999)
        try write(home.appendingPathComponent("Library/Caches/Google/Chrome/Default/cache.bin"), bytes: 4096)

        let chrome = try #require(BrowserCatalog.detect(home: home).first { $0.browser == "Google Chrome" })
        #expect(chrome.historyBytes == 999)
        // cacheURLs must point only at the Caches tree — never the History db.
        #expect(chrome.cacheURLs.allSatisfy { $0.path.contains("/Caches/") })
        #expect(chrome.cacheURLs.allSatisfy { !$0.path.contains("History") })
    }

    @Test func detectsFirefoxAndSafariLayouts() throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        try write(home.appendingPathComponent("Library/Application Support/Firefox/Profiles/abc.default/places.sqlite"), bytes: 20)
        try write(home.appendingPathComponent("Library/Caches/Firefox/Profiles/abc.default/cache.bin"), bytes: 100)
        try write(home.appendingPathComponent("Library/Caches/com.apple.Safari/cache.bin"), bytes: 300)

        let profiles = BrowserCatalog.detect(home: home)
        #expect(profiles.contains { $0.browser == "Firefox" && $0.cacheBytes == 100 })
        #expect(profiles.contains { $0.browser == "Safari" && $0.cacheBytes == 300 })
    }

    /// Enforcement gate: the same `Library/Caches`-scoped validator `cleanCaches`
    /// builds must accept every detected cacheURL and *reject* the profile's
    /// History/Cookies paths — so a live-DB path can never be trashed even if a
    /// future bug slipped one into `cacheURLs`.
    @Test func cacheOnlyValidatorAcceptsCachesRejectsHistoryAndCookies() throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let support = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default")
        try write(support.appendingPathComponent("History"), bytes: 500)
        try write(support.appendingPathComponent("Cookies"), bytes: 500)
        try write(home.appendingPathComponent("Library/Caches/Google/Chrome/Default/cache.bin"), bytes: 4096)

        let chrome = try #require(BrowserCatalog.detect(home: home).first { $0.browser == "Google Chrome" })
        let validator = PathValidator(allowedRoots: [home.appendingPathComponent("Library/Caches")])
        for url in chrome.cacheURLs {
            #expect((try? validator.validate(url)) != nil)
        }
        #expect((try? validator.validate(support.appendingPathComponent("History"))) == nil)
        #expect((try? validator.validate(support.appendingPathComponent("Cookies"))) == nil)
    }

    @Test func absentBrowsersProduceNoProfiles() throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        #expect(BrowserCatalog.detect(home: home).isEmpty)
    }

    @Test func sortedByCacheSizeDescending() throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        try write(home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/History"), bytes: 1)
        try write(home.appendingPathComponent("Library/Caches/Google/Chrome/Default/c.bin"), bytes: 100)
        try write(home.appendingPathComponent("Library/Caches/com.apple.Safari/c.bin"), bytes: 9000)

        let profiles = BrowserCatalog.detect(home: home)
        #expect(profiles.first?.browser == "Safari")
    }
}
