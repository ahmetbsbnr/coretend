// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing

/// Structural contracts about the navigation layer.
///
/// These read source text rather than exercising views, because a SwiftUI view
/// hierarchy is not inspectable from a unit test — and because the defect being
/// guarded is precisely a *construct* being reintroduced, not a behaviour.
@Suite("Navigation structure")
struct ModuleSubNavContractTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func appSources() throws -> [(name: String, text: String)] {
        let dir = root.appendingPathComponent("Sources/CoreTendApp")
        let names = try SourceTree.swiftFiles(under: dir)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        return try names.map {
            ($0, try String(contentsOf: dir.appendingPathComponent($0), encoding: .utf8))
        }
    }

    /// Source with `//` comment lines removed, so a contract about *code* is
    /// not tripped by the comment explaining that very contract.
    private func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// A `TabView` as the detail of a `NavigationSplitView` can blank the split
    /// view's sidebar on macOS. That is the 1.0.1 defect, reproduced on the
    /// published build. Two modules had been moved off it and a third —
    /// ApplicationsView — had been left behind for months precisely because
    /// nothing failed when it stayed.
    /// Scoped to the main window's own views.
    ///
    /// The defect this guards is specific and stated above: a `TabView` *as
    /// the detail of a NavigationSplitView* can blank that split view's
    /// sidebar. The Settings scene is a separate window with no split view in
    /// it, and a tabbed Settings window is the standard macOS shape — the one
    /// people look for. Excluding it keeps the contract pointed at the thing
    /// that actually broke, rather than turning a specific layout bug into a
    /// blanket ban on an AppKit idiom.
    private static let scenesWithoutASplitView = ["SettingsView.swift"]

    @Test func noModuleUsesATabView() throws {
        for file in try appSources()
        where !Self.scenesWithoutASplitView.contains(file.name) {
            #expect(
                !codeOnly(file.text).contains("TabView"),
                "\(file.name) uses TabView — use ModuleSubNav instead (see its doc comment)"
            )
        }
    }

    /// Exactly one NavigationSplitView exists, in MainWindow. A second one
    /// anywhere means a module has started re-implementing primary navigation.
    @Test func primaryNavigationIsDeclaredExactlyOnce() throws {
        // Matching "NavigationSplitView" rather than "NavigationSplitView {":
        // adding a columnVisibility binding changed the call's shape and the
        // check silently found nothing, which it reported as a failure only
        // because the expected list was non-empty. A looser match cannot go
        // quiet the same way.
        let declaring = try appSources()
            .filter { $0.text.contains("NavigationSplitView(") || $0.text.contains("NavigationSplitView {") }
            .map(\.name)
        #expect(declaring == ["App/MainWindow.swift"], "unexpected NavigationSplitView in \(declaring)")
    }

    /// Sub-navigation goes through ModuleSubNav, so the idiom cannot drift back
    /// apart into a per-module segmented control with its own padding, width
    /// and background.
    @Test func subNavigationIsNotHandRolledPerModule() throws {
        let handRolled = try appSources()
            .filter { $0.name != "ModuleSubNav.swift" }
            .filter { $0.text.contains("pickerStyle(.segmented)") && $0.text.contains("safeAreaInset(edge: .top") }
            .map(\.name)
        #expect(handRolled.isEmpty, "hand-rolled pinned sub-nav in \(handRolled) — use ModuleSubNav")
    }

    /// Every sub-screen declares itself one.
    ///
    /// A sub-screen must not set a window title — its parent module already
    /// did, and the last writer would win. But "correctly has no title" and
    /// "forgot the title" look identical in source, which is how three views
    /// shipped untitled. Conforming to `ModuleSubScreen` is the declaration
    /// that the absence is deliberate, and this test is what makes the
    /// declaration load-bearing.
    @Test func everySubScreenIsDeclaredAsOneAndSetsNoTitle() throws {
        let subScreens = [
            "LeftoversView", "AppUpdatesView", "PrivacyCleanerView",
            "SimilarImagesView", "InstalledAppsView", "IntegrityView", "LargeOldFilesView",
        ]
        let sources = Dictionary(uniqueKeysWithValues: try appSources().map { ($0.name, $0.text) })
        for (name, text) in sources {
            for screen in subScreens where text.contains("struct \(screen):") {
                #expect(text.contains("struct \(screen): ModuleSubScreen"),
                        "\(screen) in \(name) is a sub-screen but does not declare it")
            }
        }
        // And none of them claims the window title.
        for file in ["LeftoversView.swift", "AppUpdatesView.swift",
                     "PrivacyCleanerView.swift", "SimilarImagesView.swift",
                     "CloudCleanupView.swift", "StartupItemsView.swift"] {
            let text = try #require(sources[file], "missing \(file)")
            #expect(!text.contains("navigationTitle("),
                    "\(file) sets a window title its parent module already owns")
        }
    }

    /// Every module reachable from the sidebar names itself in the title bar.
    @Test func everyRoutedModuleSetsANavigationTitle() throws {
        let routed = [
            "DashboardView", "RecordView", "CleanupView", "SpaceLensView",
            "DuplicatesView", "ApplicationsView", "ProtectionView", "PerformanceView",
        ]
        let sources = Dictionary(uniqueKeysWithValues: try appSources().map { ($0.name, $0.text) })
        for module in routed {
            let text = try #require(sources["\(module).swift"], "missing source for \(module)")
            #expect(text.contains("navigationTitle("), "\(module) sets no navigationTitle")
        }
    }
}

@Suite("Sidebar follows the system row size")
struct SidebarSizeContractTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The sidebar's own metrics must come from `MCSidebarMetrics`, not from
    /// constants. A fixed point size compiles, renders, and quietly ignores a
    /// setting the user changed for legibility.
    @Test func theSidebarReadsTheSystemRowSize() throws {
        let text = try String(
            contentsOf: root.appendingPathComponent("Sources/CoreTendApp/Sidebar.swift"),
            encoding: .utf8)
        #expect(text.contains("MCSidebarMetrics.shared.size"))
        #expect(text.contains("metrics.iconSize"), "the glyph does not follow the setting")
        #expect(text.contains("metrics.rowPadding"), "row height does not follow the setting")
        #expect(text.contains("MCFont.sidebarItem(metrics"), "the label does not follow the setting")
    }

    /// And it must not hardcode one anywhere, which is what it did before.
    @Test func theSidebarHardcodesNoRowMetric() throws {
        let text = try String(
            contentsOf: root.appendingPathComponent("Sources/CoreTendApp/Sidebar.swift"),
            encoding: .utf8)
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//") else { continue }
            #expect(!trimmed.contains("MCIconSize.row"),
                    "the sidebar uses a fixed glyph size — it must follow MCSidebarMetrics: \(trimmed)")
        }
    }
}

@Suite("Sub-navigation adopts the current idiom")
struct SubNavIdiomTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func subNav() throws -> String {
        try String(contentsOf: root.appendingPathComponent("Sources/CoreTendApp/ModuleSubNav.swift"),
                   encoding: .utf8)
    }

    /// macOS 27 introduced `PickerStyle.tabs`, the platform's own answer to a
    /// small set of peer sections at the top of a pane. A segmented control is
    /// the previous generation's answer and is a *value* picker borrowed for
    /// navigation, which is why it always read slightly wrong here.
    @Test func theCurrentIdiomIsAdopted() throws {
        #expect(try subNav().contains(".pickerStyle(.tabs)"))
    }

    /// And gated, because the deployment target is macOS 14 where `.tabs` does
    /// not exist — the compiler refuses it ungated, which is the check working.
    @Test func itIsGatedForTheDeploymentTarget() throws {
        let text = try subNav()
        #expect(text.contains("#available(macOS 27.0, *)"))
        #expect(text.contains(".pickerStyle(.segmented)"),
                "no fallback for macOS 14–26, where .tabs does not exist")
    }
}

/// `.fixedSize(horizontal: false, vertical: true)` inside a module's detail
/// column starves the NavigationSplitView sidebar to nothing. Phase 1
/// bisected a blank sidebar to exactly this; the Integrity rebuild then
/// reproduced it with one explainer line. A capture check catches it after
/// the fact; this catches it before a build.
///
/// Sheets and the onboarding window are not in the split view and may wrap.
@Suite("Detail columns do not use fixedSize")
struct DetailColumnLayoutTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test func noModuleViewUsesHorizontalFixedSize() throws {
        let dir = root.appendingPathComponent("Sources/CoreTendApp")
        let exempt = ["OnboardingView.swift", "KeyboardShortcutsView.swift", "SettingsView.swift",
                      "UpdatesView.swift", "DiagnosticReport.swift"]
        for name in try SourceTree.swiftFiles(under: dir) where !exempt.contains((name as NSString).lastPathComponent) {
            let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
            for line in text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                #expect(!trimmed.contains("fixedSize(horizontal: false"),
                        "\(name) uses fixedSize in a detail column, which blanks the sidebar: \(trimmed)")
            }
        }
    }
}
