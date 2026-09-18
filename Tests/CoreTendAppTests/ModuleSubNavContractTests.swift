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
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
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
    @Test func noModuleUsesATabView() throws {
        for file in try appSources() {
            #expect(
                !codeOnly(file.text).contains("TabView"),
                "\(file.name) uses TabView — use ModuleSubNav instead (see its doc comment)"
            )
        }
    }

    /// Exactly one NavigationSplitView exists, in MainWindow. A second one
    /// anywhere means a module has started re-implementing primary navigation.
    @Test func primaryNavigationIsDeclaredExactlyOnce() throws {
        let declaring = try appSources()
            .filter { $0.text.contains("NavigationSplitView {") }
            .map(\.name)
        #expect(declaring == ["CoreTendApp.swift"], "unexpected NavigationSplitView in \(declaring)")
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

    /// Every module reachable from the sidebar names itself in the title bar.
    /// Three views shipped without a title because nothing checked.
    @Test func everyRoutedModuleSetsANavigationTitle() throws {
        let routed = [
            "DashboardView", "CleanupView", "ProtectionView", "ApplicationsView",
            "DuplicatesView", "PerformanceView", "SpaceLensView", "MyClutterView",
            "CloudCleanupView", "MyActivityView",
        ]
        let sources = Dictionary(uniqueKeysWithValues: try appSources().map { ($0.name, $0.text) })
        for module in routed {
            let text = try #require(sources["\(module).swift"], "missing source for \(module)")
            #expect(text.contains("navigationTitle("), "\(module) sets no navigationTitle")
        }
    }
}
