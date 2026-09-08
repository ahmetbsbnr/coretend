// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Deep Scan — user-facing surface for the DeepScanCore engine + detectors.
//
// This screen only *analyses* and *presents*. The single place a real change
// happens is `DeepScanExecutor` -> `SafetyCenter` -> Trash, behind the
// `DeepScanExecutionGate` (OFF for normal builds). Everything visible here is
// read-only until the user opens the Cleanup Plan and confirms, and even then
// only the narrow SAFE subset is eligible.
//
// GUI behaviour that needs a running app (layout, scrolling, VoiceOver) is
// HUMAN VERIFICATION REQUIRED — see Documentation/DeepScan/GUI.md.

import SwiftUI
import DeepScanCore
import SafetyCore
import DesignSystem
import Persistence

// MARK: - Localized labels for DeepScanCore enums
//
// DeepScanCore stays framework- and localization-free; the app maps its enums
// to `Localizable.strings` here so no Deep Scan screen shows mixed languages.

private func dsPhaseName(_ p: DeepScanPhase) -> String {
    switch p {
    case .preparing: L("deepscan.phase.preparing")
    case .enumerating: L("deepscan.phase.enumerating")
    case .indexing: L("deepscan.phase.indexing")
    case .analyzingApps: L("deepscan.phase.apps")
    case .analyzingAI: L("deepscan.phase.ai")
    case .analyzingDeveloper: L("deepscan.phase.developer")
    case .analyzingGit: L("deepscan.phase.git")
    case .analyzingLeftovers: L("deepscan.phase.leftovers")
    case .finalizing: L("deepscan.phase.finalizing")
    case .done: L("deepscan.phase.done")
    case .cancelledPartial: L("deepscan.phase.partial")
    }
}

private func dsRiskName(_ r: RiskClass) -> String {
    switch r {
    case .safe: L("deepscan.risk.low")
    case .review: L("deepscan.risk.review")
    case .highRisk: L("deepscan.risk.high")
    case .protected: L("deepscan.risk.protected")
    }
}

private func dsConfidenceName(_ c: Confidence) -> String {
    switch c {
    case .confirmed: L("deepscan.confidence.confirmed")
    case .strong: L("deepscan.confidence.strong")
    case .probable: L("deepscan.confidence.probable")
    case .weak: L("deepscan.confidence.weak")
    case .unknown: L("deepscan.confidence.unknown")
    }
}

private func dsRebuildName(_ r: Reconstructability) -> String {
    switch r {
    case .regeneratesLocally: L("deepscan.rebuild.local")
    case .reinstallRequired: L("deepscan.rebuild.reinstall")
    case .networkRedownload: L("deepscan.rebuild.redownload")
    case .longCompile: L("deepscan.rebuild.long")
    case .largeModelDownload: L("deepscan.rebuild.large")
    case .irreplaceable: L("deepscan.rebuild.irreplaceable")
    case .unknown: L("deepscan.rebuild.unknown")
    }
}

private func dsCategoryName(_ c: CleanupCategory) -> String {
    switch c {
    case .storage: L("deepscan.category.storage")
    case .appsAndLeftovers: L("deepscan.category.apps")
    case .aiAndLLM: L("deepscan.category.ai")
    case .developer: L("deepscan.category.developer")
    case .gitProjects: L("deepscan.category.git")
    case .systemAndSettings: L("deepscan.category.system")
    case .temporaryFiles: L("deepscan.category.temp")
    case .installers: L("deepscan.category.installers")
    case .cloud: L("deepscan.category.cloud")
    }
}

private func dsSortName(_ s: DeepScanSort) -> String {
    switch s {
    case .size: L("deepscan.sort.size")
    case .risk: L("deepscan.sort.risk")
    case .lastActivity: L("deepscan.sort.lastactivity")
    case .confidence: L("deepscan.sort.confidence")
    }
}

@MainActor
@Observable
final class DeepScanViewModel {
    enum Phase: Equatable { case idle, scanning, results }

    var phase: Phase = .idle
    var progress = DeepScanProgressModel()
    var permission: DeepScanPermissionState = .partialAccess
    var settings = DeepScanSettings.load()
    /// When set (via "Scan a specific folder…"), the scan is limited to this
    /// path instead of the home volume. Used for controlled QA of a disposable
    /// fixture; the detector context still uses the real home.
    var overrideRoot: URL?

    // Results
    private(set) var candidates: [CleanupCandidate] = []
    private(set) var gitFacts: [GitRepoFacts] = []
    private(set) var identitiesByPath: [String: FileIdentity] = [:]
    private(set) var runningBundleIDs: Set<String> = []
    var results = DeepScanResultsModel([])
    var selectedCategory: CleanupCategory?
    var selectedIDs: Set<UUID> = []
    var pageLimit = 200
    var visibleCount = 200

    // Plan
    var plan: DeepScanCleanupPlan?
    var showPlan = false
    var showSettings = false
    var executionReport: DeepScanExecutionReport?

    private var scanTask: Task<Void, Never>?
    private let cancellation = DeepScanCancellation()

    var executionAvailable: Bool { DeepScanExecutionGate.isEnabledResolved }

    // MARK: scanning

    func startScan() {
        guard phase != .scanning else { return }
        phase = .scanning
        progress = DeepScanProgressModel()
        progress.phase = .preparing
        candidates = []; gitFacts = []; selectedIDs = []
        permission = DeepScanPermissionProbe().probe()

        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = overrideRoot.map { [$0] } ?? settings.scanRoots(home: home)
        var cfg = DeepScanConfiguration(
            roots: roots, maxConcurrency: 8, timeBudget: .seconds(240),
            excludedPrefixes: ["/System", "/Volumes"],
            followMountBoundaries: settings.scanExternalVolumes, maxDepth: 32)
        cfg.roots = roots
        let detectors = settings.detectors()
        let allowNet = settings.gitNetworkVerificationEnabled

        scanTask = Task { [weak self] in
            guard let self else { return }
            self.progress.phase = .enumerating
            let pipeline = DeepScanPipeline(detectors: detectors, allowNetwork: allowNet)
            let result = await pipeline.run(configuration: cfg, home: home,
                                            cancellation: self.cancellation) { p in
                Task { @MainActor in
                    self.progress.nodesScanned = p.nodesObserved
                    self.progress.bytesObserved = p.bytesObserved
                }
            }
            self.progress.phase = .finalizing
            self.candidates = result.candidates
            self.gitFacts = result.context.gitRepos
            self.identitiesByPath = result.identitiesByPath
            self.runningBundleIDs = result.context.runningBundleIDs
            self.progress.permissionDeniedCount = result.graph.deniedRoots.count
            self.results = DeepScanResultsModel(result.candidates)
            self.progress.phase = (result.graph.wasCancelled || result.graph.hitTimeout)
                ? .cancelledPartial : .done
            self.phase = .results

            AppEnvironment.shared.record(ActivityRecord(
                kind: .scan,
                summary: "Deep Scan: \(result.candidates.count) items across \(result.graph.nodes.count) nodes",
                itemCount: result.candidates.count,
                bytes: result.candidates.filter { $0.risk != .protected }
                    .reduce(0) { $0 + $1.estimatedReclaimableBytes }))
        }
    }

    func pause() { cancellation.pause(); progress.isPaused = true }
    func resume() { cancellation.resume(); progress.isPaused = false }
    func cancel() { cancellation.cancel(); scanTask?.cancel() }

    // MARK: results helpers

    var categoryGroups: [DeepScanCategoryGroup] { DeepScanGrouping.categories(candidates) }
    var aiGroups: [DeepScanAIToolGroup] { DeepScanGrouping.aiTools(candidates) }
    var gitRows: [DeepScanGitRepoRow] { DeepScanGrouping.gitRepos(candidates, facts: gitFacts) }

    func rows() -> [DeepScanDisplayRow] {
        var m = results
        m.filter.category = selectedCategory
        return m.page(offset: 0, limit: visibleCount)
    }
    func totalMatching() -> Int {
        var m = results
        m.filter.category = selectedCategory
        return m.filteredCount
    }
    func reviewableBytes() -> Int64 {
        var m = results
        m.filter.category = selectedCategory
        return m.reclaimableBytes()
    }

    func toggle(_ row: DeepScanDisplayRow) {
        guard !row.isProtected else { return }
        if selectedIDs.contains(row.id) { selectedIDs.remove(row.id) } else { selectedIDs.insert(row.id) }
    }

    // MARK: plan + execution

    func openPlan() {
        let reval = ExecutionRevalidator().revalidate(
            candidates.filter { selectedIDs.contains($0.id) && $0.risk != .protected },
            originalIdentities: identitiesByPath,
            runningBundleIDs: DeepScanPipeline.runningProcesses().bundleIDs)
        plan = DeepScanCleanupPlan.build(selectedIDs: selectedIDs, from: candidates, revalidation: reval)
        showPlan = true
    }

    func executePlan() {
        Task { [weak self] in
            guard let self else { return }
            let selected = self.candidates.filter { self.selectedIDs.contains($0.id) }
            let report = await DeepScanExecutor().execute(
                selected: selected,
                identitiesByPath: self.identitiesByPath,
                runningBundleIDs: DeepScanPipeline.runningProcesses().bundleIDs,
                allowedRoots: PathValidator.userContentRoots(home: FileManager.default.homeDirectoryForCurrentUser)
                    .map { URL(fileURLWithPath: $0) }
                    + [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches"),
                       URL(fileURLWithPath: NSTemporaryDirectory())],
                auditSink: AppEnvironment.shared.store)
            self.executionReport = report
            if !report.executed.isEmpty {
                AppEnvironment.shared.record(ActivityRecord(
                    kind: .cleanup,
                    summary: "Deep Scan moved \(report.executed.count) items to Trash",
                    itemCount: report.executed.count, bytes: report.bytesTrashed))
            }
            self.showPlan = false
            self.startRefreshAfterExecution()
        }
    }

    private func startRefreshAfterExecution() {
        selectedIDs = selectedIDs.filter { id in
            !(executionReport?.executed.contains { $0.candidate.id == id } ?? false)
        }
    }

    func saveSettings() { try? settings.save() }
}

// MARK: - Root view

struct DeepScanView: View {
    @State private var model = DeepScanViewModel()

    var body: some View {
        Group {
            switch model.phase {
            case .idle: entry
            case .scanning: scanning
            case .results: results
            }
        }
        .navigationTitle(L("deepscan.nav_title"))
        .accessibilityIdentifier("deepScan.root")
        .sheet(isPresented: $model.showSettings) {
            DeepScanSettingsSheet(settings: $model.settings, onSave: model.saveSettings)
        }
        .sheet(isPresented: $model.showPlan) {
            if let plan = model.plan {
                DeepScanPlanSheet(plan: plan, executionAvailable: model.executionAvailable,
                                  report: model.executionReport,
                                  onExecute: model.executePlan)
            }
        }
    }

    // MARK: entry

    private var entry: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                Text(L("deepscan.nav_title"))
                    .font(MCFont.pageTitle)
                Text(L("deepscan.intro"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                MCCard {
                    VStack(alignment: .leading, spacing: MCSpacing.sm) {
                        permissionRow
                        Divider()
                        Label(model.settings.scanExternalVolumes
                              ? L("deepscan.volume_with_external", "\(model.settings.includedExternalVolumeRoots.count)")
                              : L("deepscan.volume_home_only"),
                              systemImage: "internaldrive")
                            .font(MCFont.secondaryBody)
                        Label(L("deepscan.readonly_note"), systemImage: "lock.shield")
                            .font(MCFont.secondaryBody)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: MCSpacing.sm) {
                    Button {
                        model.startScan()
                    } label: {
                        Label(L("deepscan.start"), systemImage: "magnifyingglass")
                            .frame(maxWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(L("deepscan.scan_options")) { model.showSettings = true }
                        .controlSize(.large)
                }

                HStack(spacing: MCSpacing.xs) {
                    Button(L("deepscan.scan_folder")) {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK { model.overrideRoot = panel.url }
                    }
                    if let r = model.overrideRoot {
                        Text(L("deepscan.scan_folder_active", r.path))
                            .font(MCFont.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Button(L("deepscan.scan_whole_home")) { model.overrideRoot = nil }
                            .font(MCFont.caption)
                    }
                }

                if !model.executionAvailable {
                    Label(L("deepscan.exec_disabled_note"),
                          systemImage: "exclamationmark.triangle")
                        .font(MCFont.caption)
                        .foregroundStyle(MCTheme.warning)
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var permissionRow: some View {
        let (icon, tint, text): (String, Color, String) = {
            switch model.permission {
            case .fullDiskAccess: return ("checkmark.seal", MCTheme.success, L("deepscan.permission.full"))
            case .partialAccess: return ("exclamationmark.triangle", MCTheme.warning, L("deepscan.permission.partial"))
            case .protectedByOS: return ("lock", .secondary, L("deepscan.permission.protected"))
            case .scanError: return ("xmark.octagon", MCTheme.danger, L("deepscan.permission.error"))
            }
        }()
        return Label(text, systemImage: icon)
            .font(MCFont.secondaryBody)
            .foregroundStyle(tint == .secondary ? Color.secondary : tint)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: scanning

    private var scanning: some View {
        VStack(alignment: .leading, spacing: MCSpacing.lg) {
            Text(L("deepscan.scanning_title")).font(MCFont.pageTitle)
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                ForEach(DeepScanPhase.allCases.filter { $0 != .done && $0 != .cancelledPartial }, id: \.self) { phase in
                    HStack(spacing: MCSpacing.xs) {
                        Image(systemName: phaseIcon(phase))
                            .foregroundStyle(phaseTint(phase))
                        Text(dsPhaseName(phase))
                            .font(MCFont.secondaryBody)
                            .foregroundStyle(phase == model.progress.phase ? .primary : .secondary)
                    }
                }
            }
            MCCard {
                VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                    Text(L("deepscan.progress.items", "\(model.progress.nodesScanned)",
                           DeepScanFormat.bytes(model.progress.bytesObserved)))
                        .font(MCFont.metric)
                    Text(L("deepscan.progress.blocked", "\(model.progress.permissionDeniedCount)"))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                    Text(L("deepscan.progress.elapsed", String(format: "%.0f", model.progress.elapsed)))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if model.progress.isPaused {
                    Button(L("common.resume")) { model.resume() }
                } else {
                    Button(L("common.pause")) { model.pause() }
                }
                Button(L("common.cancel"), role: .destructive) { model.cancel() }
            }
            Spacer()
        }
        .padding(MCSpacing.page)
        .frame(maxWidth: 720, alignment: .leading)
    }

    private func phaseIcon(_ p: DeepScanPhase) -> String {
        let order = DeepScanPhase.allCases
        guard let i = order.firstIndex(of: p), let cur = order.firstIndex(of: model.progress.phase) else {
            return "circle"
        }
        if i < cur { return "checkmark.circle.fill" }
        if i == cur { return "arrow.triangle.2.circlepath" }
        return "circle"
    }
    private func phaseTint(_ p: DeepScanPhase) -> Color {
        p == model.progress.phase ? MCColor.teal : .secondary
    }

    // MARK: results

    private var results: some View {
        HStack(spacing: 0) {
            categoryRail
            Divider()
            resultsList
        }
    }

    private var categoryRail: some View {
        List(selection: $model.selectedCategory) {
            Button {
                model.selectedCategory = nil
            } label: {
                HStack {
                    Label(L("deepscan.overview"), systemImage: "square.grid.2x2")
                    Spacer()
                    Text("\(model.candidates.count)").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            ForEach(model.categoryGroups) { group in
                Button {
                    model.selectedCategory = group.category
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(dsCategoryName(group.category))
                            Spacer()
                            Text("\(group.count)").foregroundStyle(.secondary)
                        }
                        Text(L("deepscan.rail.summary",
                               DeepScanFormat.bytes(group.reviewableBytes), "\(group.protectedCount)"))
                            .font(MCFont.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 260)
        .listStyle(.sidebar)
    }

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: MCSpacing.sm) {
            HStack {
                TextField(L("deepscan.search_placeholder"), text: $model.results.filter.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Menu(L("deepscan.filter.risk")) {
                    Button(L("deepscan.filter.risk.any")) { model.results.filter.maxRisk = nil }
                    Button(L("deepscan.filter.risk.low_only")) { model.results.filter.maxRisk = .safe }
                    Button(L("deepscan.filter.risk.review_or_lower")) { model.results.filter.maxRisk = .review }
                }
                Menu(L("deepscan.sort")) {
                    ForEach(DeepScanSort.allCases, id: \.self) { s in
                        Button(dsSortName(s)) { model.results.sort = s }
                    }
                }
                Toggle(L("deepscan.protected_only"), isOn: $model.results.filter.protectedOnly)
                    .toggleStyle(.checkbox)
                Spacer()
                Button {
                    model.openPlan()
                } label: {
                    Label(L("deepscan.review_plan", "\(model.selectedIDs.count)"),
                          systemImage: "tray.and.arrow.down")
                }
                .disabled(model.selectedIDs.isEmpty)
            }

            Text(L("deepscan.results.summary", "\(model.totalMatching())",
                   DeepScanFormat.bytes(model.reviewableBytes())))
                .font(MCFont.caption).foregroundStyle(.secondary)

            List {
                ForEach(model.rows()) { row in
                    DeepScanRowView(row: row,
                                    isSelected: model.selectedIDs.contains(row.id),
                                    toggle: { model.toggle(row) })
                }
                if model.totalMatching() > model.visibleCount {
                    Button(L("deepscan.show_more", "\(model.totalMatching() - model.visibleCount)")) {
                        model.visibleCount += model.pageLimit
                    }
                }
            }
            .listStyle(.inset)
        }
        .padding(MCSpacing.page)
    }
}

// MARK: - Row

struct DeepScanRowView: View {
    let row: DeepScanDisplayRow
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                ForEach(Array(row.whyBullets.enumerated()), id: \.offset) { _, b in
                    Label(b, systemImage: "checkmark.circle").font(MCFont.caption)
                }
                Divider()
                grid(L("deepscan.row.where"), row.whereText)
                grid(L("deepscan.row.size"), L("deepscan.row.size_value", row.size, row.allocatedSize))
                grid(L("deepscan.row.reclaimable"), row.estimatedReclaimable)
                grid(L("deepscan.row.confidence"), dsConfidenceName(row.candidate.confidence))
                grid(L("deepscan.row.rebuild"), dsRebuildName(row.candidate.reconstructability))
                grid(L("deepscan.row.last_activity"), row.lastActivity)
                grid(L("deepscan.row.owner"), row.owner)
                grid(L("deepscan.row.if_removed"), row.ifRemoved)
                if let pr = row.protectedReason {
                    Label(pr, systemImage: "lock.fill")
                        .font(MCFont.caption).foregroundStyle(MCTheme.warning)
                }
            }
            .padding(.vertical, MCSpacing.xxs)
        } label: {
            HStack(spacing: MCSpacing.xs) {
                if row.isProtected {
                    MCStatusBadge(L("deepscan.badge.protected"), status: .attention)
                } else {
                    Toggle("", isOn: Binding(get: { isSelected }, set: { _ in toggle() }))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.what).font(MCFont.body)
                    Text(row.whereText).font(MCFont.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Text(row.size).font(MCFont.secondaryBody).foregroundStyle(.secondary)
                riskBadge
            }
        }
    }

    private var riskBadge: some View {
        let status: MCStatus = {
            switch row.candidate.risk {
            case .safe: return .success
            case .review: return .active
            case .highRisk: return .attention
            case .protected: return .attention
            }
        }()
        return MCStatusBadge(dsRiskName(row.candidate.risk), status: status)
    }

    private func grid(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: MCSpacing.xs) {
            Text(k).font(MCFont.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(v).font(MCFont.caption).textSelection(.enabled)
        }
    }
}

// MARK: - Plan sheet

struct DeepScanPlanSheet: View {
    let plan: DeepScanCleanupPlan
    let executionAvailable: Bool
    let report: DeepScanExecutionReport?
    let onExecute: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            Text(L("deepscan.plan.title")).font(MCFont.pageTitle)

            HStack(spacing: MCSpacing.lg) {
                stat(L("deepscan.plan.selected"), "\(plan.selected.count)")
                stat(L("deepscan.plan.logical"), DeepScanFormat.bytes(plan.totalLogicalBytes))
                stat(L("deepscan.plan.reclaimable"),
                     L("deepscan.reclaimable_prefix", DeepScanFormat.bytes(plan.estimatedReclaimableBytes)))
            }

            if !plan.riskSummaryByClass.isEmpty {
                Text(L("deepscan.plan.risk_prefix", plan.riskSummaryByClass
                    .map { L("deepscan.plan.summary_item", "\($0.value)", dsRiskName($0.key)) }
                    .joined(separator: ", ")))
                    .font(MCFont.caption).foregroundStyle(.secondary)
            }
            if !plan.rebuildSummaryByKind.isEmpty {
                Text(L("deepscan.plan.rebuild_prefix", plan.rebuildSummaryByKind
                    .map { L("deepscan.plan.summary_item", "\($0.value)", dsRebuildName($0.key)) }
                    .joined(separator: ", ")))
                    .font(MCFont.caption).foregroundStyle(.secondary)
            }

            if !plan.changedSinceScan.isEmpty {
                MCCard {
                    VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                        Text(L("deepscan.plan.changed_title")).font(MCFont.sectionTitle)
                        ForEach(plan.changedSinceScan) { c in
                            Text(L("deepscan.plan.changed_line",
                                   L("deepscan.skip.\(deepScanSkipReasonSlug(c.reason))"),
                                   (c.path as NSString).lastPathComponent))
                                .font(MCFont.caption)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !plan.protectedHeldBack.isEmpty {
                Text(L("deepscan.plan.protected_note", "\(plan.protectedHeldBack.count)"))
                    .font(MCFont.caption).foregroundStyle(MCTheme.warning)
            }

            List(plan.selected) { line in
                HStack {
                    Text(line.row.what)
                    Spacer()
                    Text(line.row.size).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 160)

            if let report {
                Text(report.gated
                     ? L("deepscan.plan.result_gated")
                     : L("deepscan.plan.result_done", "\(report.executed.count)", "\(report.skipped.count)"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(report.executed.isEmpty ? .secondary : MCTheme.success)
            }

            HStack {
                Button(L("deepscan.plan.close")) { dismiss() }
                Spacer()
                Button {
                    onExecute()
                } label: {
                    Label(executionAvailable
                          ? L("deepscan.plan.move_to_trash", "\(plan.movedToTrash.count)")
                          : L("deepscan.plan.exec_disabled"),
                          systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!executionAvailable || plan.movedToTrash.isEmpty)
            }
        }
        .padding(MCSpacing.lg)
        .frame(width: 560, height: 560)
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading) {
            Text(k).font(MCFont.caption).foregroundStyle(.secondary)
            Text(v).font(MCFont.metric)
        }
    }
}

// MARK: - Settings sheet

struct DeepScanSettingsSheet: View {
    @Binding var settings: DeepScanSettings
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            Text(L("deepscan.settings.title")).font(MCFont.pageTitle)
            Form {
                Section(L("deepscan.settings.scope")) {
                    Toggle(L("deepscan.settings.external"), isOn: $settings.scanExternalVolumes)
                    Toggle(L("deepscan.settings.developer"), isOn: $settings.developerAnalysisEnabled)
                    Toggle(L("deepscan.settings.ai"), isOn: $settings.aiAnalysisEnabled)
                    Toggle(L("deepscan.settings.system"), isOn: $settings.systemAnalysisEnabled)
                    Toggle(L("deepscan.settings.cloud"), isOn: $settings.cloudAnalysisEnabled)
                }
                Section(L("deepscan.settings.git_section")) {
                    Toggle(L("deepscan.settings.git_verify"), isOn: $settings.gitNetworkVerificationEnabled)
                    Text(L("deepscan.settings.git_note"))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                }
                Section {
                    Text(L("deepscan.settings.protections_note"))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Spacer()
                Button(L("deepscan.settings.done")) { onSave(); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(MCSpacing.lg)
        .frame(width: 460, height: 460)
    }
}
