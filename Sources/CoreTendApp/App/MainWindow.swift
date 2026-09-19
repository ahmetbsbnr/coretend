// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

// The main window: routes the selected module to its screen. See docs/FRONTEND_REBUILD.md.

import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence

struct MainWindow: View {

    @State private var selection: ModuleID? =
        TestModuleOverride.resolve(environment: ProcessInfo.processInfo.environment) ?? .smartCare
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false
    @State private var showCommandPalette = false
    @State private var showShortcuts = false
    /// Bound so View › Hide Sidebar has something to move. Without a binding
    /// the split view owns the state and the menu item is inert.
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    /// Owned here rather than inside Settings so the automatic check runs at
    /// launch. A check that only happens once the user opens the Settings
    /// screen is not an automatic check.
    @State private var updates = UpdatesViewModel()

    /// The module actually shown.
    ///
    /// A selection can arrive from somewhere the sidebar does not control — the
    /// command palette, a `.mcNavigate` notification, a restored value — and in
    /// the sandboxed build some of those name a module this binary cannot
    /// deliver. Resolving it once here means the detail column can never render
    /// a screen whose backing capability is absent.
    private var routed: ModuleID? {
        guard let selection else { return nil }
        return AppCapabilities.forCurrentBuild().supports(selection) ? selection : .smartCare
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            Sidebar(selection: Binding(
                get: { selection ?? .smartCare },
                set: { selection = $0 }))
        } detail: {
            Group {
                switch routed {
                case .smartCare:
                    DashboardView()
                case .cleanup:
                    CleanupView()
                case .protection:
                    ProtectionView()
                case .applications:
                    ApplicationsView()
                case .duplicates:
                    DuplicatesView()
                case .performance:
                    PerformanceView()
                case .spaceLens:
                    SpaceLensView()
                case .record:
                    RecordView()
                case nil:
                    // Only reachable before a selection exists; every ModuleID
                    // has a real view. There is no "under construction" state.
                    DashboardView()
                }
            }
            .mcCanvasBackground()
        }
        .onAppear {
            if !onboardingDone { showOnboarding = true }
            CaptureHarness.settle(showing: routed)
        }
        .task {
            // No-op unless the user opted in and a day has passed. Failures are
            // deliberately silent: an app that works fully offline must not
            // greet the user with a network error it chose to go looking for.
            await updates.checkAutomaticallyIfDue()
        }
        .sheet(isPresented: $showOnboarding, onDismiss: { onboardingDone = true }) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcNavigate)) { note in
            if let module = note.object as? ModuleID { selection = module }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcOpenSpaceLensAt)) { _ in
            selection = .spaceLens
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcShowOnboarding)) { _ in
            showOnboarding = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcShowCommandPalette)) { _ in
            showCommandPalette = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcShowKeyboardShortcuts)) { _ in
            showShortcuts = true
        }
        .sheet(isPresented: $showShortcuts) { KeyboardShortcutsView() }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView(isPresented: $showCommandPalette)
        }
        .toolbar {
            // The module's own verb, on the left of the toolbar where a
            // document app puts its primary action. Every scanning module
            // already answers ⌘R; this gives that command a visible control
            // instead of leaving it to the keyboard and a menu.
            if let scannable = routed, scannable.hasScan {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        NotificationCenter.default.post(name: .mcStartScan, object: nil)
                    } label: {
                        // Labelled, not a bare glyph. This is the verb the
                        // module exists for, and a triangle on its own says
                        // "play" — which is what a media control says.
                        Label(L("toolbar.scan"), systemImage: "sparkle.magnifyingglass")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .help(L("toolbar.scan_help", scannable.label))
                    .accessibilityIdentifier("toolbar.scan")
                }
            }
            ToolbarItemGroup {
                // Surfaced only when an automatic check actually found
                // something newer. There is no permanent "check for updates"
                // affordance in the toolbar: that belongs in Settings, and a
                // badge that is always present stops meaning anything.
                if case .result(.updateAvailable(let info)) = updates.phase {
                    SettingsLink {
                        Label(L("updates.available", info.version), systemImage: "arrow.down.circle.fill")
                    }
                    .help(L("updates.available", info.version))
                    .accessibilityIdentifier("toolbar.update_available")
                }
                Button {
                    showCommandPalette = true
                } label: {
                    Label(L("palette.open"), systemImage: "command")
                }
                .help(L("palette.open"))
            }
        }
        .background(MCColor.background)
    }

}

/// Same locale-aware, diacritic-insensitive comparison ClutterSearch uses
/// for file names — this just isn't matching a fileName/path pair, so it
/// doesn't call through that file-shaped API directly. An empty query
/// matches everything, matching every other search field in the app.
func paletteMatches(label: String, query: String) -> Bool {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return true }
    return label.localizedStandardContains(trimmed)
}

/// Fuzzy-filtered jump list over every sidebar destination, plus a handful
/// of actions — dispatched through the same NotificationCenter routing the
/// sidebar and Help-menu commands already use, not a second navigation
/// system. Deliberately not a general "search everything" index (see
/// GRAPHIFY_MAPS.md / the workspace audit for why that's a separate,
/// larger undertaking, not folded into this).
private struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private enum Entry: Identifiable {
        case module(ModuleID)
        case action(id: String, label: String, icon: String, perform: () -> Void)

        var id: String {
            switch self {
            case let .module(m): "module.\(m.rawValue)"
            case let .action(id, _, _, _): "action.\(id)"
            }
        }

        var label: String {
            switch self {
            case let .module(m): m.label
            case let .action(_, label, _, _): label
            }
        }

        var icon: String {
            switch self {
            case let .module(m): m.systemImage
            case let .action(_, _, icon, _): icon
            }
        }
    }

    private var actions: [Entry] {
        [
            // The palette invokes closures, not views, so it cannot hold a
            // SettingsLink. `showSettingsWindow:` is the responder-chain action
            // the Settings scene installs; it is the only supported way to open
            // that window from outside a view, and it is guarded so a future
            // macOS that renames it degrades to doing nothing rather than
            // crashing.
            .action(id: "checkUpdates", label: L("updates.check_now"), icon: "arrow.triangle.2.circlepath") {
                MCSettingsWindow.open()
            },
            .action(id: "scanHome", label: L("palette.scan_home"), icon: "circle.hexagongrid") {
                NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.spaceLens)
            },
        ]
    }

    private var entries: [Entry] {
        SidebarGroup.visibleModules.map(Entry.module) + actions
    }

    private var filtered: [Entry] {
        entries.filter { paletteMatches(label: $0.label, query: query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(MCColor.textSecondary)
                TextField(L("palette.placeholder"), text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { activate(filtered.first) }
                    .accessibilityIdentifier("commandPalette.search")
            }
            .padding(MCSpacing.sm)
            Divider()
            if filtered.isEmpty {
                MCEmptyState(icon: "magnifyingglass", title: L("palette.no_results"), message: "")
            } else {
                List(filtered) { entry in
                    Button {
                        activate(entry)
                    } label: {
                        Label(entry.label, systemImage: entry.icon)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(entry.id)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 420, height: 360)
        .onAppear { searchFocused = true }
        .onKeyPress(.escape) { isPresented = false; return .handled }
    }

    private func activate(_ entry: Entry?) {
        guard let entry else { return }
        switch entry {
        case let .module(m): NotificationCenter.default.post(name: .mcNavigate, object: m)
        case let .action(_, _, _, perform): perform()
        }
        isPresented = false
    }
}
