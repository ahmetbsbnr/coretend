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
        // Byte counts / numbers follow the in-app language override, not the
        // process locale. Set before any UI (incl. the menu bar) renders.
        MCFormatting.locale = LocalizationManager.locale
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
        WindowGroup("CoreTend", id: "main") {
            MainWindow()
                .frame(minWidth: MCSize.windowMinWidth, minHeight: MCSize.windowMinHeight)
                .id(appLanguageRaw)
                // The Finder Sync extension hands a selected path to the app
                // as a `coretend://finder/…` URL. Untrusted — `FinderHandoff`
                // re-validates it against the live filesystem before routing.
                .onOpenURL { FinderHandoff.handle($0) }
                .alert(L("finder.selection_unavailable"), isPresented: Binding(
                    get: { AppRouter.shared.finderSelectionRejected },
                    set: { AppRouter.shared.finderSelectionRejected = $0 }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(L("finder.selection_unavailable.detail"))
                }
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
    case timeline = "Timeline"
    case recoveryPlan = "Recovery Plan"
    case apfs = "APFS"
    case developer = "Developer"
    case privacyLab = "Privacy Lab"
    case restoreCenter = "Restore Center"
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
        case .timeline: .timeline
        case .recoveryPlan: .recoveryPlan
        case .apfs: .apfs
        case .developer: .developer
        case .privacyLab: .privacyLab
        case .restoreCenter: .restoreCenter
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
        case .timeline: L("module.timeline")
        case .recoveryPlan: L("module.recovery_plan")
        case .apfs: L("module.apfs")
        case .developer: L("module.developer")
        case .privacyLab: L("module.privacy_lab")
        case .restoreCenter: L("module.restore_center")
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
                     modules: [.cleanup, .spaceLens, .duplicates, .applications, .developer, .timeline, .recoveryPlan, .apfs]),
        // Secondary, lower-priority tools: each does something the seven
        // primary modules above don't (broken-LaunchAgent detection, a
        // large/old-files finder, local-vs-cloud storage analysis) so they
        // stay reachable rather than deleted, but they aren't part of the
        // compact primary architecture — see Documentation/Audits/
        // SESSION_2026-08-09_AUDIT.md for the redundancy check that led here.
        SidebarGroup(id: "more", title: L("sidebar.more"),
                     modules: [.myClutter, .cloudCleanup, .performance]),
        SidebarGroup(id: "system", title: L("sidebar.system"),
                     modules: [.privacyLab, .protection, .myActivity, .restoreCenter, .settings]),
    ]

    static var visibleModules: [ModuleID] {
        all.flatMap(\.modules)
    }
}

struct MainWindow: View {
    @Environment(\.openWindow) private var openWindow
    @State private var developerModel = DeveloperCenterModel()
    /// App/window-scope: a Smart Scan started from the Dashboard survives the
    /// user navigating to another module and back (the Dashboard view is torn
    /// down and rebuilt; this model is not).
    @State private var smartScan = SmartScanModel()
    @State private var selection: ModuleID? = .smartCare
    /// Pinned to `.all`. Some detail views (a `List`/`Table` heavy layout,
    /// notably Duplicates) could momentarily report a zero-width detail on
    /// macOS 14 and the split view would then collapse the sidebar into an
    /// empty column. Owning the visibility and never letting it leave `.all`
    /// keeps the two columns stable regardless of what the detail renders.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false
    @State private var showCommandPalette = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                ForEach(SidebarGroup.all) { group in
                    Section {
                        ForEach(group.modules) { module in
                            sidebarRow(module)
                            .tag(module)
                            // Suppress the system list-selection fill so the
                            // ONLY selection indicator is sidebarRow's own
                            // teal marker — which is driven by `selection ==
                            // module`, not by list focus. Without this, moving
                            // focus into a detail view (e.g. selecting a Space
                            // Lens bubble) turns the system fill grey and the
                            // active module reads as "greyed out".
                            .listRowBackground(Color.clear)
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
                    DashboardView(smartScan: smartScan)
                case .cleanup:
                    CleanupView()
                case .protection:
                    ProtectionView()
                case .applications:
                    ApplicationsView()
                case .duplicates:
                    DuplicatesView()
                case .timeline:
                    StorageTimelineView()
                case .recoveryPlan:
                    RecoveryPlanView()
                case .apfs:
                    APFSIntelligenceView()
                case .developer:
                    DeveloperCenterView(model: developerModel)
                case .privacyLab:
                    PrivacyLabView()
                case .restoreCenter:
                    RestoreCenterView()
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
            // CoreTend's own header band: the command-palette trigger lives
            // here, trailing-aligned with the page content, NOT jammed into
            // the extreme top-right macOS toolbar slot against the rounded
            // window corner. One placement, every module.
            .safeAreaInset(edge: .top, spacing: 0) { paletteHeader }
            .mcCanvasBackground()
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: columnVisibility) { _, newValue in
            // Never let a detail view push the sidebar away.
            if newValue != .all { columnVisibility = .all }
        }
        .onAppear {
            // Re-runs on a language change (the window has `.id(appLanguageRaw)`),
            // so byte/number formatting follows the new choice immediately.
            MCFormatting.locale = LocalizationManager.locale
            if !onboardingDone { showOnboarding = true }
            // Start the macOS integration layer (background scan scheduler,
            // notification tap routing). Idempotent.
            MacIntegrations.shared.start()
            AppRouter.shared.openMainWindow = { openWindow(id: "main") }
            // Drain any deep link that arrived before this window subscribed
            // to `.mcNavigate` (cold launch from a notification / App Intent
            // / Finder Sync action). The sidebar selection is switched here;
            // a Finder route's URL payload is left for the destination view
            // (Space Lens / Privacy Lab / Integrity) to consume on appear.
            if let route = AppRouter.shared.markReceiverReady() {
                selection = AppRouter.module(for: route)
            }
        }
        .onDisappear { AppRouter.shared.markReceiverUnavailable() }
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
            openCommandPalette()
        }
        .background(MCColor.background)
        .tint(MCColor.teal)
        // Transient overlay, NOT a `.sheet`: a document-modal sheet is a
        // no-op on an outside click. This overlay's backdrop consumes the
        // dismissal click (so it never activates the control underneath) and
        // closes the palette; the panel itself stays interactive.
        .overlay {
            if showCommandPalette {
                CommandPaletteOverlay(isPresented: $showCommandPalette, reduceMotion: reduceMotion)
                    .transition(.opacity)
            }
        }
    }

    private func openCommandPalette() {
        withAnimation(reduceMotion ? nil : .snappy) { showCommandPalette = true }
    }

    /// The header band injected above every module's detail content. Holds
    /// only the command-palette trigger, right-aligned to the page gutter.
    private var paletteHeader: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button {
                openCommandPalette()
            } label: {
                Image(systemName: "command")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(MCColor.elevatedBackground, in: Circle())
                    .overlay(Circle().strokeBorder(MCColor.separator.opacity(0.8), lineWidth: 1))
            }
            .buttonStyle(.plain)
            // ⌘K is owned by the menu command in `CoreTendHelpCommands`
            // (which posts `.mcShowCommandPalette`); not re-bound here to
            // avoid a duplicate-shortcut conflict.
            .help(L("palette.open.a11y"))
            .accessibilityLabel(L("palette.open.a11y"))
            .accessibilityIdentifier("commandPalette.trigger")
        }
        .padding(.trailing, MCSpacing.page)
        .padding(.top, MCSpacing.sm)
        .padding(.bottom, MCSpacing.xs)
        .frame(maxWidth: .infinity)
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

/// The palette's transient presentation: a dimmed, hit-testing backdrop with
/// the search panel floating near the top. NOT a `.sheet` — a document-modal
/// sheet ignores an outside click. Here:
///  - the backdrop is a filled, hit-testable view: an outside click lands on
///    it, is *consumed* (never reaches the control beneath — no click-
///    through), and closes the palette;
///  - the panel sits above the backdrop and stays fully interactive;
///  - Escape is owned in exactly one place (`.onExitCommand` here).
struct CommandPaletteOverlay: View {
    @Binding var isPresented: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.18))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { close() }
                .accessibilityLabel(L("palette.close.a11y"))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("commandPalette.backdrop")

            CommandPaletteView(isPresented: $isPresented)
                .padding(.top, MCSpacing.xxl)
        }
        // The single Escape owner. `.onExitCommand` handles `cancelOperation:`
        // from anywhere in the responder chain, including the focused search
        // field, so it fires regardless of focus.
        .onExitCommand { close() }
    }

    private func close() {
        withAnimation(reduceMotion ? nil : .snappy) { isPresented = false }
    }
}

/// Fuzzy-filtered jump list over every sidebar destination, plus a handful
/// of actions — dispatched through the same NotificationCenter routing the
/// sidebar and Help-menu commands already use, not a second navigation
/// system. Deliberately not a general "search everything" index (see
/// GRAPHIFY_MAPS.md / the workspace audit for why that's a separate,
/// larger undertaking, not folded into this).
struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            HStack(spacing: MCSpacing.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(L("palette.placeholder"), text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { activate(filtered.first) }
                    .accessibilityLabel(L("palette.placeholder"))
                    .accessibilityIdentifier("commandPalette.search")
                // Pointer dismiss affordance. Escape is owned by the
                // overlay's `.onExitCommand`, so no key shortcut here.
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L("palette.close.a11y"))
                .accessibilityLabel(L("palette.close.a11y"))
                .accessibilityIdentifier("commandPalette.close")
            }
            .padding(MCSpacing.sm)
            Divider()
            if filtered.isEmpty {
                MCEmptyState(icon: "magnifyingglass", title: L("palette.no_results"), message: "")
                    .frame(height: 180)
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
                .frame(minHeight: 120, maxHeight: 320)
            }
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        // Opaque panel chrome so it reads as a floating surface AND so any
        // click on the panel (incl. its empty regions) is consumed here and
        // never falls through to the dismissal backdrop.
        .background(MCColor.elevatedBackground, in: RoundedRectangle(cornerRadius: MCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: MCRadius.card)
            .strokeBorder(MCColor.separator.opacity(0.8), lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: MCRadius.card))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("commandPalette.panel")
        .task {
            // The overlay opens inside a `withAnimation`, so at `onAppear`
            // its hosting view is not yet in the key window's responder
            // chain and a direct `searchFocused = true` is dropped (the
            // search field never gets the caret — keyboard-driven palette
            // is dead). Deferring one runloop turn lets the focus land.
            try? await Task.sleep(for: .milliseconds(50))
            searchFocused = true
        }
    }

    private func dismiss() {
        query = ""
        withAnimation(reduceMotion ? nil : .snappy) { isPresented = false }
    }

    private func activate(_ entry: Entry?) {
        guard let entry else { return }
        switch entry {
        case let .module(m): NotificationCenter.default.post(name: .mcNavigate, object: m)
        case let .action(_, _, _, perform): perform()
        }
        dismiss()
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
