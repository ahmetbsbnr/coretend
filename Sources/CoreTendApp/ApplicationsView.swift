// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import AppDiscovery
import SafetyCore
import DesignSystem
import Persistence

/// Resolves every application-inventory root. Normal launches inspect the
/// standard macOS locations. Test launches are confined to fixtures beneath a
/// validated temporary store; an invalid override fails closed with no roots.
struct ApplicationInventoryLocations {
    let home: URL
    let applicationRoots: [URL]
    let systemLibrary: URL?
    let caskroomRoots: [String]

    static func resolve(
        environment: [String: String],
        realHome: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> ApplicationInventoryLocations {
        if TestStoreOverride.isTestMarkerSet(environment: environment) {
            guard let temporaryRoot = TestStoreOverride.resolve(environment: environment).directory else {
                return ApplicationInventoryLocations(
                    home: URL(fileURLWithPath: "/dev/null"),
                    applicationRoots: [],
                    systemLibrary: nil,
                    caskroomRoots: []
                )
            }
            let fixtures = temporaryRoot.appendingPathComponent("ApplicationFixtures", isDirectory: true)
            let fixtureHome = fixtures.appendingPathComponent("Home", isDirectory: true)
            return ApplicationInventoryLocations(
                home: fixtureHome,
                applicationRoots: [
                    fixtures.appendingPathComponent("Applications", isDirectory: true),
                    fixtureHome.appendingPathComponent("Applications", isDirectory: true),
                ],
                systemLibrary: fixtures.appendingPathComponent("SystemLibrary", isDirectory: true),
                caskroomRoots: [fixtures.appendingPathComponent("Caskroom", isDirectory: true).path]
            )
        }

        return ApplicationInventoryLocations(
            home: realHome,
            applicationRoots: [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                realHome.appendingPathComponent("Applications", isDirectory: true),
            ],
            systemLibrary: URL(fileURLWithPath: "/Library", isDirectory: true),
            caskroomRoots: HomebrewCaskIndex.caskroomRoots
        )
    }

    var discovery: AppDiscovery {
        AppDiscovery(home: home, applicationRoots: applicationRoots, systemLibrary: systemLibrary)
    }
}

/// Real, non-invented update-mechanism detection shared by the Updates tab
/// and the "by update state" grouping — one place reads Sparkle/App Store
/// signals so both stay in sync.
/// Built once per process — the Caskroom doesn't change mid-session, so we scan
/// it lazily on first use rather than per app. A global `let` is initialized
/// atomically and is Sendable.
public let sharedCaskIndex: HomebrewCaskIndex = {
    let locations = ApplicationInventoryLocations.resolve(environment: ProcessInfo.processInfo.environment)
    return HomebrewCaskIndex.build(roots: locations.caskroomRoots)
}()

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
    var sortOrder: [KeyPathComparator<InstalledApp>] = [KeyPathComparator(\.sizeBytes, order: .reverse)]
    var selectedApp: InstalledApp?
    var associated: [AssociatedItem] = []
    var selectedAssociatedPaths: Set<String> = []
    var uninstallResult: String?
    var grouping: AppGrouping = .none

    private let discovery: AppDiscovery

    init(discovery: AppDiscovery = ApplicationInventoryLocations.resolve(
        environment: ProcessInfo.processInfo.environment
    ).discovery) {
        self.discovery = discovery
    }

    var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// The visible apps in the table's order. Grouping contributes a sort
    /// key ahead of the chosen column, so "group by publisher" reads as
    /// publisher blocks without losing the table.
    var sortedApps: [InstalledApp] {
        groupedApps.flatMap(\.apps).sorted(using: sortOrder)
    }

    var groupedApps: [AppGroup] {
        AppGroupingLogic.groups(for: filteredApps, by: grouping)
    }

    nonisolated static func isPreselectedAssociatedKind(_ kind: AssociatedItem.Kind) -> Bool {
        kind == .caches || kind == .savedState
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
        let discovery = discovery
        let items = await Task.detached(priority: .utility) { discovery.associatedItems(for: app) }.value
        associated = items
        // Preselect only reversible support data; preferences, containers, and
        // launch items stay visible but require an explicit user choice.
        selectedAssociatedPaths = Set(items.filter { Self.isPreselectedAssociatedKind($0.kind) }.map(\.url.path))
    }

    /// Moves the app bundle and approved associated items to the Trash.
    /// The bundle plus every ticked associated item — the number the
    /// confirmation quotes, so what it says and what it does are one
    /// computation.
    var uninstallBytes: Int64 {
        (selectedApp?.sizeBytes ?? 0)
            + associated.filter { selectedAssociatedPaths.contains($0.url.path) }
                        .reduce(0) { $0 + $1.sizeBytes }
    }

    func uninstall() async {
        guard let app = selectedApp else { return }
        let items = associated.filter { selectedAssociatedPaths.contains($0.url.path) }
        let home = FileManager.default.homeDirectoryForCurrentUser
        var allowedRoots: [URL] = [app.path.deletingLastPathComponent()]
        allowedRoots.append(home.appendingPathComponent("Library"))
        allowedRoots.append(URL(fileURLWithPath: "/Library/LaunchAgents"))
        allowedRoots.append(URL(fileURLWithPath: "/Library/LaunchDaemons"))
        let center = SafetyCenter(validator: PathValidator(allowedRoots: allowedRoots), sink: AppEnvironment.shared.store)
        // The bundle itself first, then its leftovers, so the audit log reads
        // in the order the user thinks about the uninstall.
        let requests = [ApprovalRequest(url: app.path, logicalSize: app.sizeBytes,
                                        ruleID: "apps.uninstall", risk: .medium)]
            + items.map { ApprovalRequest(url: $0.url, logicalSize: $0.sizeBytes,
                                          ruleID: "apps.uninstall.associated", risk: .medium) }
        let batch = await center.approveAll(requests)
        let outcome = ExecutionOutcome(
            result: await center.execute(batch.approved),
            rejections: batch.rejections)
        uninstallResult = [
            L("apps.uninstall.result", outcome.executedCount, mcFormatBytes(outcome.movedToTrashBytes)),
            outcome.message,
        ].compactMap { $0 }.joined(separator: "\n")
        AppEnvironment.shared.record(ActivityRecord(
            kind: .cleanup,
            summary: outcome.annotate("Uninstalled \(app.name)"),
            itemCount: outcome.executedCount, bytes: outcome.movedToTrashBytes))
        await load()
    }
}

struct ApplicationsView: View {
    @State private var tab = 0

    // Was a TabView, which is exactly the construct the rest of this codebase
    // documents as able to blank the NavigationSplitView sidebar on macOS —
    // the 1.0.1 defect. Protection and My Clutter had already been moved off
    // it; this one had not. See ModuleSubNav.
    var body: some View {
        ModuleSubNav(sections: [
            .init(0, L("apps.tab.installed")),
            .init(1, L("apps.tab.leftovers")),
            .init(2, L("apps.tab.updates")),
        ], selection: $tab) { tab in
            switch tab {
            case 1: LeftoversView()
            case 2: AppUpdatesView()
            default: InstalledAppsView()
            }
        }
        .navigationTitle(L("apps.title"))
        .accessibilityIdentifier("applications.root")
    }
}

struct InstalledAppsView: ModuleSubScreen {
    static let parent = ModuleID.applications
    static let labelKey = "apps.tab.installed"

    @State private var model = ApplicationsViewModel()
    @State private var showUninstallConfirmation = false
    @Namespace private var rowTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// List and inspector, not a second split view.
    ///
    /// This was an `HSplitView` nested inside the window's own
    /// `NavigationSplitView`, which gave the screen a second draggable divider
    /// and a second sunken column sitting right beside the real sidebar. Two
    /// columns of the same shape, three pixels apart, reading as two sidebars —
    /// and nothing else in the app does it, so the pattern had to be learned
    /// here and nowhere else.
    ///
    /// An `HStack` instead: the list is content on a raised surface rather than
    /// chrome on a sunken one, the boundary is a hairline rather than a grab
    /// handle, and the proportions are fixed. Nothing is lost — the divider was
    /// draggable but there was no reason to drag it.
    var body: some View {
        HStack(spacing: 0) {
            appList
                .frame(minWidth: 440, idealWidth: 560, maxWidth: 720)
                .background(MCColor.elevatedBackground)
            Divider()
            detail
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await model.load() }
        .confirmationDialog(
            L("apps.uninstall_confirm.title"),
            isPresented: $showUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("apps.uninstall"), role: .destructive) {
                Task { await model.uninstall() }
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            // Names the app, counts the items and totals the bytes. "The
            // support items you selected" was true and useless: a destructive
            // confirmation has to let a person check the thing they are about
            // to do without dismissing it first.
            Text(L("apps.uninstall_confirm.message",
                   model.selectedApp?.name ?? "",
                   model.selectedAssociatedPaths.count + 1,
                   mcFormatBytes(model.uninstallBytes)))
        }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            HStack(spacing: MCSpacing.xs) {
                TextField(L("apps.search"), text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("applications.search")
                Picker(L("apps.group_by"), selection: $model.grouping) {
                    ForEach(AppGrouping.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .accessibilityIdentifier("applications.grouping")
            }
            .padding(.horizontal, MCSpacing.sm).padding(.vertical, MCSpacing.xs)
            switch model.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                Text(L("apps.empty")).foregroundStyle(MCColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                // A table, because an inventory has four attributes a person
                // sorts by — name, size, last use, where it came from — and a
                // capsule row could only show them stacked. Grouping stays as
                // a sort key rather than as sections, so the table keeps its
                // columns and its keyboard behaviour.
                Table(model.sortedApps, selection: Binding(
                    get: { model.selectedApp?.id },
                    set: { id in
                        if let app = model.apps.first(where: { $0.id == id }) {
                            Task { await model.select(app) }
                        }
                    }
                ), sortOrder: $model.sortOrder) {
                    TableColumn(L("apps.column_name"), value: \.name) { app in
                        HStack(spacing: MCSpacing.xs) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                                .resizable().frame(width: 16, height: 16).accessibilityHidden(true)
                            Text(app.name).lineLimit(1)
                            if app.isQuarantined {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(MCColor.textTertiary)
                                    .help(L("apps.downloaded.help"))
                                    .accessibilityLabel(L("apps.downloaded"))
                            }
                        }
                    }
                    .width(min: 160, ideal: 220)
                    TableColumn(L("apps.column_size"), value: \.sizeBytes) { app in
                        Text(mcFormatBytes(app.sizeBytes)).font(MCFont.tabular)
                    }
                    .width(min: 70, ideal: 84)
                    TableColumn(L("apps.column_last_used"), value: \.lastUsedSortKey) { app in
                        Text(app.lastUsedDate.map { AppDateFormatting.string($0, style: .dayMonthYear) }
                             ?? L("apps.last_used_unknown_short"))
                            .foregroundStyle(MCColor.textSecondary)
                    }
                    .width(min: 90, ideal: 110)
                    TableColumn(L("apps.column_source"), value: \.sourceSortKey) { app in
                        Text(AppUpdateSource.detect(for: app).source.rawValue)
                            .foregroundStyle(MCColor.textSecondary)
                    }
                    .width(min: 90, ideal: 120)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: false))
                .accessibilityIdentifier("applications.list")
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let app = model.selectedApp {
            ScrollView {
                VStack(alignment: .leading, spacing: MCSpacing.md) {
                    HStack(spacing: MCSpacing.sm) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                            .resizable().frame(width: 56, height: 56)
                        VStack(alignment: .leading) {
                            Text(app.name).font(MCFont.pageTitle)
                            Text(app.bundleIdentifier ?? L("apps.unknown_bundle_id"))
                                .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                            HStack(spacing: MCSpacing.xs) {
                                if let version = app.version { Text(L("apps.version_prefix", version)) }
                                if !app.architectures.isEmpty {
                                    Text(app.architectures.joined(separator: ", "))
                                }
                                Text(mcFormatBytes(app.sizeBytes))
                                if let lastUsed = app.lastUsedDate {
                                    Text(L("apps.last_used", AppDateFormatting.string(lastUsed, style: .dayMonthYear)))
                                } else {
                                    Text(L("apps.last_used_unknown"))
                                }
                            }
                            .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: MCSpacing.sm) {
                        VStack(alignment: .leading, spacing: MCSpacing.xs) {
                            Text(L("apps.associated_data")).font(MCFont.cardTitle)
                            if model.associated.isEmpty {
                                Text(L("apps.associated_data.empty"))
                                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                            }
                            ForEach(model.associated) { item in
                                HStack(spacing: MCSpacing.xs) {
                                    Toggle("", isOn: Binding(
                                        get: { model.selectedAssociatedPaths.contains(item.url.path) },
                                        set: { on in
                                            if on { model.selectedAssociatedPaths.insert(item.url.path) }
                                            else { model.selectedAssociatedPaths.remove(item.url.path) }
                                        }
                                    ))
                                    .labelsHidden()
                                    .accessibilityLabel(L("apps.select_associated", item.kind.rawValue, item.url.path))
                                    Text(item.kind.rawValue).font(MCFont.rowTitle)
                                    Text(PathDisplay.abbreviate(item.url)).font(MCFont.monoCaption)
                                        .foregroundStyle(MCColor.textSecondary)
                                        .lineLimit(1).truncationMode(.middle)
                                    Spacer(minLength: MCSpacing.xs)
                                    Text(mcFormatBytes(item.sizeBytes)).font(MCFont.tabular)
                                        .foregroundStyle(MCColor.textSecondary)
                                        .frame(width: 76, alignment: .trailing)
                                }
                                .contextMenu {
                                    Button(L("common.reveal_in_finder")) {
                                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Button(L("apps.uninstall"), role: .destructive) {
                            showUninstallConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("applications.uninstall")
                        Button(L("common.reveal_in_finder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([app.path])
                        }
                        .accessibilityIdentifier("applications.reveal")
                    }
                    if let result = model.uninstallResult {
                        Text(result).font(MCFont.secondaryBody).foregroundStyle(MCTheme.accent)
                    }
                }
                .padding(MCSpacing.page)
            }
        } else {
            MCEmptyState(icon: "sidebar.left", title: L("apps.select_prompt"), message: "")
        }
    }
}


extension InstalledApp {
    /// Apps never used sort last, whichever direction the column is in.
    var lastUsedSortKey: Date { lastUsedDate ?? .distantPast }
    var sourceSortKey: String { AppUpdateSource.detect(for: self).source.rawValue }
}
