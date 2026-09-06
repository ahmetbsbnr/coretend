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
    private let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private var sources: URL { repoRoot.appendingPathComponent("Sources/CoreTendApp") }

    private func body(of file: String) throws -> String {
        try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
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

    /// Regression: reproduced on macOS 26 — a `.borderedProminent` (default)
    /// button in a *non-scrolling* `NavigationSplitView` detail makes AppKit's
    /// "reveal the default control" pass scroll the SIDEBAR's list off-screen
    /// (the reported "Recovery Plan sidebar displaced / blank" bug). Every
    /// centred empty/success detail state that carries such a button must host
    /// its own `ScrollView` so that reveal stays local.
    @Test func centredDetailStatesWithADefaultButtonAreScrollHosted() throws {
        // The two shared components behind most of these screens.
        for file in ["Sources/DesignSystem/Components.swift"] {
            let text = try source(file)
            for component in ["struct MCSuccessState", "struct MCEmptyState"] {
                guard let start = text.range(of: component) else {
                    Issue.record("\(component) not found"); continue
                }
                let slice = String(text[start.lowerBound...].prefix(1600))
                #expect(slice.contains("ScrollView {"),
                        "\(component) must wrap its body in a ScrollView")
            }
        }
        // Recovery Plan's bespoke idle / transient states.
        let rp = try body(of: "RecoveryPlanView.swift")
        for state in ["private var startState: some View {",
                      "private func transientState(_ message: String) -> some View {"] {
            guard let r = rp.range(of: state) else { Issue.record("\(state) not found"); continue }
            let slice = String(rp[r.lowerBound...].prefix(1200))
            #expect(slice.contains("ScrollView {"), "\(state) must be scroll-hosted")
        }
    }

    /// Regression: the sidebar vanished when opening **Duplicates** — the same
    /// AppKit "reveal the first responder" pass scrolling the sidebar list
    /// off-range, this time triggered by the centred `idleView` (its only
    /// focusable control is `MCScanButton`). Every centred Duplicates detail
    /// state must own a local scroll host, and none may sit in a bare
    /// non-scrolling detail.
    @Test func duplicatesCentredStatesOwnALocalScrollHost() throws {
        let text = try body(of: "DuplicatesView.swift")
        for state in ["private var idleView: some View {",
                      "private func scanningView(_ processed: Int, _ total: Int) -> some View {"] {
            guard let r = text.range(of: state) else { Issue.record("\(state) not found"); continue }
            let slice = String(text[r.lowerBound...].prefix(4000))
            #expect(slice.contains(".mcCenteredScrollState()"),
                    "\(state) must be wrapped in MCCenteredScrollState")
        }
        // emptyView / finishedView delegate to the already-scroll-hosted
        // shared primitives.
        #expect(text.contains("private var emptyView: some View {\n        MCEmptyState("))
        #expect(text.contains("private func finishedView(_ freed: Int64) -> some View {\n        MCSuccessState("))
        // No accidental navigation-container nesting introduced by the fix.
        #expect(!text.contains("NavigationSplitView"))
        #expect(!text.contains("TabView"))
        #expect(!text.contains("NavigationStack"))
    }

    /// The shared primitive the migration standardised on. It must be a real
    /// local scroll host, or every migrated call site is a no-op.
    @Test func mcCenteredScrollStateIsAScrollHost() throws {
        let text = try source("Sources/DesignSystem/Components.swift")
        guard let r = text.range(of: "struct MCCenteredScrollState") else {
            Issue.record("MCCenteredScrollState not found"); return
        }
        let slice = String(text[r.lowerBound...].prefix(900))
        #expect(slice.contains("ScrollView {"))
        #expect(slice.contains("GeometryReader"))
        #expect(text.contains("func mcCenteredScrollState()"))
    }

    /// Broad guard so a *third* module can't regress the same way: every
    /// centred start/scanning/empty detail state that carries a focusable
    /// control must resolve to a local scroll host — either `MCCenteredScrollState`,
    /// its own `ScrollView`/`GeometryReader`, or the shared
    /// `MCEmptyState` / `MCSuccessState` primitives.
    @Test func allCentredDetailStatesWithControlsAreScrollHosted() throws {
        // file : [state-signature]
        let targets: [String: [String]] = [
            "DuplicatesView.swift": [
                "private var idleView: some View {",
                "private func scanningView(_ processed: Int, _ total: Int) -> some View {",
            ],
            "CleanupView.swift": [
                "private var idleView: some View {",
                "private var scanningView: some View {",
            ],
            "SpaceLensView.swift": [
                "private var idleView: some View {",
                "private func scanningView(_ items: Int) -> some View {",
            ],
            "MyClutterView.swift": [
                "private var idleView: some View {",
                "private var scanningView: some View {",
                "private var emptyView: some View {",
            ],
            "CloudCleanupView.swift": [
                "private var providerPicker: some View {",
            ],
            "StorageTimelineView.swift": [
                "private var noHistoryAtAllState: some View {",
            ],
            "SimilarImagesView.swift": [
                "case let .scanning(processed, total):",
                "case .empty:",
            ],
        ]
        let hosts = [".mcCenteredScrollState()", "ScrollView {", "GeometryReader",
                     "MCEmptyState(", "MCSuccessState("]
        for (file, states) in targets {
            let text = try body(of: file)
            for state in states {
                guard let r = text.range(of: state) else {
                    Issue.record("\(file): \(state) not found"); continue
                }
                let slice = String(text[r.lowerBound...].prefix(4000))
                #expect(hosts.contains { slice.contains($0) },
                        "\(file): \(state) is a centred state with controls but has no local scroll host")
            }
        }
    }
}
