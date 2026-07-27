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
            .appendingPathComponent("coretend-app-\(UUID().uuidString)")
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
            .appendingPathComponent("coretend-home-\(UUID().uuidString)")
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
            .appendingPathComponent("coretend-mas-\(UUID().uuidString)")
        let bundle = root.appendingPathComponent("Fake.app")
        try FileManager.default.createDirectory(
            at: bundle.appendingPathComponent("Contents/_MASReceipt"), withIntermediateDirectories: true)
        try Data([0]).write(to: bundle.appendingPathComponent("Contents/_MASReceipt/receipt"))
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(AppDiscovery().updateMechanism(for: bundle) == .appStore)
    }

    // MARK: - Homebrew Cask origin (Step 5, non-fuzzy)

    @Test func caskArtifactParsingExactAppNameNotFuzzy() {
        let artifacts: [[String: Any]] = [
            ["uninstall": [["quit": "com.x.y"]]],
            ["app": ["AlDente.app"]],
            ["zap": [["trash": ["~/Library/Caches/com.x.y"]]]],
        ]
        #expect(HomebrewCaskIndex.appArtifactNames(fromArtifacts: artifacts) == ["AlDente.app"])
    }

    @Test func caskArtifactRenameTargetIsTheInstalledName() {
        let artifacts: [[String: Any]] = [
            ["app": ["Source.app", ["target": "Installed.app"]]],
        ]
        #expect(HomebrewCaskIndex.appArtifactNames(fromArtifacts: artifacts) == ["Installed.app"])
    }

    @Test func caskArtifactNonAppEntriesIgnored() {
        let artifacts: [[String: Any]] = [["binary": ["foo"]], ["pkg": ["bar.pkg"]]]
        #expect(HomebrewCaskIndex.appArtifactNames(fromArtifacts: artifacts).isEmpty)
    }

    @Test func caskIndexClassificationOutranksSparkleAndManual() {
        let index = HomebrewCaskIndex(appNameToToken: ["Widget.app": "widget"])
        // Even with a Sparkle feed + download origin present, a cask token wins.
        let source = AppDiscovery.classify(
            hasMASReceipt: false, plist: ["SUFeedURL": "https://x.example/a.xml"],
            hasSparkleFramework: true, whereFroms: "https://d.example/w.dmg",
            caskToken: index.token(forAppNamed: "Widget.app"))
        #expect(source == .homebrewCask(token: "widget"))
    }

    @Test func appStoreStillOutranksCask() {
        let source = AppDiscovery.classify(
            hasMASReceipt: true, plist: [:], hasSparkleFramework: false,
            whereFroms: nil, caskToken: "widget")
        #expect(source == .appStore)
    }

    @Test func caskIndexBuildsFromFixtureCaskroomTree() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("caskroom-\(UUID())")
        let jsonDir = root.appendingPathComponent("aldente/.metadata/1.0/20260101000000.000/Casks")
        try fm.createDirectory(at: jsonDir, withIntermediateDirectories: true)
        // also a stray version dir under the app bundle that must be ignored.
        try fm.createDirectory(at: root.appendingPathComponent("aldente/1.0/AlDente.app"),
                               withIntermediateDirectories: true)
        let json = #"{"artifacts":[{"app":["AlDente.app"]}]}"#
        try json.write(to: jsonDir.appendingPathComponent("aldente.json"), atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: root) }

        let index = HomebrewCaskIndex.build(roots: [root.path])
        #expect(index.token(forAppNamed: "AlDente.app") == "aldente")
        #expect(index.token(forAppNamed: "Other.app") == nil)
    }

    @Test func caskIndexEmptyWhenNoCaskroom() {
        let index = HomebrewCaskIndex.build(roots: ["/nonexistent-caskroom-\(UUID().uuidString)"])
        #expect(index.isEmpty)
    }

    @Test func caskActionLabelDoesNotOverpromise() {
        #expect(UpdateMechanism.homebrewCask(token: "x").actionLabel == "Managed by Homebrew")
    }
}
