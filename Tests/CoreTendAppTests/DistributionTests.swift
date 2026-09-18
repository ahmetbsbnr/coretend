// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// Two products, one codebase.
///
/// The risk with a second build target is not that it fails to compile — it is
/// that it compiles fine and ships something that cannot work. A `#if` someone
/// forgets leaves a button on screen in the sandboxed build whose backing
/// capability is absent, and the Developer ID build compiles clean either way.
///
/// So capabilities are data, the sidebar is built from them, and these tests
/// assert the two products stay coherent rather than merely buildable.
@Suite("Distribution targets")
struct DistributionTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    // MARK: - Capabilities

    @Test func theSandboxedBuildDropsExactlyWhatTheContainerForbids() {
        let store = AppCapabilities.of(.appStore)
        #expect(store.canReachSystemLocations == false)
        #expect(store.canManageApplications == false)
        #expect(store.canCleanBrowserData == false)
        #expect(store.canInspectIntegrity == false)
        #expect(store.requiresUserSelectedFolders)
    }

    /// Apple delivers App Store updates. An in-app checker there would be both
    /// redundant and a review rejection, and it is the reason the sandboxed
    /// entitlements request no network client at all.
    @Test func theAppStoreBuildDoesNotCheckForUpdates() {
        #expect(AppCapabilities.of(.appStore).canCheckForUpdates == false)
        #expect(AppCapabilities.of(.developerID).canCheckForUpdates)
    }

    @Test func theDeveloperIDBuildKeepsEverything() {
        let direct = AppCapabilities.of(.developerID)
        for module in ModuleID.allCases {
            #expect(direct.supports(module), "\(module) is unavailable in the unsandboxed build")
        }
    }

    // MARK: - Nothing unreachable, nothing broken

    /// The sandboxed build must still be a product. If the sandbox took
    /// everything, there would be nothing to ship.
    @Test func theSandboxedBuildStillHasModules() {
        let groups = SidebarGroup.available(.of(.appStore))
        let modules = groups.flatMap(\.modules)
        #expect(modules.count >= 5, "only \(modules.count) modules survive the sandbox")
        // The four that work on user-chosen folders are the product there.
        for module in [ModuleID.spaceLens, .duplicates, .record, .smartCare] {
            #expect(modules.contains(module), "\(module) should survive the sandbox")
        }
    }

    /// A group emptied by filtering must disappear, not render as a header with
    /// nothing under it.
    @Test func groupsLeftEmptyAreDropped() {
        for distribution in Distribution.allCases {
            for group in SidebarGroup.available(.of(distribution)) {
                #expect(!group.modules.isEmpty,
                        "\(distribution): group \(group.id) renders a header with no rows")
            }
        }
    }

    /// Every module the sidebar offers must be one the build can deliver, in
    /// both products. This is the assertion that makes "absent rather than
    /// broken" true rather than intended.
    @Test func everyOfferedModuleIsSupported() {
        for distribution in Distribution.allCases {
            let capabilities = AppCapabilities.of(distribution)
            for module in SidebarGroup.available(capabilities).flatMap(\.modules) {
                #expect(capabilities.supports(module),
                        "\(distribution) offers \(module) but cannot deliver it")
            }
        }
    }

    /// New modules default to available in both builds. A module is only listed
    /// in `supports` when the sandbox genuinely takes something from it, so a
    /// module added without thinking about distribution ships everywhere —
    /// which is the right default, and this records it.
    @Test func modulesNotNamedInSupportsWorkEverywhere() {
        let store = AppCapabilities.of(.appStore)
        for module in [ModuleID.spaceLens, .duplicates, .performance,
                       .record, .smartCare] {
            #expect(store.supports(module))
        }
    }

    // MARK: - The two targets

    /// The second entry point exists only because SwiftPM will not let two
    /// targets share a source directory. It must stay a copy.
    @Test func theTwoEntryPointsAreIdentical() throws {
        func body(_ path: String) throws -> [String] {
            try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("//") }
        }
        #expect(try body("Sources/CoreTend/main.swift")
                == body("Sources/CoreTendAppStore/main.swift"),
                "the two entry points have diverged")
    }

    /// `CORETEND_APP_STORE` may be read in exactly one place. Scattering it is
    /// how two products drift into two behaviours nobody can enumerate.
    @Test func theCompileFlagIsReadInOnlyOnePlace() throws {
        let dir = root.appendingPathComponent("Sources/CoreTendApp")
        var readers: [String] = []
        for name in try SourceTree.swiftFiles(under: dir)
            where name.hasSuffix(".swift") {
            let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
            if text.contains("#if CORETEND_APP_STORE") { readers.append(name) }
        }
        #expect(readers == ["Distribution.swift"],
                "CORETEND_APP_STORE is read in \(readers) — it belongs in Distribution only")
    }

    // MARK: - Entitlements

    @Test func theSandboxedEntitlementsEnableTheSandbox() throws {
        let url = root.appendingPathComponent("Configuration/CoreTend-AppStore.entitlements")
        let plist = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url), format: nil) as? [String: Any] ?? [:]
        #expect(plist["com.apple.security.app-sandbox"] as? Bool == true)
        #expect(plist["com.apple.security.files.user-selected.read-write"] as? Bool == true)
        #expect(plist["com.apple.security.files.bookmarks.app-scope"] as? Bool == true)
    }

    /// The absent half matters more than the present half. Each of these would
    /// let the build reach something the capability model says it cannot, and
    /// the model would then be a comment rather than a constraint.
    @Test func theSandboxedEntitlementsRequestNothingBeyondUserSelectedFolders() throws {
        let url = root.appendingPathComponent("Configuration/CoreTend-AppStore.entitlements")
        let plist = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url), format: nil) as? [String: Any] ?? [:]
        for forbidden in [
            "com.apple.security.files.downloads.read-write",
            "com.apple.security.temporary-exception.files.absolute-path.read-write",
            "com.apple.security.temporary-exception.files.home-relative-path.read-write",
            "com.apple.security.automation.apple-events",
            "com.apple.security.cs.disable-library-validation",
            "com.apple.security.cs.allow-unsigned-executable-memory",
        ] {
            #expect(plist[forbidden] == nil, "sandboxed build requests \(forbidden)")
        }
        // No network client: the App Store build does not check for updates.
        #expect(plist["com.apple.security.network.client"] == nil)
        #expect(AppCapabilities.of(.appStore).canCheckForUpdates == false,
                "entitlements and capabilities disagree about networking")
    }

    /// The Developer ID build must stay unsandboxed — enabling the sandbox
    /// there would silently remove most of the product.
    @Test func theDeveloperIDEntitlementsDoNotEnableTheSandbox() throws {
        let url = root.appendingPathComponent("Configuration/CoreTend.entitlements")
        let plist = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url), format: nil) as? [String: Any] ?? [:]
        #expect(plist["com.apple.security.app-sandbox"] == nil)
    }
}

/// Every folder the user picks as a scan root must go through `FolderPicker`.
///
/// Four screens ran their own `NSOpenPanel`. In the sandboxed build, picking a
/// folder grants access *for this launch only*; turning that into a lasting
/// grant means recording a security-scoped bookmark at the moment of the pick,
/// and nowhere else. A panel that forgets is not broken today — it works for
/// the whole session and then quietly asks again after the next relaunch, which
/// reads as the app losing the user's settings.
@Suite("Folder pickers")
struct FolderPickerContractTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func sources() throws -> [(name: String, text: String)] {
        let dir = root.appendingPathComponent("Sources/CoreTendApp")
        return try SourceTree.swiftFiles(under: dir)
            .filter { $0.hasSuffix(".swift") }
            .map { ($0, try String(contentsOf: dir.appendingPathComponent($0), encoding: .utf8)) }
    }

    @Test func noViewRunsItsOwnFolderPanel() throws {
        for file in try sources() where file.name != "FolderPicker.swift" {
            // A panel that chooses *files* is a different thing — an app to
            // inspect, a download to verify — and needs no folder grant.
            guard file.text.contains("canChooseDirectories = true") else { continue }
            Issue.record("\(file.name) runs its own folder panel — use FolderPicker, which records the security-scoped grant at the same moment")
        }
    }

    /// The picker must record the grant, or it is just a panel with extra steps.
    @Test func thePickerRecordsAGrant() throws {
        let sources = Dictionary(uniqueKeysWithValues: try sources().map { ($0.name, $0.text) })
        let picker = try #require(sources["FolderPicker.swift"])
        #expect(picker.contains("access.grant(url)"))
    }
}
