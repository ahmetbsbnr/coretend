import SwiftUI
import DesignSystem

@main
struct MacCareApp: App {
    var body: some Scene {
        WindowGroup("MacCare Local") {
            MainWindow()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.automatic)
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
    @State private var selection: ModuleID? = .cleanup

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
            case .performance:
                PerformanceView()
            case .spaceLens:
                SpaceLensView()
            case .myClutter:
                MyClutterView()
            case .myActivity:
                MyActivityView()
            case .settings:
                MCSettingsView()
            default:
                PlaceholderView(module: selection ?? .smartCare)
            }
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
