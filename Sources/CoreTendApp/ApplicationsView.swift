import SwiftUI
import AppDiscovery
import SafetyCore
import DesignSystem
import Persistence

/// Real, non-invented update-mechanism detection shared by the Updates tab
/// and the "by update state" grouping — one place reads Sparkle/App Store
/// signals so both stay in sync.
/// Built once per process — the Caskroom doesn't change mid-session, so we scan
/// it lazily on first use rather than per app. A global `let` is initialized
/// atomically and is Sendable.
public let sharedCaskIndex = HomebrewCaskIndex.build()

public enum AppUpdateSource: String, Sendable {
    case appStore = "App Store"
    case homebrew = "Homebrew Cask"
    case sparkle = "Sparkle feed"
    case none = "In-app / manual"

    /// Delegates to the tested `AppDiscovery.updateMechanism` engine so the
    /// classification (App Store receipt, Homebrew Cask token, safe-https Sparkle
    /// feed, download origin) lives in one unit-tested place. `.manual`/`.unknown`
    /// both map to `.none` here — neither offers an in-app auto-update mechanism.
    public static func detect(for app: InstalledApp,
                              caskIndex: HomebrewCaskIndex = sharedCaskIndex) -> (source: AppUpdateSource, feedURL: URL?) {
        switch AppDiscovery().updateMechanism(for: app.path, caskIndex: caskIndex) {
        case .appStore: return (.appStore, nil)
        case .homebrewCask: return (.homebrew, nil)
        case .sparkle(let feedURL): return (.sparkle, feedURL)
        case .manual, .unknown: return (.none, nil)
        }
    }
}

/// Grouping strategies for the Applications list — every key is derived
/// strictly from real `InstalledApp`/`AppUpdateSource` data.
enum AppGrouping: String, CaseIterable, Identifiable {
    case none = "None"
    case publisher = "Publisher"
    case size = "Size"
    case updateState = "Update State"
    case lastUsed = "Last Used"
    var id: String { rawValue }

    /// Localized label for display. `rawValue` stays the internal grouping/sort
    /// key (used by `AppGroupingLogic`'s dictionary keys and `order` arrays) —
    /// only the picker text is translated.
    var displayName: String {
        switch self {
        case .none: L("apps.grouping.none")
        case .publisher: L("apps.grouping.publisher")
        case .size: L("apps.grouping.size")
        case .updateState: L("apps.grouping.update_state")
        case .lastUsed: L("apps.grouping.last_used")
        }
    }
}

struct AppGroup: Identifiable {
    let id: String
    let apps: [InstalledApp]
}

enum AppGroupingLogic {
    /// Vendor label from the bundle identifier's second component
    /// (e.g. "com.acme.App" → "Acme"). Real data; falls back to "Unknown"
    /// rather than inventing a name when there's no bundle id.
    static func publisher(_ app: InstalledApp) -> String {
        guard let id = app.bundleIdentifier else { return "Unknown" }
        let parts = id.split(separator: ".")
        guard parts.count >= 2 else { return "Unknown" }
        return parts[1].capitalized
    }

    static func sizeBucket(_ app: InstalledApp) -> String {
        let mb = Double(app.sizeBytes) / 1_000_000
        switch mb {
        case ..<50: return "Under 50 MB"
        case ..<250: return "50–250 MB"
        case ..<1000: return "250 MB–1 GB"
        default: return "Over 1 GB"
        }
    }

    static func updateState(_ app: InstalledApp) -> String {
        AppUpdateSource.detect(for: app).source.rawValue
    }

    static func lastUsedBucket(_ app: InstalledApp) -> String {
        guard let date = app.lastUsedDate else { return "Unknown" }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case ..<7: return "This week"
        case ..<30: return "This month"
        case ..<90: return "Last 3 months"
        case ..<365: return "This year"
        default: return "Over a year ago"
        }
    }

    static func groups(for apps: [InstalledApp], by grouping: AppGrouping) -> [AppGroup] {
        guard grouping != .none else { return [AppGroup(id: "All Applications", apps: apps)] }
        let key: (InstalledApp) -> String
        let order: [String]?
        switch grouping {
        case .none: key = { _ in "" }; order = nil
        case .publisher: key = publisher; order = nil
        case .size: key = sizeBucket; order = ["Under 50 MB", "50–250 MB", "250 MB–1 GB", "Over 1 GB"]
        case .updateState: key = updateState; order = [AppUpdateSource.appStore.rawValue, AppUpdateSource.homebrew.rawValue, AppUpdateSource.sparkle.rawValue, AppUpdateSource.none.rawValue]
        case .lastUsed: key = lastUsedBucket; order = ["This week", "This month", "Last 3 months", "This year", "Over a year ago", "Unknown"]
        }
        var buckets: [String: [InstalledApp]] = [:]
        for app in apps { buckets[key(app), default: []].append(app) }
        let ids = order?.filter { buckets[$0] != nil } ?? buckets.keys.sorted()
        return ids.map { AppGroup(id: $0, apps: buckets[$0] ?? []) }
    }
}

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
    var grouping: AppGrouping = .none

    private let discovery = AppDiscovery()

    var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var groupedApps: [AppGroup] {
        AppGroupingLogic.groups(for: filteredApps, by: grouping)
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
        let center = SafetyCenter(validator: PathValidator(allowedRoots: allowedRoots), dryRun: dryRun, sink: AppEnvironment.shared.store)
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
            ? L("apps.uninstall.dryrun_result", result.executed.count, mcFormatBytes(freed))
            : L("apps.uninstall.result", result.executed.count, mcFormatBytes(freed))
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
                .tabItem { Label(L("apps.tab.installed"), systemImage: "square.grid.2x2") }
            LeftoversView()
                .tabItem { Label(L("apps.tab.leftovers"), systemImage: "trash.slash") }
            AppUpdatesView()
                .tabItem { Label(L("apps.tab.updates"), systemImage: "arrow.triangle.2.circlepath") }
        }
        .padding(8)
        .navigationTitle(L("apps.title"))
    }
}

struct InstalledAppsView: View {
    @State private var model = ApplicationsViewModel()
    @Namespace private var rowTransition

    var body: some View {
        HSplitView {
            appList
                .frame(minWidth: 300)
            detail
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await model.load() }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            TextField(L("apps.search"), text: $model.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, MCSpacing.sm).padding(.top, MCSpacing.sm)
            Picker(L("apps.group_by"), selection: $model.grouping) {
                ForEach(AppGrouping.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(MCSpacing.sm)
            switch model.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                Text(L("apps.empty")).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                // Native, reliable list is always the primary view — grouping
                // only changes section boundaries, never replaces the list.
                List(selection: Binding(
                    get: { model.selectedApp?.id },
                    set: { id in
                        if let app = model.apps.first(where: { $0.id == id }) {
                            Task { await model.select(app) }
                        }
                    }
                )) {
                    ForEach(model.groupedApps) { group in
                        Section(group.id) {
                            ForEach(group.apps) { app in
                                appCapsuleRow(app)
                                    .tag(app.id)
                                    .matchedGeometryEffect(id: app.id, in: rowTransition)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .animation(MCMotion.snappy, value: model.grouping)
            }
        }
    }

    private func appCapsuleRow(_ app: InstalledApp) -> some View {
        let update = AppUpdateSource.detect(for: app).source
        return HStack(spacing: MCSpacing.sm) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                .resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                HStack(spacing: MCSpacing.xxs) {
                    Text(app.version ?? "—")
                    if app.isQuarantined {
                        Label(L("apps.downloaded"), systemImage: "arrow.down.circle")
                            .labelStyle(.iconOnly)
                            .help(L("apps.downloaded.help"))
                    }
                    if update != .none {
                        Text(update.rawValue)
                            .padding(.horizontal, MCSpacing.xxs)
                            .background(MCColor.protection.opacity(0.15), in: Capsule())
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(mcFormatBytes(app.sizeBytes))
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.vertical, MCSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name), \(L("apps.a11y.version", app.version ?? L("apps.unknown"))), \(mcFormatBytes(app.sizeBytes)), \(update.rawValue)\(app.isQuarantined ? ", \(L("apps.downloaded"))" : "")")
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
                            Text(app.name).font(MCFont.pageTitle)
                            Text(app.bundleIdentifier ?? L("apps.unknown_bundle_id"))
                                .font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                if let version = app.version { Text(L("apps.version_prefix", version)) }
                                if !app.architectures.isEmpty {
                                    Text(app.architectures.joined(separator: ", "))
                                }
                                Text(mcFormatBytes(app.sizeBytes))
                                if let lastUsed = app.lastUsedDate {
                                    Text(L("apps.last_used", lastUsed.formatted(date: .abbreviated, time: .omitted)))
                                } else {
                                    Text(L("apps.last_used_unknown"))
                                }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    MCCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("apps.associated_data")).font(MCFont.cardTitle)
                            if model.associated.isEmpty {
                                Text(L("apps.associated_data.empty"))
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
                        Toggle(L("common.dry_run"), isOn: $model.dryRun).toggleStyle(.switch)
                        Button(model.dryRun ? L("apps.simulate_uninstall") : L("apps.uninstall"), role: .destructive) {
                            Task { await model.uninstall() }
                        }
                        .buttonStyle(.borderedProminent)
                        Button(L("common.reveal_in_finder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([app.path])
                        }
                    }
                    if let result = model.uninstallResult {
                        Text(result).font(MCFont.secondaryBody).foregroundStyle(MCTheme.accent)
                    }
                }
                .padding(20)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: MCIconSize.emptyState)).foregroundStyle(MCTheme.accent)
                Text(L("apps.select_prompt")).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
