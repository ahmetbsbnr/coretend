import SwiftUI
import AppDiscovery
import SafetyCore
import DesignSystem
import Persistence

@MainActor
@Observable
final class ApplicationsViewModel {
    enum Phase: Equatable { case loading, ready, empty }

    var phase: Phase = .loading
    var apps: [InstalledApp] = []
    var searchText = ""
    var selectedApp: InstalledApp?
    var associated: [AssociatedItem] = []
    var selectedAssociatedPaths: Set<String> = []
    var uninstallResult: String?
    var dryRun = true

    private let discovery = AppDiscovery()

    var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func load() async {
        phase = .loading
        let discovery = discovery
        let found = await Task.detached(priority: .utility) { discovery.discoverApps() }.value
        apps = found
        phase = found.isEmpty ? .empty : .ready
    }

    func select(_ app: InstalledApp) async {
        selectedApp = app
        uninstallResult = nil
        associated = []
        selectedAssociatedPaths = []
        guard let bundleID = app.bundleIdentifier else { return }
        let discovery = discovery
        let items = await Task.detached(priority: .utility) { discovery.associatedItems(bundleID: bundleID) }.value
        associated = items
        // Preselect only reversible support data; the app bundle itself is always included.
        selectedAssociatedPaths = Set(items.filter { $0.kind == .caches || $0.kind == .savedState }.map(\.url.path))
    }

    /// Moves the app bundle and approved associated items to the Trash.
    func uninstall() async {
        guard let app = selectedApp else { return }
        let items = associated.filter { selectedAssociatedPaths.contains($0.url.path) }
        let home = FileManager.default.homeDirectoryForCurrentUser
        var allowedRoots: [URL] = [app.path.deletingLastPathComponent()]
        allowedRoots.append(home.appendingPathComponent("Library"))
        let center = SafetyCenter(validator: PathValidator(allowedRoots: allowedRoots), dryRun: dryRun)
        var approved: [ApprovedFileOperation] = []
        if let op = try? await center.approve(url: app.path, logicalSize: app.sizeBytes,
                                              ruleID: "apps.uninstall", risk: .medium) {
            approved.append(op)
        }
        for item in items {
            if let op = try? await center.approve(url: item.url, logicalSize: item.sizeBytes,
                                                  ruleID: "apps.uninstall.associated", risk: .medium) {
                approved.append(op)
            }
        }
        let result = await center.execute(approved)
        let freed = result.executed.reduce(0) { $0 + $1.logicalSize }
        uninstallResult = result.wasDryRun
            ? "Dry run: \(result.executed.count) items (\(mcFormatBytes(freed))) would move to Trash"
            : "Moved \(result.executed.count) items (\(mcFormatBytes(freed))) to Trash"
        AppEnvironment.shared.record(ActivityRecord(
            kind: .cleanup,
            summary: "\(result.wasDryRun ? "Dry run uninstall" : "Uninstalled") \(app.name)",
            itemCount: result.executed.count, bytes: freed, dryRun: result.wasDryRun))
        if !result.wasDryRun { await load() }
    }
}

struct ApplicationsView: View {
    var body: some View {
        TabView {
            InstalledAppsView()
                .tabItem { Label("Installed", systemImage: "square.grid.2x2") }
            LeftoversView()
                .tabItem { Label("Leftovers", systemImage: "trash.slash") }
            AppUpdatesView()
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
        }
        .padding(8)
        .navigationTitle("Applications")
    }
}

struct InstalledAppsView: View {
    @State private var model = ApplicationsViewModel()

    var body: some View {
        HSplitView {
            appList
                .frame(minWidth: 280)
            detail
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await model.load() }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            TextField("Search apps", text: $model.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(8)
            switch model.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                Text("No applications found").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                List(model.filteredApps, selection: Binding(
                    get: { model.selectedApp?.id },
                    set: { id in
                        if let app = model.apps.first(where: { $0.id == id }) {
                            Task { await model.select(app) }
                        }
                    }
                )) { app in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                            .resizable().frame(width: 28, height: 28)
                        VStack(alignment: .leading) {
                            Text(app.name)
                            Text(app.version ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(mcFormatBytes(app.sizeBytes))
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .tag(app.id)
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let app = model.selectedApp {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                            .resizable().frame(width: 56, height: 56)
                        VStack(alignment: .leading) {
                            Text(app.name).font(.title2.weight(.semibold))
                            Text(app.bundleIdentifier ?? "unknown bundle id")
                                .font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                if let version = app.version { Text("v\(version)") }
                                if !app.architectures.isEmpty {
                                    Text(app.architectures.joined(separator: ", "))
                                }
                                Text(mcFormatBytes(app.sizeBytes))
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    MCCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Associated data").font(.headline)
                            if model.associated.isEmpty {
                                Text("No associated files found for this bundle identifier.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(model.associated) { item in
                                HStack {
                                    Toggle("", isOn: Binding(
                                        get: { model.selectedAssociatedPaths.contains(item.url.path) },
                                        set: { on in
                                            if on { model.selectedAssociatedPaths.insert(item.url.path) }
                                            else { model.selectedAssociatedPaths.remove(item.url.path) }
                                        }
                                    ))
                                    .labelsHidden()
                                    VStack(alignment: .leading) {
                                        Text(item.kind.rawValue)
                                        Text(item.url.path).font(.caption).foregroundStyle(.secondary)
                                            .lineLimit(1).truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(mcFormatBytes(item.sizeBytes))
                                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Toggle("Dry run", isOn: $model.dryRun).toggleStyle(.switch)
                        Button(model.dryRun ? "Simulate Uninstall" : "Uninstall (move to Trash)", role: .destructive) {
                            Task { await model.uninstall() }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([app.path])
                        }
                    }
                    if let result = model.uninstallResult {
                        Text(result).font(.callout).foregroundStyle(MCTheme.accent)
                    }
                }
                .padding(20)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 48)).foregroundStyle(MCTheme.accent)
                Text("Select an application").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
