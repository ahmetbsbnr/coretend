// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

// The main window: routes the selected module to its screen. See docs/FRONTEND_REBUILD.md.

import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence

/// The two regions window-level keyboard focus moves between.
///
/// The window had no such notion, and that was the focus defect: the sidebar
/// was a `.focusable()` container and the only focusable thing in the content,
/// so it took first responder at launch and never gave it up. Tab did nothing,
/// clicking a list did not move focus, and the arrow keys therefore always
/// drove module navigation — measured with `FocusProbe`, whose key-view loop
/// contained the toolbar controls and the sidebar proxy and no list at all.
enum WindowFocusRegion: Hashable {
    case sidebar, detail
}

struct MainWindow: View {

    @State private var selection: ModuleID? =
        TestModuleOverride.resolve(environment: ProcessInfo.processInfo.environment) ?? .smartCare
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false
    /// SwiftUI's own way into the Settings scene. `showSettingsWindow:` goes
    /// through the responder chain and does nothing at launch, before the app
    /// has been clicked — which is exactly when a capture needs it.
    @Environment(\.openSettings) private var openSettings
    @State private var showCommandPalette = false
    @State private var showShortcuts = false
    /// Bound so View › Hide Sidebar has something to move. Without a binding
    /// the split view owns the state and the menu item is inert.
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    /// Owned here rather than inside Settings so the automatic check runs at
    /// launch. A check that only happens once the user opens the Settings
    /// screen is not an automatic check.
    @State private var updates = UpdatesViewModel()
    /// Which half of the window the keyboard is in. Owned here because it is a
    /// property of the window, not of any one module.
    @FocusState private var region: WindowFocusRegion?
    // Review decisions belong to the window session, not a transient route.
    @State private var cleanupModel = CleanupViewModel()
    @State private var duplicatesModel = DuplicatesViewModel()

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
                .focused($region, equals: .sidebar)
        } detail: {
            Group {
                switch routed {
                case .smartCare:
                    OverviewScreen()
                case .cleanup:
                    CleanupView(model: cleanupModel)
                case .protection:
                    ProtectionView()
                case .applications:
                    ApplicationsView()
                case .duplicates:
                    DuplicatesView(model: duplicatesModel)
                case .performance:
                    PerformanceView()
                case .spaceLens:
                    SpaceLensView()
                case .record:
                    RecordView()
                case nil:
                    // Only reachable before a selection exists; every ModuleID
                    // has a real view. There is no "under construction" state.
                    OverviewScreen()
                }
            }
            .mcCanvasBackground()
            // A focus *section*, not a focusable container.
            //
            // Making the detail itself focusable did break the trap — Tab left
            // the sidebar and the arrow keys stopped changing module — but it
            // then parked focus on an empty container, so the journal still
            // never saw an arrow key. A section is a region the focus system
            // enters and then resolves to the first real focusable inside it,
            // which is the module's own list.
            //
            // The custom `onKeyPress(.tab)` that went with the previous attempt
            // is gone too: returning `.handled` consumed the very Tab that
            // AppKit needed in order to perform the move.
            .focusSection()
        }
        .onAppear {
            // A sheet is modal to its window: with onboarding up, the Settings
            // window cannot come forward, which is why the Settings capture
            // reported nothing at all rather than the wrong thing.
            if CaptureHarness.showOnboarding || (!onboardingDone && !CaptureHarness.showSettings) {
                showOnboarding = true
            }
            // After the main window exists: the Settings scene's responder
            // action is installed with the scene graph, and at the first
            // onAppear there is nothing to send it to.
            if CaptureHarness.showSettings {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
            }
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
        .onChange(of: selection) { _, module in
            DispatchQueue.main.async { FocusTrace.snapshot("module:\(module?.rawValue ?? "nil")") }
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
            // Global search. The palette is already the app's jump-to-anything
            // surface; before this it was reachable only from ⌘K and a glyph
            // that read as a menu. A field says what it does, and clicking it
            // opens the palette focused — one control, one behaviour, no
            // second search index.
            if routed.map({ !$0.hasOwnSearch }) ?? true {
              ToolbarItem(placement: .principal) {
                Button {
                    showCommandPalette = true
                } label: {
                    HStack(spacing: MCSpacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .font(MCFont.caption.weight(.medium))
                        Text(L("toolbar.search"))
                            .font(MCFont.secondaryBody)
                        Spacer(minLength: MCSpacing.md)
                        Text("⌘K")
                            .font(MCFont.micro)
                            .foregroundStyle(MCColor.textTertiary)
                    }
                    .foregroundStyle(MCColor.textSecondary)
                    .padding(.horizontal, MCSpacing.xs)
                    .padding(.vertical, MCSpacing.xxs + 1)
                    .frame(width: 260)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.accessoryBar)
                .help(L("palette.open"))
                .accessibilityIdentifier("toolbar.search")
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
                // The window's own options, in the place a Mac app puts them,
                // rather than only in the menu bar where a pointer-driven user
                // never finds them.
                if routed.map({ !$0.hasOwnSearch }) ?? true {
                  Menu {
                    Button(L("toolbar.toggle_sidebar")) {
                        withAnimation(MCMotion.transition) {
                            sidebarVisibility = sidebarVisibility == .detailOnly ? .all : .detailOnly
                        }
                    }
                    .keyboardShortcut("s", modifiers: [.command, .control])
                    Divider()
                    // Routed through the same notification the Help menu
                    // uses, not local state: one command, one path. Two ways
                    // to open one screen is two things to keep working.
                    Button(L("menu.help.shortcuts")) {
                        NotificationCenter.default.post(name: .mcShowKeyboardShortcuts, object: nil)
                    }
                    SettingsLink { Text(L("menubar.settings")) }
                } label: {
                    Label(L("toolbar.more"), systemImage: "ellipsis.circle")
                }
                  .menuIndicator(.hidden)
                  .help(L("toolbar.more"))
                  .accessibilityIdentifier("toolbar.more")
                }
            }
        }
        // No opaque ground here. This single line was what made the sidebar
        // render as a flat panel however it asked to be drawn: it composited
        // an opaque fill across the whole split view, leaving the sidebar's
        // material nothing behind the window to sample. The detail column
        // paints its own canvas (`mcCanvasBackground`), so nothing else
        // depended on it.
        // Without this the toolbar paints its own material on top of the
        // sidebar's, and two stacked vibrancy layers produce a visibly lighter
        // block over the top of the sidebar — a seam exactly where the point
        // of the exercise was not to have one.
        .modifier(MCHiddenToolbarBackground())
        .mcConfigureWindow()
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
    @State private var highlighted: Entry.ID?
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
                    .onSubmit { activate(id: highlighted) }
                    .accessibilityIdentifier("commandPalette.search")
            }
            .padding(MCSpacing.sm)
            Divider()
            if filtered.isEmpty {
                MCEmptyState(icon: "magnifyingglass", title: L("palette.no_results"), message: "")
            } else {
                // A selectable list, not a stack of plain buttons.
                //
                // Plain buttons inside list rows only answered a click that
                // landed on the glyph or the few characters of the label —
                // the rest of the row was dead, the pointer never changed,
                // and the keyboard could not reach them at all: the field
                // holds focus, so ↑↓ went nowhere and Return always fired the
                // first result whatever was under the cursor. Selection is
                // state now, the arrows move it from the field, and the whole
                // row is the target.
                List(filtered, selection: $highlighted) { entry in
                    Label(entry.label, systemImage: entry.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { activate(entry) }
                        .tag(entry.id)
                        .accessibilityIdentifier(entry.id)
                        .accessibilityAddTraits(.isButton)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 420, height: 360)
        .onAppear { searchFocused = true; highlighted = filtered.first?.id }
        .onChange(of: query) { _, _ in highlighted = filtered.first?.id }
        .onKeyPress(.escape) { isPresented = false; return .handled }
        .onKeyPress(.downArrow) { move(by: 1); return .handled }
        .onKeyPress(.upArrow) { move(by: -1); return .handled }
    }

    /// Moves the highlight without moving focus: the field keeps the caret,
    /// so typing and choosing are the same gesture.
    private func move(by step: Int) {
        let list = filtered
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == highlighted } ?? 0
        let next = min(max(current + step, 0), list.count - 1)
        highlighted = list[next].id
    }

    private func activate(id: Entry.ID?) {
        activate(filtered.first { $0.id == id } ?? filtered.first)
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

/// The deployment target is macOS 14, where `toolbarBackgroundVisibility` does
/// not exist. Below 15 the toolbar keeps its own material and the seam stays —
/// which is the appearance the app already had, not a regression.
private struct MCHiddenToolbarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            content
        }
    }
}
