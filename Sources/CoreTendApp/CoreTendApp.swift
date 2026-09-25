// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence

/// A per-process appearance override used only by the isolated artifact
/// harness. It requires the same validated two-key test marker as the store and
/// filesystem fixtures, so normal launches always continue to follow macOS.
enum TestAppearanceOverride {
    static func resolve(environment: [String: String]) -> NSAppearance.Name? {
        guard TestStoreOverride.isTestMarkerSet(environment: environment),
              TestStoreOverride.resolve(environment: environment).directory != nil
        else { return nil }

        switch environment["CORETEND_TEST_APPEARANCE"]?.lowercased() {
        case "light": return .aqua
        case "dark": return .darkAqua
        default: return nil
        }
    }

    @MainActor
    static func apply(environment: [String: String]) {
        guard let name = resolve(environment: environment) else { return }
        NSApplication.shared.appearance = NSAppearance(named: name)
    }
}

public struct CoreTendApp: App {
    public init() {
        TestAppearanceOverride.apply(environment: ProcessInfo.processInfo.environment)
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
        CommandGroup(replacing: .help) {
            Button("CoreTend Help") {
                NSWorkspace.shared.open(site.appending(path: "support#documentation"))
            }
            Button("Installation Help") {
                NSWorkspace.shared.open(site.appending(path: "support"))
            }
            Button("Keyboard Shortcuts") {
                NSWorkspace.shared.open(site.appending(path: "support"))
            }
            Divider()
            Button("Report an Issue") {
                NSWorkspace.shared.open(repository.appending(path: "issues"))
            }
            Button("Security") {
                NSWorkspace.shared.open(site.appending(path: "support#security"))
            }
            Button("About CoreTend") {
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
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            MCHairline()
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                if let snap = snapshot {
                    gaugeRow(L("menubar.cpu"), fraction: snap.cpuUsedFraction,
                             value: "\(Int(snap.cpuUsedFraction * 100))%",
                             warn: snap.cpuUsedFraction > 0.85)
                    gaugeRow(L("menubar.memory"), fraction: snap.memoryUsedFraction,
                             value: "\(Int(snap.memoryUsedFraction * 100))% · \(snap.memoryPressureLevel)",
                             warn: snap.memoryPressureLevel != "normal")
                    gaugeRow(L("menubar.free_space"), fraction: snap.diskUsedFraction,
                             value: mcFormatBytes(snap.diskFreeBytes),
                             warn: snap.diskFreeBytes < 20_000_000_000)
                    MCKeyValueRow(L("menubar.thermal"), value: snap.thermalState.capitalized,
                                  status: isThermalWarn(snap) ? .attention : nil)
                } else {
                    HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }
                        .padding(.vertical, MCSpacing.lg)
                }
            }
            .padding(14)
            MCHairline()
            VStack(alignment: .leading, spacing: 2) {
                if let last = lastActivity {
                    Text(L("menubar.last_activity", last.summary))
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(last.date, style: .relative)
                        .font(MCFont.badge).foregroundStyle(.tertiary)
                } else {
                    Text(L("menubar.no_activity_yet"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            MCHairline()
            VStack(spacing: 0) {
                menuAction(L("menubar.open_app"), icon: "macwindow") { openWindow() }
                menuAction(L("menubar.settings"), icon: "gearshape") {
                    openWindow()
                    NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.settings)
                }
                menuAction(L("menubar.quit"), icon: "power") { NSApp.terminate(nil) }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 300)
        .background(MCColor.background)
        .tint(MCColor.teal)
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

    private var needsAttention: Bool {
        guard let snap = snapshot else { return false }
        return MenuBarIconModel.needsAttention(
            thermalState: snap.thermalState,
            memoryPressureLevel: snap.memoryPressureLevel,
            diskFreeBytes: snap.diskFreeBytes)
    }

    private var header: some View {
        HStack(spacing: MCSpacing.xs) {
            CoreBloomMark(tint: [MCColor.teal], lineWidthFraction: 0.1)
                .frame(width: 18, height: 18)
            Text(verbatim: "CoreTend").font(MCFont.cardTitle)
            Spacer(minLength: 0)
            if snapshot != nil {
                MCStatusBadge(needsAttention ? L("menubar.status_attention") : L("menubar.status_ok"),
                              status: needsAttention ? .attention : .success)
            }
        }
    }

    private func isThermalWarn(_ snap: MetricsSnapshot) -> Bool {
        snap.thermalState == "serious" || snap.thermalState == "critical"
    }

    private func openWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title == "CoreTend" }?.makeKeyAndOrderFront(nil)
    }

    private func menuAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: MCSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title).font(MCFont.secondaryBody)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 28)
        }
        .buttonStyle(.mcRow)
    }

    /// Metric with a segmented meter — for the 0…1 gauges (CPU, memory, disk).
    private func gaugeRow(_ label: String, fraction: Double, value: String, warn: Bool) -> some View {
        let tint: Color = warn ? MCTheme.warning : MCTheme.accent
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: MCSpacing.xs) {
                MCEyebrow(label)
                Spacer(minLength: MCSpacing.xs)
                if warn {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(MCTheme.warning)
                        .accessibilityHidden(true)
                }
                Text(value)
                    .font(MCFont.mono)
                    .foregroundStyle(.primary)
            }
            MCMeter(fraction: fraction, tint: tint, segments: 32, height: 5)
        }
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

/// Sidebar groups — organised by the job the user came to do, not by
/// implementation module: get space back, look after apps and the system,
/// then the workspace itself (history and settings).
struct SidebarGroup: Identifiable {
    let id: String
    let title: String?
    let modules: [ModuleID]

    static let all: [SidebarGroup] = [
        SidebarGroup(id: "main", title: nil, modules: [.smartCare]),
        // Everything that finds bytes to give back, most general first:
        // rule-based junk, the map, exact copies, then the finer-grained
        // large/old and cloud-state finders (kept reachable — see
        // Documentation/Audits/SESSION_2026-08-09_AUDIT.md).
        SidebarGroup(id: "reclaim", title: L("sidebar.reclaim"),
                     modules: [.cleanup, .spaceLens, .duplicates, .myClutter, .cloudCleanup]),
        SidebarGroup(id: "system", title: L("sidebar.apps_system"),
                     modules: [.applications, .performance, .protection]),
        SidebarGroup(id: "workspace", title: L("sidebar.history"),
                     modules: [.myActivity, .settings]),
    ]

    static var visibleModules: [ModuleID] {
        all.flatMap(\.modules)
    }
}

/// Startup-disk reading for the sidebar footer. Samples slowly (the value
/// changes on the scale of minutes) and only while the window exists.
@MainActor
@Observable
final class SidebarDiskModel {
    var freeBytes: Int64?
    var totalBytes: Int64 = 0
    var usedFraction: Double = 0
    private let collector = MetricsCollector()

    func run() async {
        while !Task.isCancelled {
            let snap = await collector.snapshot()
            freeBytes = snap.diskFreeBytes
            totalBytes = snap.diskTotalBytes
            usedFraction = snap.diskUsedFraction
            try? await Task.sleep(for: .seconds(60))
        }
    }
}

struct MainWindow: View {
    @State private var selection: ModuleID? = .smartCare
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false
    @State private var showCommandPalette = false
    @State private var disk = SidebarDiskModel()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarGroup.all) { group in
                    Section {
                        ForEach(group.modules) { module in
                            sidebarRow(module)
                            .tag(module)
                            .accessibilityIdentifier("sidebar.\(module.rawValue)")
                        }
                    } header: {
                        if let title = group.title {
                            Text(title)
                                .font(MCFont.eyebrow)
                                .textCase(.uppercase)
                                .kerning(MCTracking.label)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MCColor.secondaryBackground)
            .listStyle(.sidebar)
            .safeAreaInset(edge: .top, spacing: 0) { sidebarHeader }
            .safeAreaInset(edge: .bottom, spacing: 0) { sidebarFooter }
            .navigationSplitViewColumnWidth(min: MCSize.sidebarMin, ideal: MCSize.sidebarIdeal)
            .accessibilityIdentifier("sidebar.list")
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
                default:
                    PlaceholderView(module: selection ?? .smartCare)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mcCanvasBackground()
        }
        .onAppear { if !onboardingDone { showOnboarding = true } }
        .task { await disk.run() }
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
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView(isPresented: $showCommandPalette)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showCommandPalette = true
                } label: {
                    Label(L("palette.open"), systemImage: "magnifyingglass")
                }
                .help(L("palette.open") + " ⌘K")
            }
        }
        .background(MCColor.background)
        .tint(MCColor.teal)
    }

    // MARK: Sidebar chrome

    /// Brand lockup and the search/jump field. The field is a button that
    /// opens the command palette — one search model for the whole app.
    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: MCSpacing.sm) {
            HStack(spacing: MCSpacing.xs) {
                CoreBloomMark(tint: [MCColor.teal], lineWidthFraction: 0.1)
                    .frame(width: 20, height: 20)
                Text(verbatim: "CoreTend")
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
                Text(verbatim: AppMetadata.marketingVersion)
                    .font(MCFont.badge)
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            Button {
                showCommandPalette = true
            } label: {
                HStack(spacing: MCSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(L("sidebar.search"))
                        .font(MCFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    MCKeycap("⌘K")
                }
                .padding(.leading, MCSpacing.xs)
                .padding(.trailing, 4)
                .frame(height: 28)
                .background(MCColor.elevatedBackground, in: RoundedRectangle(cornerRadius: MCRadius.control))
                .overlay(RoundedRectangle(cornerRadius: MCRadius.control)
                    .strokeBorder(MCColor.separator, lineWidth: 1))
            }
            .buttonStyle(MCPressStyle())
            .accessibilityLabel(L("palette.open"))
            .accessibilityIdentifier("sidebar.search")
        }
        .padding(.horizontal, MCSpacing.sm)
        .padding(.top, MCSpacing.xs)
        .padding(.bottom, MCSpacing.xs)
    }

    /// Always-visible startup-disk reading: the one number a care utility
    /// should never make the user hunt for. Clicking it opens Space Lens.
    private var sidebarFooter: some View {
        Button {
            selection = .spaceLens
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    MCEyebrow(L("sidebar.disk_label"))
                    Spacer(minLength: 0)
                    Image(systemName: "internaldrive")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                if let free = disk.freeBytes {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(L("sidebar.disk_free", mcFormatBytes(free)))
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                        Text(L("sidebar.disk_of", mcFormatBytes(disk.totalBytes)))
                            .font(MCFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    MCMeter(fraction: disk.usedFraction,
                            tint: free < 20_000_000_000 ? MCTheme.warning : MCTheme.accent,
                            segments: 24, height: 5)
                } else {
                    MCMeter(fraction: 0, segments: 24, height: 5)
                }
            }
            .padding(MCSpacing.sm)
            .background(MCColor.elevatedBackground, in: RoundedRectangle(cornerRadius: MCRadius.card))
            .overlay(RoundedRectangle(cornerRadius: MCRadius.card).strokeBorder(MCColor.separator, lineWidth: 1))
        }
        .buttonStyle(MCPressStyle())
        .padding(MCSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sidebar.disk")
    }

    private func sidebarRow(_ module: ModuleID) -> some View {
        let isSelected = selection == module
        return Label {
            Text(module.label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
        } icon: {
            Image(systemName: module.systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? MCColor.teal : Color.secondary)
                .frame(width: 18)
        }
        .padding(.vertical, 2)
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
///
/// Fully keyboard-driven: ↑/↓ move the highlight, ↩ opens it, esc closes.
private struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var highlighted = 0
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

        var isAction: Bool {
            if case .action = self { return true }
            return false
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
        let results = filtered
        VStack(spacing: 0) {
            HStack(spacing: MCSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MCColor.teal)
                TextField(L("palette.placeholder"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($searchFocused)
                    .onSubmit { activate(results.indices.contains(highlighted) ? Optional(results[highlighted]) : results.first) }
                    .onKeyPress(.downArrow) { move(1, count: results.count); return .handled }
                    .onKeyPress(.upArrow) { move(-1, count: results.count); return .handled }
                    .accessibilityIdentifier("commandPalette.search")
            }
            .padding(.horizontal, MCSpacing.md)
            .frame(height: 54)
            MCHairline()
            if results.isEmpty {
                MCEmptyState(icon: "magnifyingglass", title: L("palette.no_results"), message: "")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, entry in
                                if index == 0 || results[index - 1].isAction != entry.isAction {
                                    MCEyebrow(entry.isAction ? L("palette.section.actions") : L("palette.section.go_to"))
                                        .padding(.horizontal, MCSpacing.sm)
                                        .padding(.top, index == 0 ? MCSpacing.xs : MCSpacing.sm)
                                        .padding(.bottom, 4)
                                }
                                row(entry, isHighlighted: index == highlighted)
                                    .id(entry.id)
                                    .onHover { if $0 { highlighted = index } }
                            }
                        }
                        .padding(MCSpacing.xs)
                    }
                    .onChange(of: highlighted) { _, new in
                        if results.indices.contains(new) { proxy.scrollTo(results[new].id) }
                    }
                }
            }
            MCHairline()
            HStack(spacing: MCSpacing.md) {
                hint("↑↓", L("palette.hint.move"))
                hint("↩", L("palette.hint.open"))
                hint("esc", L("palette.hint.close"))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MCSpacing.md)
            .frame(height: 34)
            .background(MCColor.secondaryBackground)
        }
        .frame(width: 520, height: 420)
        .background(MCColor.elevatedBackground)
        .onAppear { searchFocused = true }
        .onChange(of: query) { _, _ in highlighted = 0 }
        .onKeyPress(.escape) { isPresented = false; return .handled }
    }

    private func row(_ entry: Entry, isHighlighted: Bool) -> some View {
        Button {
            activate(entry)
        } label: {
            HStack(spacing: MCSpacing.sm) {
                MCIconTile(entry.icon, tint: isHighlighted ? MCColor.teal : .secondary, size: 26)
                Text(entry.label)
                    .font(.system(size: 13, weight: isHighlighted ? .medium : .regular))
                Spacer(minLength: 0)
                if isHighlighted {
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, MCSpacing.xs)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: MCRadius.control)
                .fill(isHighlighted ? MCColor.accentWash : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(entry.id)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            MCKeycap(key)
            Text(label).font(MCFont.caption).foregroundStyle(.secondary)
        }
    }

    private func move(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        highlighted = (highlighted + delta + count) % count
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
        MCEmptyState(icon: module.systemImage, title: module.label,
                     message: L("placeholder.under_construction"),
                     iconColor: MCTheme.accent, iconSize: MCIconSize.emptyState)
    }
}
