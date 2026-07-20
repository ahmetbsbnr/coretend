import SwiftUI
import DesignSystem
import SystemMetrics
import MalwareEngine
import Persistence

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
            if let image = Self.menuBarImage {
                Image(nsImage: image)
            } else {
                Image(systemName: "circle.hexagonpath")
            }
            Text("MacCare")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Lightweight status popover. Samples only while the menu is open; the
/// sampling loop is a SwiftUI `.task`, which SwiftUI cancels automatically
/// when the view leaves the hierarchy (menu closed) — no separate teardown
/// needed to keep idle CPU low.
struct MenuBarView: View {
    @State private var snapshot: MetricsSnapshot?
    @State private var collector = MetricsCollector()
    @State private var protectionStatus: MenuBarStatus.ProtectionStatus?
    @State private var lastSmartCare: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MacCare Local").font(.headline)
            if let snap = snapshot {
                metricRow(icon: "cpu", label: "CPU", value: "\(Int(snap.cpuUsedFraction * 100))%",
                          warn: snap.cpuUsedFraction > 0.85)
                metricRow(icon: "memorychip", label: "Memory",
                          value: "\(Int(snap.memoryUsedFraction * 100))% — \(snap.memoryPressureLevel)",
                          warn: snap.memoryPressureLevel != "normal")
                metricRow(icon: "internaldrive", label: "Free space",
                          value: mcFormatBytes(snap.diskFreeBytes),
                          warn: snap.diskFreeBytes < 20_000_000_000)
                metricRow(icon: "network", label: "Network",
                          value: "\(mcFormatBytes(snap.networkBytesPerSecond))/s", warn: false)
                metricRow(icon: "thermometer.medium", label: "Thermal",
                          value: snap.thermalState.capitalized,
                          warn: snap.thermalState == "serious" || snap.thermalState == "critical")
            } else {
                ProgressView().controlSize(.small)
            }
            Divider()
            if let protectionStatus {
                metricRow(icon: "shield", label: "Protection", value: protectionStatus.text,
                          warn: protectionStatus.isWarning)
            }
            if let lastSmartCare {
                metricRow(icon: "sparkles", label: "Smart Care", value: lastSmartCare, warn: false)
            }
            Divider()
            Button("Open MacCare Local") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.title == "MacCare Local" }?.makeKeyAndOrderFront(nil)
            }
            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.title == "MacCare Local" }?.makeKeyAndOrderFront(nil)
                NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.settings)
            }
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 280)
        .task {
            let activity: [ActivityRecord] = (try? await AppEnvironment.shared.store?.activity(limit: 50)) ?? []
            protectionStatus = MenuBarStatus.protectionStatus(
                clamAvailable: ClamAVScanner().isAvailable, activity: activity)
            lastSmartCare = MenuBarStatus.lastSmartCareSummary(activity: activity)
            // Adaptive: only samples while this view exists (menu open).
            _ = await collector.snapshot()
            while !Task.isCancelled {
                snapshot = await collector.snapshot()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func metricRow(icon: String, label: String, value: String, warn: Bool) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon).frame(width: 18)
                .foregroundStyle(warn ? MCTheme.warning : MCTheme.accent)
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
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
}

/// Sidebar groups — logical, quiet, native.
struct SidebarGroup: Identifiable {
    let id: String
    let title: String?
    let modules: [ModuleID]

    static let all: [SidebarGroup] = [
        SidebarGroup(id: "care", title: nil, modules: [.smartCare]),
        SidebarGroup(id: "space", title: "Free Up Space",
                     modules: [.cleanup, .myClutter, .spaceLens, .cloudCleanup]),
        SidebarGroup(id: "optimize", title: "Optimize", modules: [.performance, .applications]),
        SidebarGroup(id: "protect", title: "Protect", modules: [.protection]),
        SidebarGroup(id: "track", title: "Activity", modules: [.myActivity, .settings]),
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
                                Text(module.rawValue)
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
        .tint(MCColor.coreMint)
    }
}

struct PlaceholderView: View {
    let module: ModuleID

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: module.systemImage)
                .font(.system(size: 48))
                .foregroundStyle(MCTheme.accent)
            Text(module.rawValue).font(.title2.weight(.semibold))
            Text("This module is under construction. Coming in a later slice.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
