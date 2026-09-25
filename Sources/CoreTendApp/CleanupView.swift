// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

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
        case idle, scanning, review, running, done(ExecutionOutcome), failed(String)
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
            let outcome = ExecutionOutcome(result: await center.execute(approved))
            phase = .done(outcome)
            // Both counts reach the log, not just the successes: SafetyCore
            // skipping a path that changed between approval and execution is
            // the product working, and a record that omits it reads as if
            // everything went through.
            AppEnvironment.shared.record(ActivityRecord(
                kind: .cleanup,
                summary: outcome.annotate("Moved \(outcome.executedCount) items to Trash"),
                itemCount: outcome.executedCount, bytes: outcome.freedBytes))
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
                reviewView
            case let .done(outcome):
                doneView(outcome)
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

    // MARK: - Idle: a briefing — what will be examined, then one command

    private var idleView: some View {
        VStack(spacing: 0) {
            MCPageHeader(L("module.storage"), eyebrow: L("sidebar.reclaim"),
                         subtitle: L("cleanup.idle.safety_note"),
                         icon: ModuleID.cleanup.systemImage)
            ScrollView {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: MCSpacing.xl) {
                        launchColumn.frame(width: 320)
                        scopePanel
                    }
                    VStack(alignment: .leading, spacing: MCSpacing.lg) {
                        launchColumn
                        scopePanel
                    }
                }
                .padding(MCSpacing.page)
                .frame(maxWidth: MCSize.contentMax, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var launchColumn: some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            Text(L("cleanup.idle.title"))
                .font(MCFont.heroTitle)
                .kerning(MCTracking.title)
                .fixedSize(horizontal: false, vertical: true)
            MCScanButton(L("cleanup.start_scan")) { model.startScan() }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("storage.scan.start")
            Label(L("dashboard.status.recoverable"), systemImage: "arrow.uturn.backward")
                .font(MCFont.caption)
                .foregroundStyle(.secondary)
        }
        .mcAppear()
    }

    private var scopePanel: some View {
        MCPanel(L("cleanup.idle.what_is_scanned")) {
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                MCFeatureRow(L("cleanup.category.caches"),
                             subtitle: L("cleanup.category.caches.detail"),
                             icon: "folder.badge.gearshape")
                MCHairline()
                MCFeatureRow(L("cleanup.category.logs"),
                             subtitle: L("cleanup.category.logs.detail"),
                             icon: "doc.text")
                MCHairline()
                MCFeatureRow(L("cleanup.category.xcode"),
                             subtitle: L("cleanup.category.xcode.detail"),
                             icon: "hammer")
                MCHairline()
                MCFeatureRow(L("cleanup.category.downloads"),
                             subtitle: L("cleanup.category.downloads.detail"),
                             icon: "arrow.down.circle")
            }
        }
        .frame(maxWidth: MCSize.columnMax)
        .mcAppear(delay: 0.05)
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: MCSpacing.lg) {
            MCScanStage(isScanning: !model.isScanPaused) {
                Text(L("cleanup.scanning_progress", model.scannedCount, mcFormatBytes(model.totalBytes)))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L("cleanup.scanning_progress", model.scannedCount, mcFormatBytes(model.totalBytes)))
            HStack(spacing: MCSpacing.xs) {
                if model.isScanPaused {
                    Button(L("common.resume")) { model.resumeScan() }
                        .buttonStyle(.mcSecondary)
                        .keyboardShortcut("r", modifiers: [])
                        .accessibilityHint(L("cleanup.resume_hint"))
                        .accessibilityIdentifier("storage.scan.resume")
                } else {
                    Button(L("common.pause")) { model.pauseScan() }
                        .buttonStyle(.mcSecondary)
                        .keyboardShortcut("p", modifiers: [])
                        .accessibilityHint(L("cleanup.pause_hint"))
                        .accessibilityIdentifier("storage.scan.pause")
                }
                Button(L("common.cancel")) { model.cancelScan() }
                    .buttonStyle(.mcQuiet)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("storage.scan.cancel")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review: total up top, groups in the middle, commit bar pinned below

    private var reviewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            MCPageHeader(L("module.storage"), eyebrow: L("sidebar.reclaim")) {
                Button(L("smartcare.scan_again")) { model.startScan() }
                    .buttonStyle(.mcQuiet)
                    .disabled(model.phase == .running)
            }
            HStack(alignment: .bottom, spacing: MCSpacing.lg) {
                // The recoverable total is the whole point of this screen.
                MCReadout(L("cleanup.review.found"),
                          value: mcFormatBytes(model.totalBytes), large: true)
                Spacer()
                if model.isDisplayTruncated {
                    Text(L("cleanup.review.truncated", model.findings.count, model.totalFindingCount, mcFormatBytes(model.totalBytes)))
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: 320, alignment: .trailing)
                }
            }
            .padding(.horizontal, MCSpacing.page)
            .padding(.vertical, MCSpacing.md)

            List {
                ForEach(model.groups) { group in
                    DisclosureGroup {
                        ForEach(group.findings) { finding in
                            findingRow(finding)
                        }
                    } label: {
                        HStack(spacing: MCSpacing.sm) {
                            Toggle("", isOn: Binding(
                                get: { model.selectionState(for: group) },
                                set: { model.setSelection($0, for: group) }
                            ))
                            .labelsHidden()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name).font(MCFont.cardTitle)
                                Text(group.explanation)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(L("cleanup.group.item_count", group.findings.count))
                                .font(MCFont.badge).foregroundStyle(.secondary)
                            Text(mcFormatBytes(group.bytes))
                                .font(MCFont.mono.weight(.semibold))
                                .frame(minWidth: 72, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)

            MCActionBar {
                VStack(alignment: .leading, spacing: 2) {
                    MCEyebrow(L("cleanup.review.selected", model.findings.count, mcFormatBytes(model.selectedBytes)))
                    MCMeter(fraction: model.totalBytes > 0 ? Double(model.selectedBytes) / Double(model.totalBytes) : 0,
                            segments: 40, height: 4)
                        .frame(maxWidth: 260)
                }
            } actions: {
                if model.phase == .running { ProgressView().controlSize(.small) }
                Button(L("cleanup.move_to_trash")) {
                    showMoveConfirmation = true
                }
                .buttonStyle(.mcPrimaryLarge)
                .disabled(model.phase == .running || model.selectedIDs.isEmpty)
            }
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
            .accessibilityLabel(
                FindingMetadata.summary(
                    risk: finding.risk, modificationDate: finding.modificationDate
                ).map {
                    L("finding.a11y.evidence",
                      L("cleanup.select_item", finding.url.lastPathComponent), $0)
                } ?? L("cleanup.select_item", finding.url.lastPathComponent)
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(finding.url.lastPathComponent)
                Text(finding.url.deletingLastPathComponent().path)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                // The evidence the scan already had and never showed. Size
                // alone is the weakest of the three signals for deciding
                // whether a file should go; risk also explains why a row is or
                // is not ticked by default.
                if let evidence = FindingMetadata.summary(
                    risk: finding.risk, modificationDate: finding.modificationDate) {
                    Text(evidence)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .lineLimit(1)
                        // VoiceOver reads the row as one sentence; this line is
                        // part of it rather than a separate stop.
                        .accessibilityHidden(true)
                }
            }
            Spacer()
            Text(mcFormatBytes(finding.logicalSize))
                .font(MCFont.mono).foregroundStyle(.secondary)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([finding.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.mcIcon)
            .accessibilityLabel(L("common.reveal_in_finder"))
            .help(L("common.reveal_in_finder"))
        }
    }

    private func doneView(_ outcome: ExecutionOutcome) -> some View {
        MCSuccessState(
            title: outcome.title,
            message: outcome.message,
            actionTitle: L("smartcare.scan_again")) { model.startScan() }
    }
}
