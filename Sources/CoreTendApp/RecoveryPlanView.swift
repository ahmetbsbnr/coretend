// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import SafetyCore
import DesignSystem

@MainActor
@Observable
final class RecoveryPlanViewModel {
    enum Phase: Equatable { case idle, preparing, ready, executing, finished }

    var phase: Phase = .idle
    /// Bytes, never a formatted string — the text field/preset buttons write
    /// here, everything else reads from here.
    var goalBytes: Int64 = 20_000_000_000
    private(set) var candidateData: [RecoveryPlanCandidateData] = []
    private(set) var plan: RecoveryPlan?
    var selectedIDs: Set<String> = []
    private(set) var executionResult: RecoveryPlanExecutionResult?

    /// True when this plan was populated from a fresh Smart Scan handoff
    /// rather than its own scan — surfaced in the UI so the user knows the
    /// numbers came straight from the scan they just ran.
    private(set) var fromSmartScan = false

    func preparePlan() async {
        phase = .preparing
        if let handed = await SmartScanHandoff.shared.freshCandidates() {
            candidateData = handed
            fromSmartScan = true
        } else {
            candidateData = await RecoveryPlanService.prepareCandidates()
            fromSmartScan = false
        }
        rebuildPlan()
        phase = .ready
    }

    /// Re-derives the plan (and resets selection to its fresh preselection)
    /// from already-scanned data — called when the goal changes, so
    /// adjusting the goal never re-scans the filesystem.
    func applyGoal() {
        guard phase == .ready else { return }
        rebuildPlan()
    }

    private func rebuildPlan() {
        let newPlan = RecoveryPlanBuilder.build(
            candidates: candidateData.map(\.candidate), goal: RecoveryGoal(bytes: max(0, goalBytes)))
        plan = newPlan
        selectedIDs = newPlan.preselectedIDs
    }

    var selectedBytes: Int64 {
        guard let plan else { return 0 }
        return plan.allCandidates.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.reclaimableBytes }
    }

    var goalReached: Bool { goalBytes > 0 && selectedBytes >= goalBytes }

    func isSelected(_ candidate: RecoveryPlanCandidate) -> Bool { selectedIDs.contains(candidate.id) }

    func setSelected(_ on: Bool, for candidate: RecoveryPlanCandidate) {
        guard candidate.category != .notIncluded else { return }
        if on { selectedIDs.insert(candidate.id) } else { selectedIDs.remove(candidate.id) }
    }

    func execute() async {
        guard phase == .ready, !selectedIDs.isEmpty else { return }
        phase = .executing
        let selected = candidateData.filter { selectedIDs.contains($0.candidate.id) }
        executionResult = await RecoveryPlanService.execute(selected: selected)
        phase = .finished
    }

    func startOver() async {
        phase = .idle
        plan = nil
        selectedIDs = []
        executionResult = nil
        await preparePlan()
    }
}

struct RecoveryPlanView: View {
    @State private var model = RecoveryPlanViewModel()
    @State private var showConfirm = false

    var body: some View {
        Group {
            switch model.phase {
            case .idle:
                startState
            case .preparing:
                transientState(L("recovery.preparing"))
            case .ready:
                readyView
            case .executing:
                transientState(L("recovery.executing"))
            case .finished:
                finishedView
            }
        }
        .navigationTitle(L("recovery.title"))
        .accessibilityIdentifier("recovery.root")
        .task {
            // Arriving from "Review Recovery Plan" in a completed Smart Scan:
            // the candidates are already prepared and handed off, so land
            // straight in the review state instead of the manual start card.
            // `preparePlan()` reuses the handoff — it does not re-scan.
            if model.phase == .idle, SmartScanHandoff.shared.isFresh {
                await model.preparePlan()
            }
        }
    }

    // MARK: - States

    /// Shared look for every transient / status screen (preparing, executing,
    /// and any future one). The copy is width-capped and wraps, with generous
    /// horizontal padding, so a long FR string never approaches the window
    /// edge or clips, and it stays vertically + horizontally centred.
    private func transientState(_ message: String) -> some View {
        // Scroll-hosted like the other centred states so a focus/reveal pass
        // can never reach the sidebar's scroll view (see `startState`).
        ScrollView {
            VStack(spacing: MCSpacing.md) {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: MCSize.readableTextWidth)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, MCSpacing.xl)
            .padding(.vertical, MCSpacing.page)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    /// Deliberately not auto-triggered on appear: preparing a plan runs all
    /// four wired engines (Duplicates in particular can take a while over a
    /// large home folder), so scanning only starts once the user has set a
    /// goal and asked for one — never a surprise background scan from just
    /// opening the tab.
    private var startState: some View {
        // MUST be scroll-hosted. This state is a `NavigationSplitView` detail
        // whose "Préparer le plan" button is `.borderedProminent` — the
        // window's default control. In a non-scrolling detail, AppKit's
        // reveal-the-default-control pass walks up for an enclosing
        // NSScrollView, finds the *sidebar's* list, and scrolls the whole
        // navigation off-screen (reproduced: the reported "Recovery Plan
        // sidebar displaced" bug). A local scroll host keeps that reveal
        // harmless; the content still fits without visible scrolling.
        ScrollView {
            VStack(spacing: MCSpacing.md) {
                Image(systemName: "target")
                    .font(.system(size: MCIconSize.emptyState)).foregroundStyle(MCTheme.accent)
                    .accessibilityHidden(true)
                Text(L("recovery.empty.no_scan.title")).font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("recovery.empty.no_scan.subtitle")).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: MCSize.readableTextWidth)
                goalCard.frame(maxWidth: MCSize.readableTextWidth)
                Button(L("recovery.prepare_button")) { Task { await model.preparePlan() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("recovery.prepare")
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, MCSpacing.xl)
            .padding(.vertical, MCSpacing.page)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var finishedView: some View {
        let result = model.executionResult
        return MCSuccessState(
            title: L("recovery.result.title", mcFormatBytes(result?.processedBytes ?? 0)),
            message: (result?.skippedCount ?? 0) > 0
                ? L("recovery.result.skipped", result?.skippedCount ?? 0) : nil,
            actionTitle: L("recovery.result.prepare_again")) {
                Task { await model.startOver() }
            }
            .accessibilityIdentifier("recovery.result")
    }

    // MARK: - Ready

    private var readyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                if model.fromSmartScan {
                    Label(L("recovery.from_smartscan"), systemImage: "sparkles")
                        .font(MCFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("recovery.fromSmartScan")
                }
                goalCard
                if let plan = model.plan {
                    if plan.isEmpty {
                        noCandidatesState
                    } else {
                        summaryCard(plan)
                        ForEach([RecoveryPlanCategory.recommended, .reviewRequired, .optional]) { category in
                            let section = plan.section(category)
                            if !section.candidates.isEmpty {
                                categorySection(section)
                            }
                        }
                        let notIncluded = plan.section(.notIncluded)
                        if !notIncluded.candidates.isEmpty {
                            notIncludedSection(notIncluded)
                        }
                    }
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // A comfortable margin under the last row, on top of the action bar's
        // own reserved height, so nothing renders against the window edge.
        .contentMargins(.bottom, MCSpacing.md, for: .scrollContent)
        .accessibilityIdentifier("recovery.ready")
        // The primary destructive action lives in the content area, in a
        // bottom bar — not jammed into the top-right window chrome. Its
        // height is reserved by `safeAreaInset`, which is what lets the
        // final Recovery Plan row scroll fully clear of the bottom edge.
        .safeAreaInset(edge: .bottom, spacing: 0) { confirmBar }
    }

    private var confirmBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: MCSpacing.md) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("recovery.summary.current_selection"))
                        .font(MCFont.badge).foregroundStyle(.secondary).textCase(.uppercase)
                    Text(mcFormatBytes(model.selectedBytes))
                        .font(MCFont.cardTitle).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: MCSpacing.sm)
                Button(L("recovery.confirm_button")) { showConfirm = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.selectedIDs.isEmpty)
                    .accessibilityIdentifier("recovery.confirm")
                    .confirmationDialog(L("recovery.confirm_dialog.title"), isPresented: $showConfirm) {
                        Button(L("recovery.confirm_dialog.action"), role: .destructive) {
                            Task { await model.execute() }
                        }
                    } message: {
                        Text(L("recovery.confirm_dialog.message", mcFormatBytes(model.selectedBytes)))
                    }
            }
            .padding(.horizontal, MCSpacing.page)
            .padding(.vertical, MCSpacing.sm)
        }
        .background(.bar)
    }

    private var noCandidatesState: some View {
        VStack(spacing: MCSpacing.sm) {
            Image(systemName: "checkmark.circle").font(.system(size: MCIconSize.emptyState * 0.7))
                .foregroundStyle(.secondary).accessibilityHidden(true)
            Text(L("recovery.empty.no_eligible_items")).font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MCSpacing.xl)
    }

    // MARK: - Goal

    private var goalCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                Text(L("recovery.goal_label")).font(MCFont.cardTitle)
                    .fixedSize(horizontal: false, vertical: true)
                // Presets + custom field wrap to a second line at a narrow
                // window width instead of overflowing the card.
                MCFlowLayout(spacing: MCSpacing.xs, lineSpacing: MCSpacing.xs) {
                    ForEach(RecoveryGoalPreset.allCases) { preset in
                        Button(preset.label) {
                            model.goalBytes = preset.bytes
                            model.applyGoal()
                        }
                        .buttonStyle(.bordered)
                        .tint(preset.bytes == model.goalBytes ? MCTheme.accent : .secondary)
                        .accessibilityIdentifier("recovery.goal.\(preset.id)")
                    }
                    HStack(spacing: MCSpacing.xxs) {
                        TextField(L("recovery.goal.custom_placeholder"), value: Binding(
                            get: { Double(model.goalBytes) / 1_000_000_000 },
                            set: { model.goalBytes = Int64(max(0, $0) * 1_000_000_000); model.applyGoal() }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .accessibilityLabel(L("recovery.goal.custom_a11y"))
                        Text(L("recovery.goal.unit_gb"))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private enum RecoveryGoalPreset: String, CaseIterable, Identifiable {
        case five, ten, twenty
        var id: String { rawValue }
        var bytes: Int64 {
            switch self {
            case .five: 5_000_000_000
            case .ten: 10_000_000_000
            case .twenty: 20_000_000_000
            }
        }
        var label: String {
            switch self {
            case .five: L("recovery.goal.preset_5gb")
            case .ten: L("recovery.goal.preset_10gb")
            case .twenty: L("recovery.goal.preset_20gb")
            }
        }
    }

    // MARK: - Summary

    private func summaryMetric(_ label: String, _ value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label).font(MCFont.badge)
                .foregroundStyle(.secondary).textCase(.uppercase)
                .fixedSize(horizontal: false, vertical: true)
            Text(value).font(MCFont.displayMetric).monospacedDigit()
                .minimumScaleFactor(0.7).lineLimit(1)
        }
    }

    private func summaryCard(_ plan: RecoveryPlan) -> some View {
        let recoverable = summaryMetric(
            L("recovery.summary.potentially_recoverable"),
            mcFormatBytes(plan.potentiallyRecoverableBytes), alignment: .leading)
        let selection = summaryMetric(
            L("recovery.summary.current_selection"),
            mcFormatBytes(model.selectedBytes), alignment: .leading)

        return MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                // Side-by-side when there is room; stacked when the window is
                // too narrow for two large metrics — never shrunk to tiny type.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top) {
                        recoverable
                        Spacer(minLength: MCSpacing.lg)
                        selection
                    }
                    VStack(alignment: .leading, spacing: MCSpacing.sm) {
                        recoverable
                        selection
                    }
                }
                if model.goalBytes > 0 {
                    Label(
                        model.goalReached ? L("recovery.goal_reached") : L("recovery.goal_not_reached"),
                        systemImage: model.goalReached ? "checkmark.circle.fill" : "circle.dashed")
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(model.goalReached ? MCTheme.success : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sections

    private func categorySection(_ section: RecoveryPlanSection) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            MCSectionHeader(sectionTitle(section.category), subtitle: mcFormatBytes(section.totalBytes))
            ForEach(section.candidates) { candidate in
                candidateRow(candidate)
            }
        }
    }

    /// Trailing byte value: fixed to its natural width and never compressed
    /// or truncated, so the number stays readable and column-aligned even
    /// when the title/description wraps.
    private func rowBytes(_ bytes: Int64) -> some View {
        Text(mcFormatBytes(bytes))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .fixedSize()
            .layoutPriority(1)
    }

    private func candidateRow(_ candidate: RecoveryPlanCandidate) -> some View {
        HStack(alignment: .top, spacing: MCSpacing.sm) {
            Toggle("", isOn: Binding(
                get: { model.isSelected(candidate) },
                set: { model.setSelected($0, for: candidate) }
            ))
            .labelsHidden()
            .accessibilityLabel(L("recovery.select_item", candidate.finding.title))
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.finding.title).font(MCFont.cardTitle)
                    .fixedSize(horizontal: false, vertical: true)
                AdvisorSummaryRow(finding: candidate.finding)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: MCSpacing.sm)
            rowBytes(candidate.reclaimableBytes)
        }
        .padding(.vertical, MCSpacing.xxs)
    }

    private func notIncludedSection(_ section: RecoveryPlanSection) -> some View {
        DisclosureGroup {
            ForEach(section.candidates) { candidate in
                HStack(alignment: .top, spacing: MCSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.finding.title).font(MCFont.cardTitle)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(exclusionText(candidate.exclusionReason))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: MCSpacing.sm)
                    rowBytes(candidate.reclaimableBytes)
                }
                .padding(.vertical, MCSpacing.xxs)
            }
        } label: {
            Text(L("recovery.not_included.count", section.candidates.count)).font(MCFont.cardTitle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("recovery.not_included")
    }

    private func sectionTitle(_ category: RecoveryPlanCategory) -> String {
        switch category {
        case .recommended: L("recovery.section.recommended")
        case .reviewRequired: L("recovery.section.review_required")
        case .optional: L("recovery.section.optional")
        case .notIncluded: L("recovery.section.not_included")
        }
    }

    private func exclusionText(_ reason: RecoveryPlanExclusionReason?) -> String {
        switch reason {
        case .noReclaimableBytes: L("recovery.exclusion.no_reclaimable_bytes")
        case .readOnly: L("recovery.exclusion.read_only")
        case .destructiveActionUnavailable: L("recovery.exclusion.destructive_action_unavailable")
        case .uncertainAssociation: L("recovery.exclusion.uncertain_association")
        case .highRisk: L("recovery.exclusion.high_risk")
        case .unsupportedSource: L("recovery.exclusion.unsupported_source")
        case .overlapsAnotherSource: L("recovery.exclusion.overlaps_another_source")
        case nil: ""
        }
    }
}
