import Testing
import Foundation
@testable import AppDiscovery

@Suite("AppDiscovery")
struct AppDiscoveryTests {
    @Test func bundleIDHeuristic() {
        #expect(AppDiscovery.looksLikeBundleID("com.example.app"))
        #expect(AppDiscovery.looksLikeBundleID("org.mozilla.firefox"))
        #expect(!AppDiscovery.looksLikeBundleID("Documents"))
        #expect(!AppDiscovery.looksLikeBundleID("com.apple"))
        #expect(!AppDiscovery.looksLikeBundleID("a..b.c"))
    }

    @Test func inspectReadsFakeBundle() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-app-\(UUID().uuidString)")
        let bundle = root.appendingPathComponent("Fake.app")
        try FileManager.default.createDirectory(
            at: bundle.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.test.fake",
            "CFBundleName": "Fake",
            "CFBundleShortVersionString": "2.1",
            "CFBundleExecutable": "Fake",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: bundle.appendingPathComponent("Contents/Info.plist"))

        let app = AppDiscovery().inspect(bundle: bundle)
        #expect(app?.name == "Fake")
        #expect(app?.bundleIdentifier == "com.test.fake")
        #expect(app?.version == "2.1")
    }

    @Test func leftoversExcludeAppleAndInstalled() throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-home-\(UUID().uuidString)")
        let appSupport = home.appendingPathComponent("Library/Application Support")
        try FileManager.default.createDirectory(
            at: appSupport.appendingPathComponent("com.gone.app"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: appSupport.appendingPathComponent("com.apple.something"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: appSupport.appendingPathComponent("com.installed.app"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: appSupport.appendingPathComponent("PlainFolderName"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let leftovers = AppDiscovery(home: home).leftovers(installedBundleIDs: ["com.installed.app"])
        let names = leftovers.map { $0.url.lastPathComponent }
        #expect(names == ["com.gone.app"])
    }
}
