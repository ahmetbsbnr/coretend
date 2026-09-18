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
final class CleanupViewModel: CancellableScan {
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

    /// Set when the scan ran without a trustworthy exclusion list. Nothing is
    /// preselected in that state, and the review screen says why: a folder the
    /// user protected may be in these results, and the app cannot tell.
    var exclusionsUnavailable = false

    var scanTask: Task<Void, Never>?
    var pauseController: ScanPauseController?

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
        exclusionsUnavailable = false
        let pauseController = ScanPauseController()
        self.pauseController = pauseController
        scanTask = Task {
            // Two questions, deliberately asked separately: what to exclude,
            // and whether that answer can be trusted. The old single line
            // `(try? ... ) ?? []` answered the first and silently assumed the
            // second — so an unreadable exclusion list looked exactly like an
            // empty one, and folders the user had protected came back ticked
            // for deletion. See ExclusionsSnapshot.
            let exclusions = await AppEnvironment.shared.exclusions()
            exclusionsUnavailable = !exclusions.isTrustworthy
            let engine = ScanEngine(configuration: ScanConfiguration(home: CaptureHarness.scanHome, excludedPaths: exclusions.paths))
            for await event in engine.run(rules: UserCleanupRules.all, pauseController: pauseController) {
                switch event {
                case .started: break
                case let .progress(scanned, _):
                    scannedCount = scanned
                case let .finding(finding):
                    // ponytail: cap displayed findings at 5000 to bound memory; paginate later.
                    if findings.count < 5000 {
                        findings.append(finding)
                        // Preselection is a deletion suggestion. Making one
                        // while unable to confirm the user's protected folders
                        // were honoured is the single most damaging thing this
                        // screen can do, so it does not.
                        if finding.preselected && !exclusionsUnavailable {
                            selectedIDs.insert(finding.id)
                        }
                    }
                    totalFindingCount += 1
                    totalBytes += finding.logicalSize
                case .error: break
                case let .finished(scanned, bytes):
                    scannedCount = scanned
                    totalBytes = bytes
                    phase = .review
            CaptureHarness.note(state: "review")
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Cleanup scan: \(findings.count) items found",
                        itemCount: findings.count, bytes: bytes))
                case .cancelled:
                    // Normally unreachable: the loop exits on cancellation
                    // before this arrives. See CancellableScan.
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
        cancelScanning()
    }

    func resetPhaseAfterCancellation() {
        if phase == .scanning { phase = .idle }
    }

    func runCleanup() {
        guard phase == .review else { return }
        phase = .running
        let selected = findings.filter { selectedIDs.contains($0.id) }
        Task {
            let home = CaptureHarness.scanHome
            let validator = PathValidator(allowedRoots: UserCleanupRules.allowedRoots(home: home))
            let center = SafetyCenter(validator: validator, sink: AppEnvironment.shared.store)
            let batch = await center.approveAll(selected.map {
                ApprovalRequest(url: $0.url, logicalSize: $0.logicalSize,
                                ruleID: $0.ruleID, risk: $0.risk)
            })
            let outcome = ExecutionOutcome(
                result: await center.execute(batch.approved),
                rejections: batch.rejections)
            phase = .done(outcome)
            // Both counts reach the log, not just the successes: SafetyCore
            // skipping a path that changed between approval and execution is
            // the product working, and a record that omits it reads as if
            // everything went through.
            AppEnvironment.shared.record(ActivityRecord(
                kind: .cleanup,
                summary: outcome.annotate("Moved \(outcome.executedCount) items to Trash"),
                itemCount: outcome.executedCount, bytes: outcome.movedToTrashBytes))
        }
    }
}

struct JunkCleanupView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model = CleanupViewModel()

    /// Evidence lines wrap instead of truncating once text is large enough
    /// that a single line would cut them short. Typed explicitly: an inline
    /// `? nil : 1` inside a view builder leaves the compiler unable to infer
    /// the surrounding ForEach.
    private var evidenceLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }
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
            case let .done(outcome):
                doneView(outcome)
            case let .failed(message):
                Text(L("cleanup.failed", message)).foregroundStyle(MCTheme.danger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(MCSpacing.page)
            }
        }
        .onAppear { if CaptureHarness.autostartScan, model.phase == .idle { model.startScan() } }
        .scanCommands(
            start: { model.startScan() },
            pauseOrResume: { model.isScanPaused ? model.resumeScan() : model.pauseScan() },
            cancel: { model.cancelScan() })
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
                        .foregroundStyle(MCColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .mcAppear()

                MCScanButton(L("cleanup.start_scan")) { model.startScan() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("storage.scan.start")
                    .mcAppear(delay: 0.06)

                VStack(alignment: .leading, spacing: MCSpacing.sm) {
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
            MCScanControls(
                identifierPrefix: "storage",
                isPaused: model.isScanPaused,
                pauseHintKey: "cleanup.pause_hint",
                resumeHintKey: "cleanup.resume_hint",
                onPause: { model.pauseScan() },
                onResume: { model.resumeScan() },
                onCancel: { model.cancelScan() })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review

    private var reviewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.exclusionsUnavailable {
                HStack(alignment: .top, spacing: MCSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(MCTheme.warning).accessibilityHidden(true)
                    Text(L("cleanup.exclusions_unavailable"))
                        .font(MCFont.caption).lineLimit(3)
                }
                .padding(.horizontal, MCSpacing.page).padding(.vertical, MCSpacing.xs)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("cleanup.exclusions_unavailable")
                Divider()
            }
            // A sentence and the one button. The total is not a hero number:
            // it is what *would* move to the Trash, which is a proposal, and a
            // proposal in 40pt reads as a promise.
            HStack(alignment: .firstTextBaseline, spacing: MCSpacing.md) {
                Text(L("cleanup.review.sentence", mcFormatBytes(model.selectedBytes),
                       model.selectedIDs.count, model.findings.count))
                    .font(MCFont.body)
                if model.isDisplayTruncated {
                    Text(L("cleanup.review.truncated", model.findings.count, model.totalFindingCount, mcFormatBytes(model.totalBytes)))
                        .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                }
                Spacer()
                Button(L("cleanup.move_to_trash")) { showMoveConfirmation = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.phase == .running || model.selectedIDs.isEmpty)
            }
            .padding(.horizontal, MCSpacing.page).padding(.vertical, MCSpacing.sm)
            Divider()
            List {
                ForEach(model.groups) { group in
                    Section {
                        ForEach(group.findings) { finding in findingRow(finding) }
                    } header: {
                        groupHeader(group)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 28)
        }
    }

    /// The whole category in one line: tick it, read what it is, see what it
    /// weighs. The explanation is the header's tooltip and its VoiceOver
    /// hint, not a second line on every screen.
    private func groupHeader(_ group: CleanupViewModel.RuleGroup) -> some View {
        HStack(spacing: MCSpacing.xs) {
            Toggle("", isOn: Binding(
                get: { model.selectionState(for: group) },
                set: { model.setSelection($0, for: group) }
            ))
            .labelsHidden()
            .accessibilityLabel(L("cleanup.select_group", group.name))
            Text(group.name).font(MCFont.sectionTitle)
            Text(L(group.findings.count == 1 ? "cleanup.group.item_count_one" : "cleanup.group.item_count_other",
                   group.findings.count))
                .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            Spacer()
            Text(mcFormatBytes(group.bytes)).font(MCFont.tabular.weight(.semibold))
        }
        .padding(.top, MCSpacing.sm)
        .help(group.explanation)
        .accessibilityHint(group.explanation)
    }

    private func findingRow(_ finding: ScanFinding) -> some View {
        let evidence = FindingMetadata.summary(risk: finding.risk, modificationDate: finding.modificationDate)
        return HStack(spacing: MCSpacing.xs) {
            Toggle("", isOn: Binding(
                get: { model.selectedIDs.contains(finding.id) },
                set: { on in
                    if on { model.selectedIDs.insert(finding.id) } else { model.selectedIDs.remove(finding.id) }
                }
            ))
            .labelsHidden()
            .accessibilityLabel(evidence.map {
                L("finding.a11y.evidence", L("cleanup.select_item", finding.url.lastPathComponent), $0)
            } ?? L("cleanup.select_item", finding.url.lastPathComponent))
            Text(finding.url.lastPathComponent).lineLimit(1)
            Text(finding.url.deletingLastPathComponent().path)
                .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: MCSpacing.xs)
            if let evidence {
                Text(evidence).font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
                    .lineLimit(evidenceLineLimit)
            }
            Text(mcFormatBytes(finding.logicalSize)).font(MCFont.tabular)
                .foregroundStyle(MCColor.textSecondary).frame(width: 80, alignment: .trailing)
        }
        .contextMenu {
            Button(L("common.reveal_in_finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([finding.url])
            }
        }
    }

    private func doneView(_ outcome: ExecutionOutcome) -> some View {
        MCSuccessState(
            title: outcome.title,
            message: outcome.message,
            actionTitle: L("smartcare.scan_again")) { model.startScan() }
    }
}


/// Cleanup: the things CoreTend can move to the Trash on your behalf.
///
/// Browser caches were filed under Integrity. They are caches — rebuilt
/// automatically, plain files, moved to the Trash like any other — so they
/// belong with the other cleanup, not with code signing.
struct CleanupView: View {
    @State private var tab = 0

    var body: some View {
        ModuleSubNav(sections: [
            .init(0, L("cleanup.tab.junk")),
            .init(1, L("cleanup.tab.browsers")),
        ], selection: $tab) { tab in
            if tab == 0 { JunkCleanupView() } else { PrivacyCleanerView() }
        }
        .navigationTitle(L("module.cleanup"))
    }
}
