// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing

/// `MainWindow` is a two-column `NavigationSplitView`. A detail view that
/// nests its own `NavigationSplitView`, or uses a `TabView` as its root
/// container, has repeatedly been the cause of the sidebar collapsing to an
/// empty column on macOS 14. These files must stay free of both.
@Suite("Sidebar structure — detail views never nest a navigation container")
struct SidebarStructureTests {
    private let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/CoreTendApp")

    private func body(of file: String) throws -> String {
        try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
    }

    @Test func duplicatesViewHasNoNestedSplitViewOrTabView() throws {
        let text = try body(of: "DuplicatesView.swift")
        #expect(!text.contains("NavigationSplitView"))
        #expect(!text.contains("TabView"))
        #expect(!text.contains("NavigationStack"))
    }

    @Test func mainWindowStillPinsColumnVisibilityToAll() throws {
        let text = try body(of: "CoreTendApp.swift")
        // The guard that snaps the sidebar back if a detail view tries to
        // collapse it.
        #expect(text.contains("columnVisibility"))
        #expect(text.contains("if newValue != .all { columnVisibility = .all }"))
        #expect(text.contains(".navigationSplitViewStyle(.balanced)"))
    }

    @Test func smartScanModuleRowsDoNotOwnListSelection() throws {
        // The Dashboard's Smart Scan module rows are plain tappable rows, not
        // a `List(selection:)` — so focusing one never greys the sidebar's
        // active-module marker (the prior focus-grey regression).
        let text = try body(of: "SmartScanDashboardSection.swift")
        #expect(!text.contains("List(selection:"))
    }
}
