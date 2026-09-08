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

@MainActor
@Observable
final class DeepScanViewModel {
    enum Phase: Equatable { case idle, scanning, results }

    var phase: Phase = .idle
    var progress = DeepScanProgressModel()
    var permission: DeepScanPermissionState = .partialAccess
    var settings = DeepScanSettings.load()

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
        let roots = settings.scanRoots(home: home)
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
        .navigationTitle("Deep Scan")
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
                Text("Deep Scan")
                    .font(MCFont.pageTitle)
                Text("A read-only, evidence-based look at where storage goes: apps and leftovers, AI/LLM stores, developer output, Git projects, system remnants, temporary files, installers, cloud copies, and large old files. Nothing is deleted during analysis.")
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                MCCard {
                    VStack(alignment: .leading, spacing: MCSpacing.sm) {
                        permissionRow
                        Divider()
                        Label(model.settings.scanExternalVolumes
                              ? "Home volume + \(model.settings.includedExternalVolumeRoots.count) external"
                              : "Home volume only (external volumes are opt-in)",
                              systemImage: "internaldrive")
                            .font(MCFont.secondaryBody)
                        Label("Analysis is read-only. No cleanup happens while scanning.",
                              systemImage: "lock.shield")
                            .font(MCFont.secondaryBody)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: MCSpacing.sm) {
                    Button {
                        model.startScan()
                    } label: {
                        Label("Start Deep Scan", systemImage: "magnifyingglass")
                            .frame(maxWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Scan Options…") { model.showSettings = true }
                        .controlSize(.large)
                }

                if !model.executionAvailable {
                    Label("Cleanup execution is disabled in this build. Deep Scan can review and plan, but the Move to Trash step is turned off until a maintainer enables it.",
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
            case .fullDiskAccess: return ("checkmark.seal", MCTheme.success, "Full Disk Access is on — the whole home volume can be analysed.")
            case .partialAccess: return ("exclamationmark.triangle", MCTheme.warning, "Partial access — some folders are hidden by macOS. Grant Full Disk Access in System Settings › Privacy & Security for a complete picture.")
            case .protectedByOS: return ("lock", .secondary, "Some locations are protected by macOS and will be reported as such.")
            case .scanError: return ("xmark.octagon", MCTheme.danger, "The last scan hit an error reading part of the disk.")
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
            Text("Scanning…").font(MCFont.pageTitle)
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                ForEach(DeepScanPhase.allCases.filter { $0 != .done && $0 != .cancelledPartial }, id: \.self) { phase in
                    HStack(spacing: MCSpacing.xs) {
                        Image(systemName: phaseIcon(phase))
                            .foregroundStyle(phaseTint(phase))
                        Text(phase.rawValue)
                            .font(MCFont.secondaryBody)
                            .foregroundStyle(phase == model.progress.phase ? .primary : .secondary)
                    }
                }
            }
            MCCard {
                VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                    Text("\(model.progress.nodesScanned) items · \(DeepScanFormat.bytes(model.progress.bytesObserved)) observed")
                        .font(MCFont.metric)
                    Text("\(model.progress.permissionDeniedCount) folders blocked by permissions")
                        .font(MCFont.caption).foregroundStyle(.secondary)
                    Text(String(format: "Elapsed %.0fs", model.progress.elapsed))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if model.progress.isPaused {
                    Button("Resume") { model.resume() }
                } else {
                    Button("Pause") { model.pause() }
                }
                Button("Cancel", role: .destructive) { model.cancel() }
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
                    Label("Overview", systemImage: "square.grid.2x2")
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
                            Text(group.category.displayName)
                            Spacer()
                            Text("\(group.count)").foregroundStyle(.secondary)
                        }
                        Text("≈ \(DeepScanFormat.bytes(group.reviewableBytes)) reviewable · \(group.protectedCount) protected")
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
                TextField("Search path, owner, kind…", text: $model.results.filter.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Menu("Risk") {
                    Button("Any") { model.results.filter.maxRisk = nil }
                    Button("Low only") { model.results.filter.maxRisk = .safe }
                    Button("Review or lower") { model.results.filter.maxRisk = .review }
                }
                Menu("Sort") {
                    ForEach(DeepScanSort.allCases, id: \.self) { s in
                        Button(s.rawValue.capitalized) { model.results.sort = s }
                    }
                }
                Toggle("Protected only", isOn: $model.results.filter.protectedOnly)
                    .toggleStyle(.checkbox)
                Spacer()
                Button {
                    model.openPlan()
                } label: {
                    Label("Review Cleanup Plan (\(model.selectedIDs.count))", systemImage: "tray.and.arrow.down")
                }
                .disabled(model.selectedIDs.isEmpty)
            }

            Text("\(model.totalMatching()) items · ≈ \(DeepScanFormat.bytes(model.reviewableBytes())) reviewable")
                .font(MCFont.caption).foregroundStyle(.secondary)

            List {
                ForEach(model.rows()) { row in
                    DeepScanRowView(row: row,
                                    isSelected: model.selectedIDs.contains(row.id),
                                    toggle: { model.toggle(row) })
                }
                if model.totalMatching() > model.visibleCount {
                    Button("Show more (\(model.totalMatching() - model.visibleCount) remaining)") {
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
                grid("Where", row.whereText)
                grid("Size", "\(row.size)  (allocated \(row.allocatedSize))")
                grid("Reclaimable", row.estimatedReclaimable)
                grid("Confidence", row.confidence)
                grid("Rebuild", row.reconstructability)
                grid("Last activity", row.lastActivity)
                grid("Owner", row.owner)
                grid("If removed", row.ifRemoved)
                if let pr = row.protectedReason {
                    Label(pr, systemImage: "lock.fill")
                        .font(MCFont.caption).foregroundStyle(MCTheme.warning)
                }
            }
            .padding(.vertical, MCSpacing.xxs)
        } label: {
            HStack(spacing: MCSpacing.xs) {
                if row.isProtected {
                    MCStatusBadge("Protected", status: .attention)
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
        return MCStatusBadge(row.risk, status: status)
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
            Text("Cleanup Plan").font(MCFont.pageTitle)

            HStack(spacing: MCSpacing.lg) {
                stat("Selected", "\(plan.selected.count)")
                stat("Logical", DeepScanFormat.bytes(plan.totalLogicalBytes))
                stat("Reclaimable", "≈ " + DeepScanFormat.bytes(plan.estimatedReclaimableBytes))
            }

            if !plan.riskSummary.isEmpty {
                Text("Risk: " + plan.riskSummary.map { "\($0.value)× \($0.key)" }.joined(separator: ", "))
                    .font(MCFont.caption).foregroundStyle(.secondary)
            }
            if !plan.rebuildCostSummary.isEmpty {
                Text("Rebuild: " + plan.rebuildCostSummary.map { "\($0.value)× \($0.key)" }.joined(separator: ", "))
                    .font(MCFont.caption).foregroundStyle(.secondary)
            }

            if !plan.changedSinceScan.isEmpty {
                MCCard {
                    VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                        Text("Skipped — changed since scan").font(MCFont.sectionTitle)
                        ForEach(plan.changedSinceScan) { c in
                            Text("• \(c.reason): \((c.path as NSString).lastPathComponent)")
                                .font(MCFont.caption)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !plan.protectedHeldBack.isEmpty {
                Text("\(plan.protectedHeldBack.count) selected item(s) are protected and will not be touched.")
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
                     ? "Execution is disabled — nothing was moved."
                     : "Moved \(report.executed.count) to Trash · \(report.skipped.count) skipped.")
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(report.executed.isEmpty ? .secondary : MCTheme.success)
            }

            HStack {
                Button("Close") { dismiss() }
                Spacer()
                Button {
                    onExecute()
                } label: {
                    Label(executionAvailable ? "Move \(plan.movedToTrash.count) to Trash" : "Execution disabled",
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
            Text("Deep Scan Options").font(MCFont.pageTitle)
            Form {
                Section("Scope") {
                    Toggle("Analyse external volumes (opt-in)", isOn: $settings.scanExternalVolumes)
                    Toggle("Developer projects & build output", isOn: $settings.developerAnalysisEnabled)
                    Toggle("AI / LLM storage", isOn: $settings.aiAnalysisEnabled)
                    Toggle("System & settings remnants", isOn: $settings.systemAnalysisEnabled)
                    Toggle("Cloud-backed locations (detection only)", isOn: $settings.cloudAnalysisEnabled)
                }
                Section("Git") {
                    Toggle("Verify remotes over the network", isOn: $settings.gitNetworkVerificationEnabled)
                    Text("When off, repositories with an unverified remote are treated conservatively.")
                        .font(MCFont.caption).foregroundStyle(.secondary)
                }
                Section {
                    Text("Safety protections, the protected-path policy, and Trash-only execution are not configurable.")
                        .font(MCFont.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Spacer()
                Button("Done") { onSave(); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(MCSpacing.lg)
        .frame(width: 460, height: 460)
    }
}
