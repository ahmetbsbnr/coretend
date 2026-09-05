// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import AppDiscovery
import SafetyCore
import DesignSystem
import Persistence
import IntegrityCore

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
    var selectedApp: InstalledApp?
    var associated: [AssociatedItem] = []
    var selectedAssociatedPaths: Set<String> = []
    var uninstallResult: String?
    var grouping: AppGrouping = .none
    /// The selected app's read-only inspection (identity beyond InstalledApp,
    /// storage breakdown, confidence, provenance, signing, architecture,
    /// launch items, running state). `nil` while loading or when nothing is
    /// selected — never populated with a stale app's data (see `select`).
    private(set) var inspection: ApplicationInspection?

    private let discovery: AppDiscovery
    /// Scanned once per list load, not once per app: LoginItemScanner reads a
    /// handful of directories, not one per app, so every selection reuses
    /// this same snapshot rather than rescanning.
    private var loginItems: [LoginItem] = []
    private var inspectionTask: Task<Void, Never>?

    init(discovery: AppDiscovery = ApplicationInventoryLocations.resolve(
        environment: ProcessInfo.processInfo.environment
    ).discovery) {
        self.discovery = discovery
    }

    var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
        let locations = IntegrityScanLocations.resolve(environment: ProcessInfo.processInfo.environment)
        loginItems = await Task.detached(priority: .utility) { LoginItemScanner.scan(locations: locations.loginItems) }.value
    }

    func select(_ app: InstalledApp) async {
        inspectionTask?.cancel()
        selectedApp = app
        uninstallResult = nil
        associated = []
        selectedAssociatedPaths = []
        inspection = nil
        let discovery = discovery
        let items = await Task.detached(priority: .utility) { discovery.associatedItems(for: app) }.value
        // A later selection may have already landed while this awaited —
        // never let a stale app's data overwrite what the user is now looking at.
        guard selectedApp?.id == app.id else { return }
        associated = items
        // Preselect only reversible support data; preferences, containers, and
        // launch items stay visible but require an explicit user choice.
        selectedAssociatedPaths = Set(items.filter { Self.isPreselectedAssociatedKind($0.kind) }.map(\.url.path))

        let allApps = apps
        let currentLoginItems = loginItems
        inspectionTask = Task {
            let result = await ApplicationInspectionService.inspect(
                app: app, allInstalledApps: allApps, discovery: discovery,
                caskIndex: sharedCaskIndex, loginItems: currentLoginItems)
            // Guards a second time for the same reason as above: this task
            // may finish after cancellation was requested, or after a newer
            // selection already landed while it awaited.
            guard !Task.isCancelled, self.selectedApp?.id == app.id else { return }
            self.inspection = result
        }
    }

    /// Moves the app bundle and approved associated items to the Trash.
    func uninstall() async {
        guard let app = selectedApp else { return }
        let items = associated.filter { selectedAssociatedPaths.contains($0.url.path) }
        let home = FileManager.default.homeDirectoryForCurrentUser
        var allowedRoots: [URL] = [app.path.deletingLastPathComponent()]
        allowedRoots.append(home.appendingPathComponent("Library"))
        allowedRoots.append(URL(fileURLWithPath: "/Library/LaunchAgents"))
        allowedRoots.append(URL(fileURLWithPath: "/Library/LaunchDaemons"))
        let center = SafetyCenter(validator: PathValidator(allowedRoots: allowedRoots), sink: AppEnvironment.shared.store)
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
        uninstallResult = L("apps.uninstall.result", result.executed.count, mcFormatBytes(freed))
        AppEnvironment.shared.record(ActivityRecord(
            kind: .cleanup,
            summary: "Uninstalled \(app.name)",
            itemCount: result.executed.count, bytes: freed))
        await load()
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
        .padding(MCSpacing.xs)
        .navigationTitle(L("apps.title"))
        .accessibilityIdentifier("applications.root")
    }
}

struct InstalledAppsView: View {
    @State private var model = ApplicationsViewModel()
    @State private var showUninstallConfirmation = false
    @Namespace private var rowTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HSplitView {
            appList
                .frame(minWidth: 300)
            detail
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
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
            Text(L("apps.uninstall_confirm.message"))
        }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            TextField(L("apps.search"), text: $model.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, MCSpacing.sm).padding(.top, MCSpacing.sm)
                .accessibilityIdentifier("applications.search")
            HStack(spacing: MCSpacing.xs) {
                Text(L("apps.group_by")).foregroundStyle(.secondary)
                Picker("", selection: $model.grouping) {
                    ForEach(AppGrouping.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityIdentifier("applications.grouping")
                Spacer()
            }
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
                .animation(MCMotion.animation(MCMotion.snappy, reduce: reduceMotion), value: model.grouping)
                .accessibilityIdentifier("applications.list")
            }
        }
    }

    private func appCapsuleRow(_ app: InstalledApp) -> some View {
        let update = AppUpdateSource.detect(for: app).source
        return HStack(spacing: MCSpacing.sm) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                .resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
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
                VStack(alignment: .leading, spacing: MCSpacing.md) {
                    HStack(spacing: MCSpacing.sm) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                            .resizable().frame(width: 56, height: 56)
                        VStack(alignment: .leading) {
                            Text(app.name).font(MCFont.pageTitle)
                            Text(app.bundleIdentifier ?? L("apps.unknown_bundle_id"))
                                .font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: MCSpacing.xs) {
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
                    if let inspection = model.inspection {
                        headerFactsCard(inspection)
                        storageCard(inspection)
                        securityCard(inspection)
                        startupCard(inspection)
                    }
                    MCCard {
                        VStack(alignment: .leading, spacing: MCSpacing.xs) {
                            Text(L("apps.associated_data")).font(MCFont.cardTitle)
                            if model.associated.isEmpty && (model.inspection?.associatedItems.isEmpty ?? true) {
                                Text(L("apps.associated_data.empty"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(model.associated) { item in
                                associatedRow(item, association: model.inspection?.associatedItems.first { $0.item.id == item.id })
                            }
                            // Group Container candidates are informational only in
                            // this pass — never selectable for uninstall (see
                            // Documentation/APPLICATIONS_CENTER.md "Group Containers").
                            ForEach((model.inspection?.associatedItems ?? []).filter { $0.method == .vendorPrefixHeuristic }) { association in
                                associatedRow(association.item, association: association, selectable: false)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Button(L("apps.uninstall"), role: .destructive) {
                            showUninstallConfirmation = true
                        }
                        .buttonStyle(.borderedProminent)
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
            MCEmptyState(icon: "square.grid.2x2", title: L("apps.select_prompt"), message: "", iconColor: MCTheme.accent)
        }
    }

    // MARK: - Applications Center 2.0 detail sections (all read-only)

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: MCSpacing.sm)
            Text(value)
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }

    private func headerFactsCard(_ inspection: ApplicationInspection) -> some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                factRow(L("apps.detail.architecture"), architectureLabel(inspection.architecture))
                factRow(L("apps.detail.installed_via"), installationSourceLabel(inspection.installationSource))
                factRow(L("apps.detail.updates_via"), updateMechanismLabel(inspection.updateMechanism))
                factRow(L("apps.detail.running"), runtimeStateLabel(inspection.runtimeState))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    private func storageCard(_ inspection: ApplicationInspection) -> some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                Text(L("apps.detail.storage")).font(MCFont.cardTitle)
                factRow(L("apps.detail.storage.application"), mcFormatBytes(inspection.storage.applicationBytes))
                ForEach(inspection.storage.byKind, id: \.kind) { entry in
                    factRow(entry.kind.rawValue, mcFormatBytes(entry.bytes))
                }
                Divider()
                // Deliberately not "Total": this only sums the fixed set of
                // locations CoreTend actually looks in, never claimed exhaustive.
                factRow(L("apps.detail.storage.known_associated"), mcFormatBytes(inspection.storage.knownAssociatedStorageBytes))
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    private func securityCard(_ inspection: ApplicationInspection) -> some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(L("apps.detail.security")).font(MCFont.cardTitle)
                if let signature = inspection.signature {
                    factRow(L("apps.detail.signed"), signingTierLabel(signature.tier))
                    if let teamID = signature.teamIdentifier {
                        factRow(L("apps.detail.team_id"), teamID)
                    }
                } else {
                    factRow(L("apps.detail.signed"), L("apps.unknown"))
                }
                factRow(L("apps.detail.provenance"),
                       inspection.app.isQuarantined ? L("apps.detail.provenance.quarantined") : L("apps.detail.provenance.not_quarantined"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    private func startupCard(_ inspection: ApplicationInspection) -> some View {
        MCCard {
            DisclosureGroup {
                if inspection.launchItems.isEmpty {
                    Text(L("apps.detail.startup.none")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(inspection.launchItems) { association in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(association.item.label)
                                Text(association.item.plistPath).font(.caption2).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            confidenceBadge(association.confidence)
                        }
                        .font(.caption)
                    }
                }
            } label: {
                Text(L("apps.detail.startup.count", inspection.launchItems.count)).font(MCFont.cardTitle)
            }
        }
        .accessibilityIdentifier("applications.startup")
    }

    private func confidenceBadge(_ confidence: AdvisorConfidence) -> some View {
        Text(confidenceLabel(confidence))
            .font(.caption2)
            .padding(.horizontal, MCSpacing.xxs)
            .background(.secondary.opacity(0.15), in: Capsule())
    }

    private func sharedBadge() -> some View {
        Text(L("apps.detail.associated.shared"))
            .font(.caption2)
            .padding(.horizontal, MCSpacing.xxs)
            .background(MCColor.protection.opacity(0.2), in: Capsule())
    }

    private func associatedRow(_ item: AssociatedItem, association: AssociatedItemAssociation?, selectable: Bool = true) -> some View {
        HStack {
            if selectable {
                Toggle("", isOn: Binding(
                    get: { model.selectedAssociatedPaths.contains(item.url.path) },
                    set: { on in
                        if on { model.selectedAssociatedPaths.insert(item.url.path) }
                        else { model.selectedAssociatedPaths.remove(item.url.path) }
                    }
                ))
                .labelsHidden()
            }
            VStack(alignment: .leading) {
                HStack(spacing: MCSpacing.xxs) {
                    Text(item.kind.rawValue)
                    if let association {
                        confidenceBadge(association.confidence)
                        if association.isShared { sharedBadge() }
                    }
                }
                Text(item.url.path).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(mcFormatBytes(item.sizeBytes))
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func architectureLabel(_ detail: ApplicationArchitectureDetail) -> String {
        switch detail.architectures {
        case ["universal"]: L("apps.detail.architecture.universal")
        case ["arm64"]: L("apps.detail.architecture.arm64")
        case ["x86_64"]: L("apps.detail.architecture.x86_64")
        default: L("apps.detail.architecture.unknown")
        }
    }

    private func installationSourceLabel(_ source: InstallationSource) -> String {
        switch source {
        case .appStore: L("apps.detail.installed_via.app_store")
        case .homebrewCask: L("apps.detail.installed_via.homebrew")
        case .downloaded: L("apps.detail.installed_via.downloaded")
        case .unknown: L("apps.detail.installed_via.unknown")
        }
    }

    private func updateMechanismLabel(_ mechanism: UpdateMechanism) -> String {
        switch mechanism {
        case .appStore: L("apps.detail.updates_via.app_store")
        case .homebrewCask: L("apps.detail.updates_via.homebrew")
        case .sparkle: L("apps.detail.updates_via.sparkle")
        case .manual, .unknown: L("apps.detail.updates_via.none")
        }
    }

    private func runtimeStateLabel(_ state: ApplicationRuntimeState) -> String {
        switch state {
        case .running: L("apps.detail.running.yes")
        case .notRunning: L("apps.detail.running.no")
        case .unknown: L("apps.unknown")
        }
    }

    private func signingTierLabel(_ tier: CodeSignTier) -> String {
        switch tier {
        case .appleSigned: L("apps.detail.signing_tier.apple")
        case .teamSigned: L("apps.detail.signing_tier.team")
        case .adHocOrUnsigned: L("apps.detail.signing_tier.adhoc")
        }
    }

    private func confidenceLabel(_ confidence: AdvisorConfidence) -> String {
        switch confidence {
        case .exact: L("apps.detail.associated.confidence.exact")
        case .high: L("apps.detail.associated.confidence.high")
        case .probable: L("apps.detail.associated.confidence.probable")
        case .uncertain: L("apps.detail.associated.confidence.uncertain")
        }
    }
}
