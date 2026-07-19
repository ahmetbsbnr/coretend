import SwiftUI
import DesignSystem
import SystemMetrics

@main
struct MacCareApp: App {
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true

    var body: some Scene {
        WindowGroup("MacCare Local") {
            MainWindow()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.automatic)

        MenuBarExtra("MacCare", systemImage: "heart.circle", isInserted: $menuBarEnabled) {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}

/// Lightweight status popover. Samples only while the menu is open.
struct MenuBarView: View {
    @State private var snapshot: MetricsSnapshot?
    @State private var collector = MetricsCollector()

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
                metricRow(icon: "thermometer.medium", label: "Thermal",
                          value: snap.thermalState.capitalized,
                          warn: snap.thermalState == "serious" || snap.thermalState == "critical")
            } else {
                ProgressView().controlSize(.small)
            }
            Divider()
            Button("Open MacCare Local") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.title == "MacCare Local" }?.makeKeyAndOrderFront(nil)
            }
            Button("Quit") { NSApp.terminate(nil) }
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
    }

    private func metricRow(icon: String, label: String, value: String, warn: Bool) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 18)
                .foregroundStyle(warn ? MCTheme.warning : MCTheme.accent)
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
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

    var systemImage: String {
        switch self {
        case .smartCare: "heart.text.square"
        case .cleanup: "sparkles"
        case .protection: "shield"
        case .performance: "gauge.with.needle"
        case .applications: "square.grid.2x2"
        case .myClutter: "doc.on.doc"
        case .spaceLens: "circle.hexagongrid"
        case .cloudCleanup: "icloud"
        case .myActivity: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

struct MainWindow: View {
    @State private var selection: ModuleID? = .smartCare
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationSplitView {
            List(ModuleID.allCases, selection: $selection) { module in
                Label(module.rawValue, systemImage: module.systemImage)
                    .tag(module)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: MCTheme.sidebarWidth)
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
