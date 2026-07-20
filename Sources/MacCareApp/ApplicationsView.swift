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
    @State private var showConstellation = false

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
            if model.phase == .ready {
                Picker("View", selection: $showConstellation) {
                    Text("List").tag(false)
                    Text("Constellation").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
            if showConstellation, model.phase == .ready {
                ScrollView {
                    AppConstellationView(apps: model.filteredApps) { app in
                        Task { await model.select(app) }
                    }
                    .padding(8)
                }
            } else {
                installedListBody
            }
        }
    }

    private var installedListBody: some View {
        Group {
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
                            if app.isDataLocationAmbiguous {
                                Label("Data location ambiguous — no bundle identifier to match against",
                                      systemImage: "exclamationmark.triangle")
                                    .font(.caption).foregroundStyle(MCTheme.warning)
                            }
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

/// Applications' visual layer: apps as capsules grouped into a constellation
/// by publisher/size/update-state/last-used. Sits alongside the native list —
/// never replaces it. Capsule width encodes real byte weight within its
/// group; color encodes update state; a ring flags ambiguous data location.
/// No timers, no motion at rest — layout only, so Reduce Motion has nothing
/// to reduce.
struct AppConstellationView: View {
    let apps: [InstalledApp]
    var onSelect: (InstalledApp) -> Void

    @State private var mode: AppGroupMode = .publisher
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var groups: [(label: String, apps: [InstalledApp])] {
        AppGrouping.grouped(apps, by: mode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            Picker("Group by", selection: $mode) {
                ForEach(AppGroupMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 220)

            ForEach(groups, id: \.label) { group in
                VStack(alignment: .leading, spacing: MCSpacing.xs) {
                    Text(group.label)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityLabel(AppGrouping.accessibilityDescription(label: group.label, apps: group.apps))
                    FlowLayout(spacing: MCSpacing.xs) {
                        ForEach(group.apps) { app in
                            capsule(for: app, groupMaxBytes: group.apps.map(\.sizeBytes).max() ?? 1)
                        }
                    }
                }
            }
        }
    }

    private func capsule(for app: InstalledApp, groupMaxBytes: Int64) -> some View {
        let weight = groupMaxBytes > 0 ? Double(app.sizeBytes) / Double(groupMaxBytes) : 0
        let update = AppGrouping.updateState(for: app)
        let tint = update == .manual ? MCColor.secondaryText : MCTheme.accent
        return Button {
            onSelect(app)
        } label: {
            HStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                    .resizable().frame(width: 16, height: 16)
                Text(app.name).font(.caption).lineLimit(1)
                Text(mcFormatBytes(app.sizeBytes)).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10 + CGFloat(weight * 10))
            .padding(.vertical, 6)
            .background(
                Capsule().fill(reduceTransparency ? tint.opacity(0.35) : tint.opacity(0.16))
            )
            .overlay(
                Capsule().strokeBorder(
                    app.isDataLocationAmbiguous ? MCTheme.warning : tint.opacity(0.4),
                    lineWidth: app.isDataLocationAmbiguous ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.accessibilityDescription(app: app, updateState: update))
    }

    /// VoiceOver label for one capsule — real fields only, no decoration.
    nonisolated static func accessibilityDescription(app: InstalledApp, updateState: AppUpdateState) -> String {
        var text = "\(app.name), version \(app.version ?? "unknown"), \(mcFormatBytes(app.sizeBytes)), \(updateState.rawValue) updates."
        if app.isDataLocationAmbiguous { text += " Data location ambiguous." }
        return text
    }
}

/// Minimal wrapping flow layout for variable-width capsule chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width.isFinite ? width : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
