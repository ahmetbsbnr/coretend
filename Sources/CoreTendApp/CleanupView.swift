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

    /// Tick every finding on screen, or none of them.
    ///
    /// Not a suggestion — the app never proposes deleting everything it
    /// found, and `preselected` stays the only thing it proposes. This is the
    /// person saying so, from the keyboard, on a list they are looking at;
    /// what it ticks still has to pass the confirmation and still goes to the
    /// Trash. It is deliberately absent while the exclusions could not be
    /// read, for the same reason preselection is.
    func selectAll() {
        guard !exclusionsUnavailable else { return }
        selectedIDs = Set(findings.map(\.id))
    }

    func selectNone() { selectedIDs = [] }

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
    @State var model = CleanupViewModel()
    @State private var highlighted: UUID?
    @State private var previewURL: URL?

    /// Evidence lines wrap instead of truncating once text is large enough
    /// that a single line would cut them short. Typed explicitly: an inline
    /// `? nil : 1` inside a view builder leaves the compiler unable to infer
    /// the surrounding ForEach.
    private var evidenceLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }
    @State private var showMoveConfirmation = false
    /// Which categories are showing their items. Empty on arrival: the review
    /// opens as a list of decisions, not a list of files.
    @State private var expandedGroups: Set<String> = []
    /// Folded categories left two thirds of a standard window empty. The
    /// largest one opens on arrival: it is both the most likely thing to be
    /// inspected and what turns the remaining space into evidence rather than
    /// into a gap.
    @State private var didExpandLargest = false
    /// How many items a folded category previews. Four fills the space a
    /// six-category review leaves without turning the screen back into a flat
    /// file list.
    private static let previewRows = 4
    /// Full Disk Access, checked when the screen appears. A scan without it
    /// finds a fraction of what is there and says nothing about why, which
    /// reads as a clean Mac.
    @State private var hasFullDiskAccess = ScanTargetAccess.canReadScanTarget
    @State private var scanAnyway = false

    var body: some View {
        Group {
            switch model.phase {
            case .idle where !hasFullDiskAccess && !scanAnyway:
                MCPermissionState(
                    title: L("permission.fulldisk.title"),
                    explanation: L("permission.fulldisk.explanation"),
                    limitation: L("permission.fulldisk.limitation"),
                    onContinue: { scanAnyway = true })
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
        .onAppear {
            hasFullDiskAccess = ScanTargetAccess.canReadScanTarget
            if CaptureHarness.autostartScan, model.phase == .idle {
                scanAnyway = true
                model.startScan()
            }
        }
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
                // The decision, stated as a figure and a sentence rather than
                // one long line of body text. What is about to happen is the
                // thing this screen exists to make unambiguous.
                VStack(alignment: .leading, spacing: 0) {
                    Text(mcFormatBytes(model.selectedBytes))
                        .font(MCFont.displaySecondary)
                        .foregroundStyle(MCColor.textPrimary)
                    Text(L("cleanup.review.sentence_short",
                           model.selectedIDs.count, model.findings.count))
                        .font(MCFont.caption)
                        .foregroundStyle(MCColor.textSecondary)
                }
                if model.isDisplayTruncated {
                    Text(L("cleanup.review.truncated", model.findings.count, model.totalFindingCount, mcFormatBytes(model.totalBytes)))
                        .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                }
                Spacer()
                // Visible because a keyboard shortcut nobody can see is a
                // feature only its author has.
                Button(L("cleanup.select_all")) { model.selectAll() }
                    .buttonStyle(.link)
                    .keyboardShortcut("a", modifiers: .command)
                    .disabled(model.exclusionsUnavailable
                              || model.selectedIDs.count == model.findings.count)
                    .accessibilityIdentifier("cleanup.select_all")
                Button(L("cleanup.select_none")) { model.selectNone() }
                    .buttonStyle(.link)
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(model.selectedIDs.isEmpty)
                    .accessibilityIdentifier("cleanup.select_none")
                Button(L("cleanup.move_to_trash")) { showMoveConfirmation = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.phase == .running || model.selectedIDs.isEmpty)
            }
            .padding(.horizontal, MCSpacing.page).padding(.vertical, MCSpacing.sm)
            Divider()
            List(selection: $highlighted) {
                ForEach(model.groups) { group in
                    Section {
                        // A preview, not all-or-nothing.
                        //
                        // Folding every category shut fixed the original
                        // problem — 478 flat rows burying every category but
                        // the first — and created the opposite one: measured
                        // on the capture, 69% of the detail column was a flat
                        // field. Each category now shows its first few items
                        // and says how many more there are, so the screen
                        // carries both the decision and its evidence.
                        let expanded = expandedGroups.contains(group.id)
                        let shown = expanded ? group.findings
                                             : Array(group.findings.prefix(Self.previewRows))
                        ForEach(shown) { finding in findingRow(finding).tag(finding.id) }
                        if !expanded, group.findings.count > Self.previewRows {
                            Button {
                                withAnimation(MCMotion.response) {
                                    expandedGroups.insert(group.id)
                                }
                            } label: {
                                Text(L("cleanup.group.show_all",
                                       group.findings.count - Self.previewRows))
                                    .font(MCFont.caption)
                                    .foregroundStyle(MCColor.textSecondary)
                                    .padding(.leading, MCSpacing.lg)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        groupHeader(group)
                    }
                }
            }
            .listStyle(.plain)
            // The list drew its own light panel, inset and rounded, inside a
            // window with a different ground: the largest card in the app,
            // enclosing a list that the hairlines and headings already
            // grouped. It sits on the window's ground now, like every other
            // list in the rebuild.
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 24)
            .onKeyPress(.space) {
                guard let highlighted else { return .ignored }
                if !model.selectedIDs.insert(highlighted).inserted { model.selectedIDs.remove(highlighted) }
                return .handled
            }
            .contextMenu(forSelectionType: UUID.self) { ids in
                if let finding = model.findings.first(where: { ids.contains($0.id) }) {
                    Button(L("clutter.quick_look")) { previewURL = finding.url }
                    Button(L("common.reveal_in_finder")) { NSWorkspace.shared.activateFileViewerSelecting([finding.url]) }
                }
            } primaryAction: { ids in
                previewURL = model.findings.first(where: { ids.contains($0.id) })?.url
            }
            .quickLookPreview($previewURL)

        }
    }

    /// The whole category in one line: tick it, read what it is, see what it
    /// weighs. The explanation is the header's tooltip and its VoiceOver
    /// hint, not a second line on every screen.
    /// The category is the unit of decision: what it is, why it was found, how
    /// much it weighs, and one control that takes or leaves all of it.
    ///
    /// The reason used to live only in a tooltip. "Why is this safe to remove"
    /// is the question this screen exists to answer, and an answer that
    /// requires hovering is an answer most people never get.
    private func groupHeader(_ group: CleanupViewModel.RuleGroup) -> some View {
        let isOpen = expandedGroups.contains(group.id)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: MCSpacing.xs) {
                Toggle("", isOn: Binding(
                    get: { model.selectionState(for: group) },
                    set: { model.setSelection($0, for: group) }
                ))
                .labelsHidden()
                .accessibilityLabel(L("cleanup.select_group", group.name))
                Button {
                    withAnimation(MCMotion.response) {
                        if isOpen { expandedGroups.remove(group.id) }
                        else { expandedGroups.insert(group.id) }
                    }
                } label: {
                    HStack(spacing: MCSpacing.xxs) {
                        Image(systemName: "chevron.right")
                            .font(MCFont.micro.weight(.semibold))
                            .foregroundStyle(MCColor.textTertiary)
                            .rotationEffect(.degrees(isOpen ? 90 : 0))
                        Text(CleanupRuleVocabulary.name(group.ruleID, fallback: group.name))
                            .font(MCFont.sectionTitle)
                            .foregroundStyle(MCColor.textPrimary)
                        Text(L(group.findings.count == 1 ? "cleanup.group.item_count_one" : "cleanup.group.item_count_other",
                               group.findings.count))
                            .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(group.name)
                // Two separate calls rather than one taking a ternary: the
                // localisation audit finds keys by scanning source for a
                // lookup applied to a string literal, so a key only ever
                // reached through an expression reads as unused and silently
                // joins the orphan count.
                .accessibilityHint(isOpen ? L("cleanup.group.collapse") : L("cleanup.group.expand"))
                Spacer()
                Text(mcFormatBytes(group.bytes)).font(MCFont.tabular.weight(.semibold))
            }
            // The reason, on screen, once per category rather than as a risk
            // word repeated on all 466 rows underneath it.
            Text(CleanupRuleVocabulary.explanation(group.ruleID, fallback: group.explanation))
                .font(MCFont.caption)
                .foregroundStyle(MCColor.textSecondary)
                .lineLimit(2)
                .padding(.leading, MCSpacing.lg + MCSpacing.xxs)
        }
        .padding(.top, MCSpacing.sm)
        .padding(.bottom, MCSpacing.xxs)
        .accessibilityElement(children: .contain)
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
            Text(finding.url.lastPathComponent)
                .font(MCFont.rowTitle)
                .lineLimit(1)
            // The folder, not the full path, and given the least weight on the
            // row. A capture of the real fixture showed every row reading as
            // 70% truncated `/private/var/folders/tc/9z4_b12n…` — a string
            // nobody can act on, set larger than the file name they can.
            Text(PathDisplay.shortFolder(of: finding.url))
                .font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
                .lineLimit(1).truncationMode(.middle)
                .layoutPriority(-1)
            Spacer(minLength: MCSpacing.xs)
            // Only the part that actually varies between rows. The risk word
            // is a property of the rule that found them, so it is stated once
            // in the header instead of 466 times here.
            if let age = FindingMetadata.ageDescription(for: finding.modificationDate) {
                // The relaxed limit, not a hard 1. At accessibility text sizes
                // a single line cuts the age off mid-phrase, removing the one
                // piece of evidence this column carries from the readers who
                // most need it — the contract AccessibilityContractTests
                // guards, which this row briefly broke.
                Text(age).font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
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
    @State var model = CleanupViewModel()

    var body: some View {
        ModuleSubNav(sections: [
            .init(0, L("cleanup.tab.junk")),
            .init(1, L("cleanup.tab.browsers")),
        ], selection: $tab) { tab in
            if tab == 0 { JunkCleanupView(model: model) } else { PrivacyCleanerView() }
        }
        .navigationTitle(L("module.cleanup"))
    }
}

/// The rule vocabulary, localised in the UI layer.
///
/// `ScanRule` lives in ScanCore, which is a pure engine with no localisation
/// and no business having any: its `name` and `explanation` are stable English
/// literals. Looking them up here by rule id keeps the engine free of
/// `Localizable.strings` while letting a French user read "Anciennes archives"
/// instead of "Old archives" — which is what a capture on a French Mac showed
/// after the app started launching in French at all.
enum CleanupRuleVocabulary {
    private static func lookup(_ ruleID: String, _ suffix: String, fallback: String) -> String {
        let key = "rule.\(ruleID.replacingOccurrences(of: ".", with: "_")).\(suffix)"
        let value = L(key)
        // `L` returns the key itself when it is absent. A rule with no
        // translation falls back to the engine's own wording rather than
        // printing "rule.user_caches.name" on screen.
        return value == key ? fallback : value
    }

    static func name(_ ruleID: String, fallback: String) -> String {
        lookup(ruleID, "name", fallback: fallback)
    }

    static func explanation(_ ruleID: String, fallback: String) -> String {
        lookup(ruleID, "explanation", fallback: fallback)
    }
}
