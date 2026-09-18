// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence

/// CoreTend renders in its own appearance, not the system's.
///
/// This is a product decision, not a technical one. The app is a single
/// designed surface — one canvas colour, one elevation ladder, one accent —
/// and every value in `MCColor` is tuned against the Slate ground it was
/// designed on. Following the system light/dark switch meant maintaining two
/// complete palettes, each of which had to independently clear contrast
/// minimums, and shipping a product whose identity changed depending on a
/// setting elsewhere on the Mac.
///
/// What this costs, stated plainly rather than discovered later: a user who
/// runs their Mac in Light appearance now gets one dark window among light
/// ones, and users who prefer light interfaces for visual-comfort reasons
/// have no in-app alternative. The mitigation is that the owned palette is
/// held to a higher contrast bar than the system default would enforce —
/// `DesignSystem` documents the measured ratios — and macOS's own Increase
/// Contrast and Reduce Transparency settings are still honoured, because
/// those are accessibility settings rather than taste settings.
///
/// Forced at launch before any window exists, so no view ever renders in the
/// inherited appearance first and then swaps.
/// Selects the module a test launch opens on, so a visual capture does not have
/// to drive the sidebar through the accessibility API.
///
/// The capture script used to find the sidebar row by walking
/// `outline 1 of scroll area 1 of group 1 of splitter group 1 of …` and calling
/// `select`. That coupled every screenshot to one specific AppKit view
/// hierarchy: replacing the `List` with CoreTend's own sidebar broke every
/// capture at once, and the AX tree is in any case flaky across rapid
/// relaunches — `entire contents` intermittently returns nothing.
///
/// A launch argument is deterministic, has no timing, and survives any future
/// change to how the sidebar is built.
///
/// Gated behind the same validated two-key test marker as the store and
/// filesystem fixtures, so a normal launch can never be steered by an
/// environment variable.
enum TestModuleOverride {
    static func resolve(environment: [String: String]) -> ModuleID? {
        guard TestStoreOverride.isTestMarkerSet(environment: environment),
              TestStoreOverride.resolve(environment: environment).directory != nil,
              let raw = environment["CORETEND_TEST_MODULE"]?
                  .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return nil }
        return ModuleID(rawValue: raw)
    }
}

@MainActor
enum AppAppearance {
    /// The one appearance CoreTend renders in.
    static let name: NSAppearance.Name = .darkAqua

    static func apply() {
        NSApplication.shared.appearance = NSAppearance(named: name)
    }
}

public struct CoreTendApp: App {
    public init() {
        AppAppearance.apply()
    }
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true
    // Same UserDefaults key LocalizationManager reads/writes. Observing it
    // here — not just inside LocalizationManager, which isn't itself
    // Observable — is what makes a language change re-render the whole
    // window immediately rather than only on next launch.
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue

    /// Core Bloom menu-bar template (adapts to menu bar appearance).
    static let menuBarImage: NSImage? = {
        guard let path = Bundle.main.path(forResource: "MenuBarTemplate", ofType: "png"),
              let image = NSImage(contentsOfFile: path) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }()

    public var body: some Scene {
        WindowGroup("CoreTend") {
            MainWindow()
                .frame(minWidth: MCSize.windowMinWidth, minHeight: MCSize.windowMinHeight)
                .id(appLanguageRaw)
        }
        .windowStyle(.automatic)
        // `.frame(minWidth:)` above constrains the *view*, not the window. The
        // window was freely resizable below it, and the view then overflowed —
        // which is what produced a 360pt-wide window whose sidebar rendered
        // its section headers as "ORAGE", "ORE", "STEM" with every icon cut
        // off the left edge. The minimum has to be expressed to the window
        // too, or it is only a suggestion the layout system then has to
        // violate.
        //
        // This is the same failure as the three layout bugs already fixed in
        // the views: something declares a size its container does not honour.
        // Here the container was the window itself.
        .windowResizability(.contentMinSize)
        .defaultSize(width: MCSize.windowDefaultWidth, height: MCSize.windowDefaultHeight)
        .commands {
            CoreTendHelpCommands()
        }

        MenuBarExtra(isInserted: $menuBarEnabled) {
            MenuBarView()
                .id(appLanguageRaw)
        } label: {
            MenuBarLabel()
            Text(verbatim: "CoreTend")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Official help destinations for builds after 0.9.0. These commands are a
/// source-branch improvement and are not claimed to exist in the tagged
/// 0.9.0 binary.
struct CoreTendHelpCommands: Commands {
    private let site = URL(string: "https://coretend.ahmetbsbnr.com")!
    private let repository = URL(string: "https://github.com/ahmetbsbnr/coretend")!

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button(L("updates.check_now")) {
                NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.settings)
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
        }
        CommandGroup(after: .toolbar) {
            Button(L("palette.open")) {
                NotificationCenter.default.post(name: .mcShowCommandPalette, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command])
        }
        // Every item here was a hardcoded English string. The app ships in
        // French and English and localizes 540 keys; the Help menu — the one
        // menu a confused user opens — was not among them.
        CommandGroup(replacing: .help) {
            Button(L("menu.help.app")) {
                NSWorkspace.shared.open(site.appending(path: "support#documentation"))
            }
            Button(L("menu.help.install")) {
                NSWorkspace.shared.open(site.appending(path: "support"))
            }
            // Was: open the website's support page, which lists no shortcuts
            // at all. A menu item that names a thing and does not show it
            // costs the user the trip to a browser to find that out.
            Button(L("menu.help.shortcuts")) {
                NotificationCenter.default.post(name: .mcShowKeyboardShortcuts, object: nil)
            }
            .keyboardShortcut("/", modifiers: [.command])
            Divider()
            Button(L("menu.help.report")) {
                NSWorkspace.shared.open(repository.appending(path: "issues"))
            }
            Button(L("menu.help.security")) {
                NSWorkspace.shared.open(site.appending(path: "support#security"))
            }
            Button(L("menu.help.about")) {
                NSWorkspace.shared.open(site.appending(path: "en/"))
            }
        }
    }
}

/// Menu-bar icon content. Polls at a slow, low-idle-cost cadence (independent
/// of whether the panel is open) purely to know whether an attention badge
/// should show — never duplicates the panel's metric collection pipeline.
@MainActor
@Observable
final class MenuBarIconModel {
    var needsAttention = false
    private let collector = MetricsCollector()
    private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
        task = Task {
            while !Task.isCancelled {
                let snap = await collector.snapshot()
                needsAttention = Self.needsAttention(
                    thermalState: snap.thermalState,
                    memoryPressureLevel: snap.memoryPressureLevel,
                    diskFreeBytes: snap.diskFreeBytes)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    /// Pure so it's directly testable without a live metrics collector.
    nonisolated static func needsAttention(thermalState: String, memoryPressureLevel: String, diskFreeBytes: Int64) -> Bool {
        thermalState == "serious" || thermalState == "critical"
            || memoryPressureLevel == "critical"
            || diskFreeBytes < 5_000_000_000
    }
}

struct MenuBarLabel: View {
    @State private var iconModel = MenuBarIconModel()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = CoreTendApp.menuBarImage {
                Image(nsImage: image)
            } else {
                Image(systemName: "circle.hexagonpath")
            }
            if iconModel.needsAttention {
                // Shape + position carries the meaning, not color alone.
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: MCIconSize.inline))
                    .offset(x: 5, y: -5)
            }
        }
        .task { iconModel.start() }
    }
}

/// Lightweight status popover. Samples system metrics only while the menu is open.
struct MenuBarView: View {
    @State private var snapshot: MetricsSnapshot?
    @State private var collector = MetricsCollector()
    @State private var lastActivity: ActivityRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.sm) {
            HStack(spacing: MCSpacing.xs) {
                CoreBloomMark(tint: [MCColor.teal], lineWidthFraction: 0.1)
                    .frame(width: 18, height: 18)
                Text(verbatim: "CoreTend").font(MCFont.cardTitle)
                Spacer(minLength: 0)
            }
            if let snap = snapshot {
                gaugeRow("cpu", L("menubar.cpu"), fraction: snap.cpuUsedFraction,
                         value: "\(Int(snap.cpuUsedFraction * 100))%",
                         warn: snap.cpuUsedFraction > 0.85)
                gaugeRow("memorychip", L("menubar.memory"), fraction: snap.memoryUsedFraction,
                         value: "\(Int(snap.memoryUsedFraction * 100))% · \(snap.memoryPressureLevel)",
                         warn: snap.memoryPressureLevel != "normal")
                gaugeRow("internaldrive", L("menubar.free_space"), fraction: snap.diskUsedFraction,
                         value: mcFormatBytes(snap.diskFreeBytes),
                         warn: snap.diskFreeBytes < 20_000_000_000)
                metricRow(icon: "thermometer.medium", label: L("menubar.thermal"),
                          value: snap.thermalState.capitalized,
                          warn: snap.thermalState == "serious" || snap.thermalState == "critical")
            } else {
                HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }
                    .padding(.vertical, MCSpacing.sm)
            }
            Divider()
            if let last = lastActivity {
                Text(L("menubar.last_activity", last.summary))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(last.date, style: .relative)
                    .font(.caption2).foregroundStyle(.tertiary)
            } else {
                Text(L("menubar.no_activity_yet"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Button(L("menubar.open_app")) { openWindow() }
            Button(L("menubar.settings")) {
                openWindow()
                NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.settings)
            }
            Button(L("menubar.quit")) { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 288)
        .task {
            // Adaptive: only samples while this view exists (menu open).
            _ = await collector.snapshot()
            while !Task.isCancelled {
                snapshot = await collector.snapshot()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .task {
            guard let store = AppEnvironment.shared.store else { return }
            let recent = (try? await store.activity(limit: 20)) ?? []
            lastActivity = recent.first
        }
    }

    private func openWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title == "CoreTend" }?.makeKeyAndOrderFront(nil)
    }

    /// Metric with an inline fill bar — for the 0…1 gauges (CPU, memory, disk).
    private func gaugeRow(_ icon: String, _ label: String, fraction: Double, value: String, warn: Bool) -> some View {
        let tint: Color = warn ? MCTheme.warning : MCTheme.accent
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: MCSpacing.xs) {
                Image(systemName: icon).frame(width: 16).foregroundStyle(tint)
                Text(label)
                Spacer(minLength: MCSpacing.xs)
                if warn {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(MCTheme.warning)
                        .accessibilityHidden(true)
                }
                Text(value).foregroundStyle(.secondary).monospacedDigit()
            }
            .font(MCFont.secondaryBody)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MCColor.separator.opacity(0.55))
                    Capsule().fill(tint)
                        .frame(width: max(3, geo.size.width * min(max(fraction, 0), 1)))
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)" + (warn ? ", \(L("menubar.warning_a11y"))" : ""))
    }

    /// Metric with no meaningful 0…1 fraction — a plain label/value row.
    private func metricRow(icon: String, label: String, value: String, warn: Bool) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 16)
                .foregroundStyle(warn ? MCTheme.warning : MCTheme.accent)
            Text(label)
            Spacer()
            if warn {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(MCTheme.warning)
                    .accessibilityHidden(true)
            }
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
        .font(MCFont.secondaryBody)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)" + (warn ? ", \(L("menubar.warning_a11y"))" : ""))
    }
}

enum ModuleID: String, CaseIterable, Identifiable {
    /// The first sidebar entry: it renders `DashboardView` and its label is
    /// `module.dashboard`. The case name and `"Smart Care"` raw value are kept
    /// only because the raw value is a stable identity matched elsewhere
    /// (`sidebar.<rawValue>` a11y ids, activity-summary prefixes); the
    /// standalone Smart Care view was retired in favour of the Dashboard.
    case smartCare = "Smart Care"
    case cleanup = "Cleanup"
    case protection = "Protection"
    case performance = "Performance"
    case applications = "Applications"
    case duplicates = "Duplicates"
    case myClutter = "My Clutter"
    case spaceLens = "Space Lens"
    case cloudCleanup = "Cloud Cleanup"
    case myActivity = "My Activity"
    case settings = "Settings"

    var id: String { rawValue }

    var identity: MCModuleIdentity {
        switch self {
        case .smartCare: .smartCare
        case .cleanup: .cleanup
        case .protection: .protection
        case .performance: .performance
        case .applications: .applications
        case .duplicates: .duplicates
        case .myClutter: .myClutter
        case .spaceLens: .spaceLens
        case .cloudCleanup: .cloudCleanup
        case .myActivity: .myActivity
        case .settings: .settings
        }
    }

    var systemImage: String { identity.icon }

    /// Localized display label. `rawValue` stays the internal stable identity
    /// (matched against `ActivityRecord.summary` prefixes elsewhere).
    var label: String {
        switch self {
        case .smartCare: L("module.dashboard")
        case .cleanup: L("module.storage")
        case .protection: L("module.protection")
        case .performance: L("performance.nav_title")
        case .applications: L("apps.title")
        case .duplicates: L("module.duplicates")
        case .myClutter: L("clutter.title")
        case .spaceLens: L("spacelens.title")
        case .cloudCleanup: L("cloud.nav_title")
        case .myActivity: L("module.activity")
        case .settings: L("settings.nav_title")
        }
    }
}

/// Sidebar groups — logical, quiet, native.
struct SidebarGroup: Identifiable {
    let id: String
    let title: String?
    let modules: [ModuleID]

    static let all: [SidebarGroup] = [
        SidebarGroup(id: "main", title: nil, modules: [.smartCare]),
        SidebarGroup(id: "storage", title: L("sidebar.storage"),
                     modules: [.cleanup, .spaceLens, .duplicates, .applications]),
        // Secondary, lower-priority tools: each does something the seven
        // primary modules above don't (broken-LaunchAgent detection, a
        // large/old-files finder, local-vs-cloud storage analysis) so they
        // stay reachable rather than deleted, but they aren't part of the
        // compact primary architecture — see Documentation/Audits/
        // SESSION_2026-08-09_AUDIT.md for the redundancy check that led here.
        SidebarGroup(id: "more", title: L("sidebar.more"),
                     modules: [.myClutter, .cloudCleanup, .performance]),
        SidebarGroup(id: "system", title: L("sidebar.system"),
                     modules: [.protection, .myActivity, .settings]),
    ]

    static var visibleModules: [ModuleID] {
        all.flatMap(\.modules)
    }
}

struct MainWindow: View {
    @State private var selection: ModuleID? =
        TestModuleOverride.resolve(environment: ProcessInfo.processInfo.environment) ?? .smartCare
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false
    @State private var showCommandPalette = false
    @State private var showShortcuts = false
    /// Owned here rather than inside Settings so the automatic check runs at
    /// launch. A check that only happens once the user opens the Settings
    /// screen is not an automatic check.
    @State private var updates = UpdatesViewModel()

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: Binding(
                get: { selection ?? .smartCare },
                set: { selection = $0 }))
        } detail: {
            Group {
                switch selection {
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
                case .myClutter:
                    MyClutterView()
                case .cloudCleanup:
                    CloudCleanupView()
                case .myActivity:
                    MyActivityView()
                case .settings:
                    MCSettingsView()
                case nil:
                    // Only reachable before a selection exists; every ModuleID
                    // has a real view. There is no "under construction" state.
                    DashboardView()
                }
            }
            .mcCanvasBackground()
        }
        .onAppear { if !onboardingDone { showOnboarding = true } }
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
            ToolbarItemGroup {
                // Surfaced only when an automatic check actually found
                // something newer. There is no permanent "check for updates"
                // affordance in the toolbar: that belongs in Settings, and a
                // badge that is always present stops meaning anything.
                if case .result(.updateAvailable(let info)) = updates.phase {
                    Button {
                        selection = .settings
                    } label: {
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
        .tint(MCColor.teal)
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
            .action(id: "checkUpdates", label: L("updates.check_now"), icon: "arrow.triangle.2.circlepath") {
                NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.settings)
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
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
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

struct PlaceholderView: View {
    let module: ModuleID

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: module.systemImage)
                .font(.system(size: MCIconSize.emptyState))
                .foregroundStyle(MCTheme.accent)
            Text(module.label).font(MCFont.pageTitle)
            Text(L("placeholder.under_construction"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
