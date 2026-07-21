import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence
import MalwareEngine

@main
struct MacCareApp: App {
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true

    /// Core Bloom menu-bar template (adapts to menu bar appearance).
    static let menuBarImage: NSImage? = {
        guard let path = Bundle.main.path(forResource: "MenuBarTemplate", ofType: "png"),
              let image = NSImage(contentsOfFile: path) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }()

    var body: some Scene {
        WindowGroup("MacCare Local") {
            MainWindow()
                .frame(minWidth: MCSize.windowMinWidth, minHeight: MCSize.windowMinHeight)
        }
        .windowStyle(.automatic)

        MenuBarExtra(isInserted: $menuBarEnabled) {
            MenuBarView()
        } label: {
            MenuBarLabel()
            Text(verbatim: "MacCare")
        }
        .menuBarExtraStyle(.window)
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
            if let image = MacCareApp.menuBarImage {
                Image(nsImage: image)
            } else {
                Image(systemName: "circle.hexagonpath")
            }
            if iconModel.needsAttention {
                // Shape + position carries the meaning, not color alone.
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
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
    private let scanner = ClamAVScanner()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "MacCare Local").font(.headline)
            if let snap = snapshot {
                metricRow(icon: "cpu", label: L("menubar.cpu"), value: "\(Int(snap.cpuUsedFraction * 100))%",
                          warn: snap.cpuUsedFraction > 0.85)
                metricRow(icon: "memorychip", label: L("menubar.memory"),
                          value: "\(Int(snap.memoryUsedFraction * 100))% — \(snap.memoryPressureLevel)",
                          warn: snap.memoryPressureLevel != "normal")
                metricRow(icon: "internaldrive", label: L("menubar.free_space"),
                          value: mcFormatBytes(snap.diskFreeBytes),
                          warn: snap.diskFreeBytes < 20_000_000_000)
                metricRow(icon: "thermometer.medium", label: L("menubar.thermal"),
                          value: snap.thermalState.capitalized,
                          warn: snap.thermalState == "serious" || snap.thermalState == "critical")
            } else {
                ProgressView().controlSize(.small)
            }
            metricRow(icon: "shield", label: L("menubar.protection"),
                      value: scanner.isAvailable ? L("menubar.clamav_ready") : L("menubar.clamav_missing"),
                      warn: !scanner.isAvailable)
            Divider()
            if let last = lastSmartCare {
                Text(L("menubar.last_smart_care", last.summary))
                    .font(.caption).foregroundStyle(.secondary)
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
        .frame(width: 260)
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
        NSApp.windows.first { $0.title == "MacCare Local" }?.makeKeyAndOrderFront(nil)
    }

    private func metricRow(icon: String, label: String, value: String, warn: Bool) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 18)
                .foregroundStyle(warn ? MCTheme.warning : MCTheme.accent)
            Text(label)
            Spacer()
            // Non-color warning signal: a glyph, not just the tinted icon above.
            if warn {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(MCTheme.warning)
                    .accessibilityHidden(true)
            }
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
        .font(.callout)
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
        case .smartCare: L("smartcare.nav_title")
        case .cleanup: L("cleanup.title")
        case .protection: L("module.protection")
        case .performance: L("performance.nav_title")
        case .applications: L("apps.title")
        case .myClutter: L("clutter.title")
        case .spaceLens: L("spacelens.title")
        case .cloudCleanup: L("cloud.nav_title")
        case .myActivity: L("module.my_activity")
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
        SidebarGroup(id: "care", title: nil, modules: [.smartCare]),
        SidebarGroup(id: "space", title: L("sidebar.free_up_space"),
                     modules: [.cleanup, .myClutter, .spaceLens, .cloudCleanup]),
        SidebarGroup(id: "optimize", title: L("sidebar.optimize"), modules: [.performance, .applications]),
        SidebarGroup(id: "protect", title: L("sidebar.protect"), modules: [.protection]),
        SidebarGroup(id: "track", title: L("sidebar.activity"), modules: [.myActivity, .settings]),
    ]
}

struct MainWindow: View {
    @State private var selection: ModuleID? = .smartCare
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarGroup.all) { group in
                    Section {
                        ForEach(group.modules) { module in
                            Label {
                                Text(module.label)
                            } icon: {
                                Image(systemName: module.systemImage)
                                    .foregroundStyle(selection == module ? module.identity.color : Color.secondary)
                            }
                            .tag(module)
                        }
                    } header: {
                        if let title = group.title {
                            Text(title)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: MCSize.sidebarMin, ideal: MCSize.sidebarIdeal)
        } detail: {
            switch selection {
            case .smartCare:
                SmartCareView()
            case .cleanup:
                CleanupView()
            case .protection:
                ProtectionView()
            case .applications:
                ApplicationsView()
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
        .onAppear { if !onboardingDone { showOnboarding = true } }
        .sheet(isPresented: $showOnboarding, onDismiss: { onboardingDone = true }) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcNavigate)) { note in
            if let module = note.object as? ModuleID { selection = module }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcShowOnboarding)) { _ in
            showOnboarding = true
        }
        .tint(MCColor.coreMint)
    }
}

struct PlaceholderView: View {
    let module: ModuleID

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: module.systemImage)
                .font(.system(size: MCIconSize.emptyState))
                .foregroundStyle(MCTheme.accent)
            Text(module.label).font(.title2.weight(.semibold))
            Text(L("placeholder.under_construction"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
