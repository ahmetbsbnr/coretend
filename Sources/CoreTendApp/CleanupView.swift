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
        case idle, scanning, review, running, done(freed: Int64), failed(String)
    }

    var phase: Phase = .idle
    var findings: [ScanFinding] = []
    var selectedIDs: Set<UUID> = []
    var scannedCount = 0
    var totalBytes: Int64 = 0
    var totalFindingCount = 0
    var isScanPaused = false

    private var scanTask: Task<Void, Never>?
    private var pauseController: ScanPauseController?

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
                        itemCount: findings.count, bytes: bytes))
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
        Task {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let validator = PathValidator(allowedRoots: UserCleanupRules.allowedRoots(home: home))
            let center = SafetyCenter(validator: validator, sink: AppEnvironment.shared.store)
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
            phase = .done(freed: freed)
            AppEnvironment.shared.record(ActivityRecord(
                kind: .cleanup,
                summary: "Moved \(result.executed.count) items to Trash",
                itemCount: result.executed.count, bytes: freed))
        }
    }
}

struct CleanupView: View {
    @State private var model = CleanupViewModel()
    @State private var showMoveConfirmation = false

    var body: some View {
        Group {
            switch model.phase {
            case .idle:
                idleView
            case .scanning:
                scanningView
            case .review, .running:
                reviewView.padding(MCSpacing.page)
            case let .done(freed):
                doneView(freed: freed)
            case let .failed(message):
                Text(L("cleanup.failed", message)).foregroundStyle(MCTheme.danger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(MCSpacing.page)
            }
        }
        .navigationTitle(L("module.storage"))
        .accessibilityIdentifier("storage.root")
        .confirmationDialog(
            L("common.trash_confirm.title"),
            isPresented: $showMoveConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("common.trash_confirm.action"), role: .destructive) {
                model.runCleanup()
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("common.trash_confirm.message"))
        }
    }

    // MARK: - Idle (editorial left-aligned layout with category overview)

    private var idleView: some View {
        GeometryReader { proxy in
        ScrollView {
            VStack(spacing: MCSpacing.xl) {
                VStack(spacing: MCSpacing.xs) {
                    Text(L("cleanup.idle.title"))
                        .font(MCFont.pageTitle)
                        .multilineTextAlignment(.center)
                    Text(L("cleanup.idle.safety_note"))
                        .font(MCFont.secondaryBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .mcAppear()

                MCScanButton(L("cleanup.start_scan")) { model.startScan() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("storage.scan.start")
                    .mcAppear(delay: 0.06)

                MCCard {
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
                }
                .frame(maxWidth: 480)
                .mcAppear(delay: 0.12)
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
        }
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: MCSpacing.lg) {
            MCScanStage(isScanning: !model.isScanPaused) {
                Text(L("cleanup.scanning_progress", model.scannedCount, mcFormatBytes(model.totalBytes)))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L("cleanup.scanning_progress", model.scannedCount, mcFormatBytes(model.totalBytes)))
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: MCSpacing.lg) {
                VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                    // The recoverable total is the whole point of this screen.
                    Text(mcFormatBytes(model.totalBytes))
                        .font(MCFont.displayMetric)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(L("cleanup.review.selected", model.findings.count, mcFormatBytes(model.selectedBytes)))
                        .font(MCFont.secondaryBody)
                        .foregroundStyle(.secondary)
                    if model.isDisplayTruncated {
                        Text(L("cleanup.review.truncated", model.findings.count, model.totalFindingCount, mcFormatBytes(model.totalBytes)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(L("cleanup.move_to_trash")) {
                    showMoveConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.phase == .running || model.selectedIDs.isEmpty)
            }
            .padding(.horizontal, MCSpacing.page)
            .padding(.top, MCSpacing.lg)
            .padding(.bottom, MCSpacing.md)

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

    private func doneView(freed: Int64) -> some View {
        MCSuccessState(
            title: L("cleanup.done.moved", mcFormatBytes(freed)),
            actionTitle: L("smartcare.scan_again")) { model.startScan() }
    }
}
