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

    // MARK: - Update source detection (Step 5)

    @Test func appStoreReceiptWinsOverEverything() {
        let source = AppDiscovery.classify(
            hasMASReceipt: true,
            plist: ["SUFeedURL": "https://example.com/appcast.xml"],
            hasSparkleFramework: true,
            whereFroms: "https://download.example.com/App.dmg")
        #expect(source == .appStore)
    }

    @Test func sparkleWithSafeFeed() {
        let source = AppDiscovery.classify(
            hasMASReceipt: false,
            plist: ["SUFeedURL": "https://example.com/appcast.xml"],
            hasSparkleFramework: true, whereFroms: nil)
        #expect(source == .sparkle(feedURL: URL(string: "https://example.com/appcast.xml")))
    }

    @Test func sparkleWithDangerousFeedYieldsNoURL() {
        for dangerous in ["http://insecure.example.com/appcast.xml",
                          "file:///etc/passwd",
                          "javascript:alert(1)",
                          "not a url at all",
                          "https:///no-host"] {
            let source = AppDiscovery.classify(
                hasMASReceipt: false, plist: ["SUFeedURL": dangerous],
                hasSparkleFramework: true, whereFroms: nil)
            #expect(source == .sparkle(feedURL: nil), "\(dangerous) must be rejected")
        }
    }

    @Test func sparkleFrameworkWithoutFeed() {
        let source = AppDiscovery.classify(
            hasMASReceipt: false, plist: [:], hasSparkleFramework: true, whereFroms: nil)
        #expect(source == .sparkle(feedURL: nil))
    }

    @Test func manualFromWhereFroms() {
        let source = AppDiscovery.classify(
            hasMASReceipt: false, plist: [:], hasSparkleFramework: false,
            whereFroms: "https://download.example.com/App.dmg")
        #expect(source == .manual(source: "https://download.example.com/App.dmg"))
    }

    @Test func unknownWhenNoSignals() {
        let source = AppDiscovery.classify(
            hasMASReceipt: false, plist: [:], hasSparkleFramework: false, whereFroms: nil)
        #expect(source == .unknown)
    }

    @Test func unknownWhenWhereFromsUnsafe() {
        let source = AppDiscovery.classify(
            hasMASReceipt: false, plist: [:], hasSparkleFramework: false,
            whereFroms: "http://insecure.example.com/App.dmg")
        #expect(source == .unknown)
    }

    @Test func labelsNeverOverpromise() {
        #expect(UpdateMechanism.sparkle(feedURL: nil).actionLabel == "Update Options Unavailable")
        #expect(UpdateMechanism.unknown.actionLabel == "Update Mechanism Unavailable")
        #expect(!UpdateMechanism.sparkle(feedURL: URL(string: "https://x.example/y")).actionLabel.contains("Available"))
    }

    @Test func updateSourceReadsRealReceiptBundle() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maccare-mas-\(UUID().uuidString)")
        let bundle = root.appendingPathComponent("Fake.app")
        try FileManager.default.createDirectory(
            at: bundle.appendingPathComponent("Contents/_MASReceipt"), withIntermediateDirectories: true)
        try Data([0]).write(to: bundle.appendingPathComponent("Contents/_MASReceipt/receipt"))
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(AppDiscovery().updateMechanism(for: bundle) == .appStore)
    }
}
