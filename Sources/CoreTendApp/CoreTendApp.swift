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
    @State private var lastSmartCare: ActivityRecord?

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
            if let last = lastSmartCare {
                Text(L("menubar.last_smart_care", last.summary))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(last.date, style: .relative)
                    .font(.caption2).foregroundStyle(.tertiary)
            } else {
                Text(L("menubar.no_smart_care_yet"))
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
            lastSmartCare = recent.first { $0.summary.hasPrefix("Smart Care") }
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
    @State private var selection: ModuleID? = .smartCare
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false
    @State private var showCommandPalette = false

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
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MCColor.secondaryBackground)
            .listStyle(.sidebar)
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
            .mcCanvasBackground()
        }
        .onAppear { if !onboardingDone { showOnboarding = true } }
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
                    Label(L("palette.open"), systemImage: "command")
                }
                .help(L("palette.open"))
            }
        }
        .background(MCColor.background)
        .tint(MCColor.teal)
    }

    private func sidebarRow(_ module: ModuleID) -> some View {
        let isSelected = selection == module
        return Label {
            Text(module.label)
                .font(.callout.weight(isSelected ? .semibold : .regular))
        } icon: {
            Image(systemName: module.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? MCColor.teal : Color.secondary)
                .frame(width: 20)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 2)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: MCRadius.small)
                    .fill(MCColor.teal.opacity(0.12))
            }
        }
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
