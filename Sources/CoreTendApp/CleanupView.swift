import SwiftUI
import ScanCore
import SafetyCore
import FileRules
import DesignSystem
import Persistence

@MainActor
@Observable
final class CleanupViewModel {
    enum Phase: Equatable {
        case idle, scanning, review, running, done(freed: Int64, dryRun: Bool), failed(String)
    }

    var phase: Phase = .idle
    var findings: [ScanFinding] = []
    var selectedIDs: Set<UUID> = []
    var scannedCount = 0
    var totalBytes: Int64 = 0
    var totalFindingCount = 0
    var dryRun = true
    var isScanPaused = false
    private var dryRunDefaultLoaded = false

    private var scanTask: Task<Void, Never>?
    private var pauseController: ScanPauseController?

    /// Applies the persisted "dry-run by default" setting once, before the user
    /// has a chance to toggle it manually. Without this the Settings toggle is
    /// orphaned — the view would always start in dry-run regardless of the setting.
    func loadDryRunDefault() async {
        guard !dryRunDefaultLoaded else { return }
        dryRunDefaultLoaded = true
        dryRun = AppEnvironment.dryRunEnabled(
            fromSetting: (try? await AppEnvironment.shared.store?.setting("dryRunDefault")) ?? nil)
    }

    var isDisplayTruncated: Bool { totalFindingCount > findings.count }

    var selectedBytes: Int64 {
        findings.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.logicalSize }
    }

    struct RuleGroup: Identifiable {
        let ruleID: String
        let name: String
        let explanation: String
        var findings: [ScanFinding]
        var bytes: Int64 { findings.reduce(0) { $0 + $1.logicalSize } }
        var id: String { ruleID }
    }

    /// Findings grouped by rule, largest group first.
    var groups: [RuleGroup] {
        var byRule: [String: RuleGroup] = [:]
        let names = Dictionary(uniqueKeysWithValues: UserCleanupRules.all.map { ($0.id, ($0.name, $0.explanation)) })
        for finding in findings {
            byRule[finding.ruleID, default: RuleGroup(
                ruleID: finding.ruleID,
                name: names[finding.ruleID]?.0 ?? finding.ruleID,
                explanation: names[finding.ruleID]?.1 ?? finding.explanation,
                findings: []
            )].findings.append(finding)
        }
        return byRule.values.sorted { $0.bytes > $1.bytes }
    }

    /// Each group's share of found bytes, largest first — feeds MCFragmentView's cluster sizes.
    var normalizedGroupWeights: [Double] {
        let all = groups
        let total = all.reduce(0) { $0 + $1.bytes }
        guard total > 0 else { return [] }
        return all.map { max(0.1, Double($0.bytes) / Double(total)) }
    }

    func selectionState(for group: RuleGroup) -> Bool {
        group.findings.allSatisfy { selectedIDs.contains($0.id) }
    }

    func setSelection(_ on: Bool, for group: RuleGroup) {
        for finding in group.findings {
            if on { selectedIDs.insert(finding.id) } else { selectedIDs.remove(finding.id) }
        }
    }

    func startScan() {
        guard phase != .scanning else { return }
        phase = .scanning
        findings = []
        selectedIDs = []
        scannedCount = 0
        totalBytes = 0
        totalFindingCount = 0
        isScanPaused = false
        let pauseController = ScanPauseController()
        self.pauseController = pauseController
        scanTask = Task {
            let excluded = (try? await AppEnvironment.shared.store?.exclusions()) ?? []
            let engine = ScanEngine(configuration: ScanConfiguration(excludedPaths: excluded))
            for await event in engine.run(rules: UserCleanupRules.all, pauseController: pauseController) {
                switch event {
                case .started: break
                case let .progress(scanned, _):
                    scannedCount = scanned
                case let .finding(finding):
                    // ponytail: cap displayed findings at 5000 to bound memory; paginate later.
                    if findings.count < 5000 {
                        findings.append(finding)
                        if finding.preselected { selectedIDs.insert(finding.id) }
                    }
                    totalFindingCount += 1
                    totalBytes += finding.logicalSize
                case .error: break
                case let .finished(scanned, bytes):
                    scannedCount = scanned
                    totalBytes = bytes
                    phase = .review
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Cleanup scan: \(findings.count) items found",
                        itemCount: findings.count, bytes: bytes, dryRun: true))
                case .cancelled:
                    isScanPaused = false
                    phase = .idle
                }
            }
            self.pauseController = nil
        }
    }

    func pauseScan() {
        guard phase == .scanning, !isScanPaused else { return }
        isScanPaused = true
        Task { await pauseController?.pause() }
    }

    func resumeScan() {
        guard phase == .scanning, isScanPaused else { return }
        isScanPaused = false
        Task { await pauseController?.resume() }
    }

    func cancelScan() {
        isScanPaused = false
        scanTask?.cancel()
        Task { await pauseController?.resume() }
    }

    func runCleanup() {
        guard phase == .review else { return }
        phase = .running
        let selected = findings.filter { selectedIDs.contains($0.id) }
        let isDryRun = dryRun
        Task {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let validator = PathValidator(allowedRoots: UserCleanupRules.allowedRoots(home: home))
            let center = SafetyCenter(validator: validator, dryRun: isDryRun, sink: AppEnvironment.shared.store)
            var approved: [ApprovedFileOperation] = []
            for finding in selected {
                if let op = try? await center.approve(
                    url: finding.url, logicalSize: finding.logicalSize,
                    ruleID: finding.ruleID, risk: finding.risk
                ) {
                    approved.append(op)
                }
            }
            let result = await center.execute(approved)
            let freed = result.executed.reduce(0) { $0 + $1.logicalSize }
            phase = .done(freed: freed, dryRun: result.wasDryRun)
            AppEnvironment.shared.record(ActivityRecord(
                kind: .cleanup,
                summary: result.wasDryRun
                    ? "Dry run: \(result.executed.count) items simulated"
                    : "Moved \(result.executed.count) items to Trash",
                itemCount: result.executed.count, bytes: freed, dryRun: result.wasDryRun))
        }
    }
}

struct CleanupView: View {
    @State private var model = CleanupViewModel()

    var body: some View {
        Group {
            switch model.phase {
            case .idle:
                idleView
            case .scanning:
                scanningView
            case .review, .running:
                reviewView.padding(MCSpacing.page)
            case let .done(freed, dryRun):
                doneView(freed: freed, dryRun: dryRun)
            case let .failed(message):
                Text(L("cleanup.failed", message)).foregroundStyle(MCTheme.danger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(MCSpacing.page)
            }
        }
        .navigationTitle(L("module.storage"))
        .accessibilityIdentifier("storage.root")
        .task { await model.loadDryRunDefault() }
    }

    // MARK: - Idle (editorial left-aligned layout with category overview)

    private var idleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.xl) {
                HStack(alignment: .top, spacing: MCSpacing.lg) {
                    MCFragmentView(groupWeights: [], phase: .rest)
                        .frame(width: 72, height: 72)
                        .accessibilityLabel(MCFragmentView(groupWeights: [], phase: .rest).accessibilityDescription)
                    VStack(alignment: .leading, spacing: MCSpacing.xs) {
                        Text(L("cleanup.idle.title"))
                            .font(MCFont.pageTitle)
                        Text(L("cleanup.idle.safety_note"))
                            .font(MCFont.secondaryBody)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: MCSpacing.sm) {
                    MCSectionHeader(L("cleanup.idle.what_is_scanned"))
                    MCFeatureRow(L("cleanup.category.caches"),
                                 subtitle: L("cleanup.category.caches.detail"),
                                 icon: "folder.badge.gearshape")
                    MCFeatureRow(L("cleanup.category.logs"),
                                 subtitle: L("cleanup.category.logs.detail"),
                                 icon: "doc.text")
                    MCFeatureRow(L("cleanup.category.xcode"),
                                 subtitle: L("cleanup.category.xcode.detail"),
                                 icon: "hammer")
                    MCFeatureRow(L("cleanup.category.downloads"),
                                 subtitle: L("cleanup.category.downloads.detail"),
                                 icon: "arrow.down.circle")
                }

                Button(L("cleanup.start_scan")) { model.startScan() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("storage.scan.start")
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: 520, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background(MCColor.background)
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: MCSpacing.md) {
            MCFragmentView(groupWeights: model.normalizedGroupWeights, phase: .scanning)
                .frame(width: 120, height: 120)
                .accessibilityLabel(MCFragmentView(groupWeights: [], phase: .scanning).accessibilityDescription)
            Text(L("cleanup.scanning_progress", model.scannedCount, mcFormatBytes(model.totalBytes)))
                .monospacedDigit()
            HStack(spacing: MCSpacing.sm) {
                if model.isScanPaused {
                    Button(L("common.resume")) { model.resumeScan() }
                        .keyboardShortcut("r", modifiers: [])
                        .accessibilityHint(L("cleanup.resume_hint"))
                        .accessibilityIdentifier("storage.scan.resume")
                } else {
                    Button(L("common.pause")) { model.pauseScan() }
                        .keyboardShortcut("p", modifiers: [])
                        .accessibilityHint(L("cleanup.pause_hint"))
                        .accessibilityIdentifier("storage.scan.pause")
                }
                Button(L("common.cancel")) { model.cancelScan() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("storage.scan.cancel")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review

    private var reviewView: some View {
        VStack(alignment: .leading, spacing: MCSpacing.sm) {
            HStack {
                MCFragmentView(groupWeights: model.normalizedGroupWeights,
                               phase: model.phase == .running ? .executing : .review)
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                    Text(L("cleanup.review.selected", model.findings.count, mcFormatBytes(model.selectedBytes)))
                        .font(MCFont.cardTitle)
                    if model.isDisplayTruncated {
                        Text(L("cleanup.review.truncated", model.findings.count, model.totalFindingCount, mcFormatBytes(model.totalBytes)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle(L("common.dry_run"), isOn: $model.dryRun).toggleStyle(.switch)
                Button(model.dryRun ? L("cleanup.simulate") : L("cleanup.move_to_trash")) {
                    model.runCleanup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.phase == .running || model.selectedIDs.isEmpty)
            }
            List {
                ForEach(model.groups) { group in
                    DisclosureGroup {
                        ForEach(group.findings) { finding in
                            findingRow(finding)
                        }
                    } label: {
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { model.selectionState(for: group) },
                                set: { model.setSelection($0, for: group) }
                            ))
                            .labelsHidden()
                            VStack(alignment: .leading) {
                                Text(group.name).font(MCFont.cardTitle)
                                Text(group.explanation)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(L("cleanup.group.item_count", group.findings.count))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(mcFormatBytes(group.bytes))
                                .monospacedDigit().font(.callout.weight(.medium))
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func findingRow(_ finding: ScanFinding) -> some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { model.selectedIDs.contains(finding.id) },
                set: { on in
                    if on { model.selectedIDs.insert(finding.id) }
                    else { model.selectedIDs.remove(finding.id) }
                }
            ))
            .labelsHidden()
            .accessibilityLabel(L("cleanup.select_item", finding.url.lastPathComponent))
            VStack(alignment: .leading) {
                Text(finding.url.lastPathComponent)
                Text(finding.url.deletingLastPathComponent().path)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(mcFormatBytes(finding.logicalSize))
                .monospacedDigit().foregroundStyle(.secondary)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([finding.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L("common.reveal_in_finder"))
            .help(L("common.reveal_in_finder"))
        }
    }

    private func doneView(freed: Int64, dryRun: Bool) -> some View {
        VStack(spacing: MCSpacing.md) {
            MCFragmentView(groupWeights: model.normalizedGroupWeights, phase: .success)
                .frame(width: 120, height: 120)
                .accessibilityLabel(MCFragmentView(groupWeights: [], phase: .success).accessibilityDescription)
            Text(dryRun
                 ? L("cleanup.done.dryrun", mcFormatBytes(freed))
                 : L("cleanup.done.moved", mcFormatBytes(freed)))
                .font(.title3.weight(.semibold))
            Button(L("smartcare.scan_again")) { model.startScan() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
