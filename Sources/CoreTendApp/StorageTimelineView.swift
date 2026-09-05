// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import Persistence
import DesignSystem

/// "What changed since my last scan?" — one scope (scan methodology) at a
/// time, per the comparison rules documented on `Store`'s Timeline section:
/// two snapshots are only ever compared when they share a scope.
@MainActor
@Observable
final class StorageTimelineViewModel {
    enum Phase: Equatable { case loading, noHistoryAtAll, ready }

    var phase: Phase = .loading
    /// Every wired scope that has at least one recorded snapshot.
    var availableScopes: [TimelineScope] = []
    var selectedScope: TimelineScope = .cleanup
    var selectedWindow: TimelineWindow = .sincePreviousScan
    var latestSnapshot: TimelineSnapshotRecord?
    var comparison: TimelineComparison?
    var recentHistory: [TimelineSnapshotRecord] = []
    var isClearing = false

    private let service: TimelineService

    init(service: TimelineService = TimelineService()) {
        self.service = service
    }

    var hasHistoryForSelectedScope: Bool { latestSnapshot != nil }

    func load() async {
        let scopes = await service.scopesWithHistory()
        availableScopes = scopes
        guard !scopes.isEmpty else {
            phase = .noHistoryAtAll
            return
        }
        selectedScope = await service.mostRecentScope() ?? scopes[0]
        await refresh()
        phase = .ready
    }

    /// Re-reads everything for the current `selectedScope`/`selectedWindow` —
    /// called after either changes, and once from `load()`.
    func refresh() async {
        latestSnapshot = await service.latestSnapshot(scope: selectedScope)
        comparison = await service.comparison(scope: selectedScope, window: selectedWindow)
        recentHistory = await service.recentHistory(scope: selectedScope, limit: 10)
    }

    func clearHistory() async {
        isClearing = true
        await service.clearHistory()
        isClearing = false
        await load()
    }
}

struct StorageTimelineView: View {
    @State private var model = StorageTimelineViewModel()
    @State private var showClearConfirm = false

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .noHistoryAtAll:
                noHistoryAtAllState
            case .ready:
                readyView
            }
        }
        .navigationTitle(L("timeline.title"))
        .accessibilityIdentifier("timeline.root")
        .toolbar {
            if model.phase == .ready {
                Button(L("timeline.clear_history"), role: .destructive) { showClearConfirm = true }
                    .accessibilityIdentifier("timeline.clear")
                    .disabled(model.isClearing)
                    .confirmationDialog(L("timeline.clear_confirm_title"), isPresented: $showClearConfirm) {
                        Button(L("timeline.clear_confirm_action"), role: .destructive) {
                            Task { await model.clearHistory() }
                        }
                    } message: {
                        Text(L("timeline.clear_confirm_message"))
                    }
            }
        }
        .task { await model.load() }
        .task(id: model.selectedScope) {
            guard model.phase == .ready else { return }
            await model.refresh()
        }
        .task(id: model.selectedWindow) {
            guard model.phase == .ready else { return }
            await model.refresh()
        }
    }

    // MARK: - Empty states

    private var noHistoryAtAllState: some View {
        VStack(spacing: MCSpacing.md) {
            Image(systemName: MCModuleIdentity.timeline.icon)
                .font(.system(size: MCIconSize.emptyState)).foregroundStyle(MCTheme.accent)
                .accessibilityHidden(true)
            Text(L("timeline.empty.title"))
                .font(.title3.weight(.semibold))
            Text(L("timeline.empty.subtitle"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack(spacing: MCSpacing.sm) {
                ForEach(TimelineScope.allCases) { scope in
                    Button(scope.label) { navigate(scope.module) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("timeline.empty.run.\(scope.rawValue)")
                }
            }
            .padding(.top, MCSpacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MCSpacing.page)
    }

    private var perScopeEmptyState: some View {
        VStack(spacing: MCSpacing.sm) {
            Image(systemName: model.selectedScope.systemImage)
                .font(.system(size: MCIconSize.emptyState * 0.7)).foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(L("timeline.scope_empty.title", model.selectedScope.label))
                .font(.headline)
            Button(L("timeline.scope_empty.action")) { navigate(model.selectedScope.module) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("timeline.scope_empty.run")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MCSpacing.xl)
    }

    // MARK: - Ready state

    private var readyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                scopePicker
                if model.hasHistoryForSelectedScope {
                    summaryCard
                    if let comparison = model.comparison {
                        if !comparison.increases.isEmpty {
                            categorySection(title: L("timeline.increases"), deltas: comparison.increases,
                                            tint: MCTheme.warning, sign: "+")
                        }
                        if !comparison.decreases.isEmpty {
                            categorySection(title: L("timeline.decreases"), deltas: comparison.decreases,
                                            tint: MCTheme.success, sign: "")
                        }
                        if comparison.increases.isEmpty && comparison.decreases.isEmpty {
                            Text(L("timeline.no_category_changes"))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        notEnoughHistoryNote
                    }
                    recentHistorySection
                } else {
                    perScopeEmptyState
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("timeline.ready")
    }

    private var scopePicker: some View {
        Picker(L("timeline.scope_picker"), selection: Binding(
            get: { model.selectedScope },
            set: { newValue in model.selectedScope = newValue }
        )) {
            ForEach(TimelineScope.allCases) { scope in
                Label(scope.label, systemImage: scope.systemImage).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("timeline.scope_picker")
    }

    private var summaryCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                if let latest = model.latestSnapshot {
                    Text(L("timeline.last_scan", latest.date.formatted(date: .abbreviated, time: .shortened)))
                        .font(MCFont.secondaryBody)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: MCSpacing.sm) {
                    windowPicker
                    Spacer(minLength: 0)
                }
                if let comparison = model.comparison {
                    HStack(spacing: MCSpacing.xs) {
                        Image(systemName: comparisonIcon(comparison.totalDeltaBytes))
                            .foregroundStyle(comparisonTint(comparison.totalDeltaBytes))
                            .accessibilityHidden(true)
                        Text(formattedDelta(comparison.totalDeltaBytes))
                            .font(MCFont.displayMetric)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L("timeline.total_change_a11y", formattedDelta(comparison.totalDeltaBytes)))
                } else {
                    Text(L("timeline.not_enough_history"))
                        .font(MCFont.secondaryBody)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var windowPicker: some View {
        Picker(L("timeline.window_picker"), selection: Binding(
            get: { model.selectedWindow },
            set: { newValue in model.selectedWindow = newValue }
        )) {
            ForEach(TimelineWindow.allCases) { window in
                Text(window.label).tag(window)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("timeline.window_picker")
    }

    private var notEnoughHistoryNote: some View {
        Label(L("timeline.not_enough_history_detail"), systemImage: "clock.badge.questionmark")
            .foregroundStyle(.secondary)
            .font(MCFont.secondaryBody)
    }

    private func categorySection(title: String, deltas: [TimelineCategoryDelta], tint: Color, sign: String) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            MCSectionHeader(title)
            ForEach(deltas.prefix(5)) { delta in
                HStack {
                    Text(TimelineCategoryLabel.display(engine: delta.engine, category: delta.category))
                    Spacer(minLength: MCSpacing.sm)
                    Text("\(sign)\(mcFormatBytes(abs(delta.deltaBytes)))")
                        .monospacedDigit()
                        .foregroundStyle(tint)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var recentHistorySection: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            MCSectionHeader(L("timeline.recent_history"))
            if model.recentHistory.count <= 1 {
                Text(L("timeline.recent_history.building"))
                    .font(MCFont.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.recentHistory) { snapshot in
                HStack {
                    Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                    Spacer(minLength: MCSpacing.sm)
                    Text(mcFormatBytes(snapshot.totalBytes))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Helpers

    private func formattedDelta(_ bytes: Int64) -> String {
        if bytes == 0 { return L("timeline.no_change") }
        let magnitude = mcFormatBytes(abs(bytes))
        return bytes > 0 ? "+\(magnitude)" : "-\(magnitude)"
    }

    private func comparisonIcon(_ delta: Int64) -> String {
        if delta > 0 { return "arrow.up.circle.fill" }
        if delta < 0 { return "arrow.down.circle.fill" }
        return "equal.circle.fill"
    }

    private func comparisonTint(_ delta: Int64) -> Color {
        if delta > 0 { return MCTheme.warning }
        if delta < 0 { return MCTheme.success }
        return .secondary
    }

    private func navigate(_ module: ModuleID) {
        NotificationCenter.default.post(name: .mcNavigate, object: module)
    }
}
