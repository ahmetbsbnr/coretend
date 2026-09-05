// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

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

    @Test func inspectMalformedInfoPlistYieldsNilNeverACrash() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-app-\(UUID().uuidString)")
        let bundle = root.appendingPathComponent("Broken.app")
        try FileManager.default.createDirectory(
            at: bundle.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        // Not a valid property list at all — garbage bytes.
        try Data([0x00, 0xFF, 0x13, 0x37, 0xDE, 0xAD]).write(to: bundle.appendingPathComponent("Contents/Info.plist"))

        #expect(AppDiscovery().inspect(bundle: bundle) == nil)
    }

    @Test func inspectMissingInfoPlistYieldsNil() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-app-\(UUID().uuidString)")
        let bundle = root.appendingPathComponent("Empty.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(AppDiscovery().inspect(bundle: bundle) == nil)
    }

    @Test func discoverAppsToleratesTwoBundlesSharingABundleIdentifier() throws {
        // A duplicate bundle identifier (e.g. a leftover copy in a second
        // Applications root) must not crash or silently drop one entry —
        // discovery reports both; de-duplication is a decision for a caller
        // that actually needs identity uniqueness, not for discovery itself.
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-dup-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["First.app", "Second.app"] {
            let bundle = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(
                at: bundle.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
            let plist: [String: Any] = ["CFBundleIdentifier": "com.acme.Duplicate", "CFBundleName": name]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: bundle.appendingPathComponent("Contents/Info.plist"))
        }
        let apps = AppDiscovery(applicationRoots: [root]).discoverApps()
        #expect(apps.count == 2)
        #expect(apps.allSatisfy { $0.bundleIdentifier == "com.acme.Duplicate" })
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

    @Test func associatedItemsIncludeReviewOnlyLaunchAgents() throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-home-\(UUID().uuidString)")
        let agents = home.appendingPathComponent("Library/LaunchAgents")
        let caches = home.appendingPathComponent("Library/Caches/com.example.Widget")
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: agents.appendingPathComponent("com.example.Widget.plist"))
        defer { try? FileManager.default.removeItem(at: home) }

        let app = InstalledApp(name: "Widget", bundleIdentifier: "com.example.Widget", version: nil,
                               path: URL(fileURLWithPath: "/Applications/Widget.app"),
                               sizeBytes: 10, architectures: ["arm64"])
        let items = AppDiscovery(home: home).associatedItems(for: app)

        #expect(items.contains { $0.kind == .caches })
        #expect(items.contains { $0.kind == .launchAgents && $0.url.lastPathComponent == "com.example.Widget.plist" })
    }

    @Test func legacyAssociatedItemsCallStaysUserLibraryOnly() throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-home-\(UUID().uuidString)")
        let agents = home.appendingPathComponent("Library/LaunchAgents")
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: agents.appendingPathComponent("com.example.Widget.plist"))
        defer { try? FileManager.default.removeItem(at: home) }

        let items = AppDiscovery(home: home).associatedItems(bundleID: "com.example.Widget")
        #expect(items.map(\.kind) == [.launchAgents])
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

    // MARK: - Installation source (distinct from update mechanism)

    @Test func installationSourceAppStoreWinsOverEverything() {
        #expect(AppDiscovery.classifyInstallationSource(
            hasMASReceipt: true, caskToken: "widget", whereFroms: "https://d.example/w.dmg") == .appStore)
    }

    @Test func installationSourceCaskOutranksWhereFroms() {
        #expect(AppDiscovery.classifyInstallationSource(
            hasMASReceipt: false, caskToken: "widget", whereFroms: "https://d.example/w.dmg")
            == .homebrewCask(token: "widget"))
    }

    @Test func installationSourceFromWhereFroms() {
        #expect(AppDiscovery.classifyInstallationSource(
            hasMASReceipt: false, caskToken: nil, whereFroms: "https://d.example/w.dmg")
            == .downloaded(source: "https://d.example/w.dmg"))
    }

    @Test func installationSourceUnsafeWhereFromsYieldsUnknown() {
        #expect(AppDiscovery.classifyInstallationSource(
            hasMASReceipt: false, caskToken: nil, whereFroms: "javascript:alert(1)") == .unknown)
    }

    /// Also documents that `classifyInstallationSource` has no Sparkle
    /// parameter at all: a Sparkle-only update signal must never leak into
    /// installation source (that would produce the exact "Installed via
    /// Sparkle" claim the product brief calls out as wrong — Sparkle answers
    /// only the update question).
    @Test func installationSourceUnknownWhenNoSignals() {
        #expect(AppDiscovery.classifyInstallationSource(hasMASReceipt: false, caskToken: nil, whereFroms: nil) == .unknown)
    }

    // MARK: - Vendor prefix (bundle id ↔ group container matching)

    @Test func vendorPrefixFromPlainBundleID() {
        #expect(AppDiscovery.vendorPrefix("com.acme.App") == "com.acme")
    }

    @Test func vendorPrefixStripsGroupPrefix() {
        #expect(AppDiscovery.vendorPrefix("group.com.acme.suite") == "com.acme")
    }

    @Test func vendorPrefixNilWhenTooShort() {
        #expect(AppDiscovery.vendorPrefix("acme") == nil)
        #expect(AppDiscovery.vendorPrefix("group.acme") == nil)
    }

    // MARK: - Group Containers (shared-storage-aware, heuristic, never exact)

    @Test func groupContainerMatchingInstalledVendorIsIncluded() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("coretend-home-\(UUID())")
        let groupContainers = home.appendingPathComponent("Library/Group Containers")
        try fm.createDirectory(at: groupContainers.appendingPathComponent("group.com.acme.suite"),
                               withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: home) }

        let app = InstalledApp(name: "Acme Editor", bundleIdentifier: "com.acme.Editor", version: "1.0",
                               path: URL(fileURLWithPath: "/Applications/Acme Editor.app"),
                               sizeBytes: 0, architectures: [])
        let candidates = AppDiscovery(home: home).groupContainerCandidates(installedApps: [app])
        #expect(candidates.count == 1)
        #expect(candidates.first?.item.kind == .groupContainers)
        #expect(candidates.first?.item.url.lastPathComponent == "group.com.acme.suite")
        #expect(candidates.first?.sharingAppCount == 1)
    }

    @Test func groupContainerSharedByTwoAppsReportsCountOfTwo() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("coretend-home-\(UUID())")
        let groupContainers = home.appendingPathComponent("Library/Group Containers")
        try fm.createDirectory(at: groupContainers.appendingPathComponent("group.com.acme.suite"),
                               withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: home) }

        let photoEditor = InstalledApp(name: "Acme Photo", bundleIdentifier: "com.acme.Photo", version: "1.0",
                                       path: URL(fileURLWithPath: "/Applications/Acme Photo.app"),
                                       sizeBytes: 0, architectures: [])
        let videoEditor = InstalledApp(name: "Acme Video", bundleIdentifier: "com.acme.Video", version: "1.0",
                                       path: URL(fileURLWithPath: "/Applications/Acme Video.app"),
                                       sizeBytes: 0, architectures: [])
        let candidates = AppDiscovery(home: home).groupContainerCandidates(installedApps: [photoEditor, videoEditor])
        #expect(candidates.count == 1)
        #expect(candidates.first?.sharingAppCount == 2)
    }

    @Test func groupContainerMatchingNoInstalledVendorIsOmitted() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("coretend-home-\(UUID())")
        let groupContainers = home.appendingPathComponent("Library/Group Containers")
        try fm.createDirectory(at: groupContainers.appendingPathComponent("group.com.unrelated.suite"),
                               withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: home) }

        let app = InstalledApp(name: "Acme Editor", bundleIdentifier: "com.acme.Editor", version: "1.0",
                               path: URL(fileURLWithPath: "/Applications/Acme Editor.app"),
                               sizeBytes: 0, architectures: [])
        let candidates = AppDiscovery(home: home).groupContainerCandidates(installedApps: [app])
        #expect(candidates.isEmpty)
    }

    @Test func groupContainerMissingDirectoryYieldsEmptyNeverACrash() {
        let home = URL(fileURLWithPath: "/nonexistent-home-\(UUID().uuidString)")
        let candidates = AppDiscovery(home: home).groupContainerCandidates(installedApps: [])
        #expect(candidates.isEmpty)
    }
}
