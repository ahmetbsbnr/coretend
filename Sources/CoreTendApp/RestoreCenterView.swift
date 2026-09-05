// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem
import Persistence
import SafetyCore

// MARK: - View model

@MainActor
@Observable
final class RestoreCenterViewModel {
    enum Phase: Equatable { case loading, empty, loaded }

    private(set) var phase: Phase = .loading
    private(set) var groups: [RestoreOperationGroup] = []
    private(set) var lastSummary: RestoreExecutionSummary?
    private(set) var isWorking = false
    var selected: Set<String> = []

    private let service: RestoreService
    private var generation = UUID()

    init(store: Store? = AppEnvironment.shared.store) {
        service = RestoreService(store: store)
    }

    private var restorableIDs: Set<String> {
        Set(groups.flatMap(\.items).filter { $0.availability.isRestorable }.map(\.id))
    }

    var selectedRestorable: [String] {
        groups.flatMap(\.items)
            .filter { selected.contains($0.id) && $0.availability.isRestorable }
            .map(\.id)
    }

    var selectedBytes: Int64 {
        let ids = Set(selectedRestorable)
        return groups.flatMap(\.items).filter { ids.contains($0.id) }.reduce(0) { $0 + $1.item.sizeBytes }
    }

    func load() async {
        let token = UUID()
        generation = token
        if groups.isEmpty { phase = .loading }
        let loaded = await service.load()
        guard generation == token else { return }
        groups = loaded
        selected = selected.intersection(restorableIDs)
        phase = loaded.isEmpty ? .empty : .loaded
    }

    func refresh() async {
        lastSummary = nil
        await load()
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    func selectAll(in group: RestoreOperationGroup) {
        for item in group.items where item.availability.isRestorable { selected.insert(item.id) }
    }

    func restoreSelected() async {
        guard !isWorking else { return }
        let ids = selectedRestorable
        guard !ids.isEmpty else { return }
        isWorking = true
        let summary = await service.restore(itemIDs: ids)
        lastSummary = summary
        selected = []
        await load()
        isWorking = false
        if summary.restoredCount > 0 {
            // Free space and last-activity changed — refresh the widget.
            AppEnvironment.shared.publishWidgetSnapshot()
        }
    }

    func forgetHistory() async {
        guard !isWorking else { return }
        isWorking = true
        await service.forgetHistory()
        lastSummary = nil
        await load()
        isWorking = false
    }
}

// MARK: - View

struct RestoreCenterView: View {
    @State private var model = RestoreCenterViewModel()
    @State private var confirmRestore = false
    @State private var confirmForget = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                header
                localNotice
                if let summary = model.lastSummary {
                    summaryCard(summary)
                }
                switch model.phase {
                case .loading:
                    HStack { ProgressView().controlSize(.small); Text(L("restore.loading")) }
                case .empty:
                    MCEmptyState(icon: "arrow.uturn.backward.circle",
                                 title: L("restore.empty.title"),
                                 message: L("restore.empty.message"))
                        .accessibilityIdentifier("restore.empty")
                case .loaded:
                    ForEach(model.groups) { group in
                        operationCard(group)
                    }
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: 940, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(L("module.restore_center"))
        .accessibilityIdentifier("restore.root")
        .task { await model.load() }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label(L("restore.refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(model.isWorking)
                .accessibilityIdentifier("restore.refresh")

                Button(role: .destructive) {
                    confirmForget = true
                } label: {
                    Label(L("restore.forget"), systemImage: "trash.slash")
                }
                .disabled(model.isWorking || model.phase == .empty)
                .accessibilityIdentifier("restore.forget")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !model.selectedRestorable.isEmpty {
                actionBar
            }
        }
        .confirmationDialog(L("restore.confirm.title"), isPresented: $confirmRestore, titleVisibility: .visible) {
            Button(L("restore.confirm.action")) { Task { await model.restoreSelected() } }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("restore.confirm.message", model.selectedRestorable.count, mcFormatBytes(model.selectedBytes)))
        }
        .confirmationDialog(L("restore.forget.title"), isPresented: $confirmForget, titleVisibility: .visible) {
            Button(L("restore.forget.action"), role: .destructive) { Task { await model.forgetHistory() } }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("restore.forget.message"))
        }
    }

    // MARK: Header / notices

    private var header: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            Text(L("restore.title")).font(MCFont.pageTitle).accessibilityAddTraits(.isHeader)
            Text(L("restore.intro")).font(MCFont.secondaryBody).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var localNotice: some View {
        Label(L("restore.private_note"), systemImage: "lock.doc")
            .font(MCFont.caption).foregroundStyle(.secondary)
            .accessibilityIdentifier("restore.private_note")
    }

    private var actionBar: some View {
        HStack {
            Text(L("restore.selected", model.selectedRestorable.count, mcFormatBytes(model.selectedBytes)))
                .font(MCFont.secondaryBody)
            Spacer()
            Button(L("restore.restore_selected")) { confirmRestore = true }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)
                .accessibilityIdentifier("restore.restore_selected")
        }
        .padding(MCSpacing.sm)
        .background(.regularMaterial)
    }

    // MARK: Result summary

    private func summaryCard(_ summary: RestoreExecutionSummary) -> some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                MCSectionHeader(L("restore.result.header"))
                summaryLine("checkmark.circle.fill", MCTheme.success,
                            L("restore.result.restored", summary.restoredCount, mcFormatBytes(summary.restoredBytes)))
                if summary.conflictCount > 0 {
                    summaryLine("exclamationmark.triangle.fill", MCTheme.warning,
                                L("restore.result.conflict", summary.conflictCount))
                }
                if summary.unavailableCount > 0 {
                    summaryLine("questionmark.circle", .secondary,
                                L("restore.result.unavailable", summary.unavailableCount))
                }
                if summary.failedCount > 0 {
                    summaryLine("xmark.octagon.fill", MCTheme.warning,
                                L("restore.result.failed", summary.failedCount))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("restore.result")
    }

    private func summaryLine(_ icon: String, _ tint: Color, _ text: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: icon).foregroundStyle(tint) }
            .font(MCFont.secondaryBody)
            .accessibilityElement(children: .combine)
    }

    // MARK: Operation group

    private func operationCard(_ group: RestoreOperationGroup) -> some View {
        MCCard {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: MCSpacing.xs) {
                    if group.items.contains(where: { $0.availability.isRestorable }) {
                        Button(L("restore.select_all_in_operation")) { model.selectAll(in: group) }
                            .buttonStyle(.link)
                            .accessibilityIdentifier("restore.select_all.\(group.operationID)")
                    }
                    ForEach(group.items) { view in
                        itemRow(view)
                        Divider()
                    }
                }
                .padding(.top, MCSpacing.xs)
            } label: {
                VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                    HStack {
                        Text(RestoreRuleLabel.display(group.ruleID)).font(MCFont.cardTitle)
                        Spacer()
                        operationStatusBadge(group)
                    }
                    Text(L("restore.operation.summary",
                           group.date.formatted(date: .abbreviated, time: .shortened),
                           group.itemCount, mcFormatBytes(group.totalBytes)))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                    Text(L("restore.operation.restorable", group.restorableCount, group.itemCount))
                        .font(MCFont.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityIdentifier("restore.operation.\(group.operationID)")
    }

    @ViewBuilder
    private func operationStatusBadge(_ group: RestoreOperationGroup) -> some View {
        if group.allRestored {
            MCStatusBadge(L("restore.state.restored"), status: .success)
        } else if group.allMissing {
            MCStatusBadge(L("restore.op.trash_emptied"), status: .neutral)
        } else if group.restorableCount == 0 {
            MCStatusBadge(L("restore.op.none_restorable"), status: .attention)
        } else {
            MCStatusBadge(L("restore.op.some_restorable"), status: .active)
        }
    }

    // MARK: Item row

    private func itemRow(_ view: RestoreItemView) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: MCSpacing.sm) {
                Toggle(isOn: Binding(
                    get: { model.selected.contains(view.id) },
                    set: { _ in model.toggle(view.id) })) {
                    Text(view.name).font(MCFont.secondaryBody)
                }
                .toggleStyle(.checkbox)
                .disabled(!view.availability.isRestorable || model.isWorking)
                .accessibilityLabel(L("restore.select_item", view.name))
                Spacer(minLength: MCSpacing.sm)
                Text(mcFormatBytes(view.item.sizeBytes)).font(MCFont.caption).monospacedDigit().foregroundStyle(.secondary)
                stateBadge(view.availability)
            }
            DisclosureGroup(L("restore.item.details")) {
                VStack(alignment: .leading, spacing: 2) {
                    detailLine(L("restore.item.original"), view.item.originalPath)
                    detailLine(L("restore.item.trash"), view.item.trashPath)
                    if view.item.isDirectory {
                        Text(L("restore.item.is_directory")).font(MCFont.caption).foregroundStyle(.tertiary)
                    }
                    Text(availabilityExplanation(view.availability))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            .font(MCFont.caption)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("restore.item.\(view.id)")
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(MCFont.caption).foregroundStyle(.tertiary)
            Text(value).font(MCFont.caption).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func stateBadge(_ availability: RestoreAvailability) -> some View {
        switch availability {
        case .available:
            MCStatusBadge(L("restore.state.available"), status: .active)
        case .alreadyRestored:
            MCStatusBadge(L("restore.state.restored"), status: .success)
        case .destinationOccupied:
            MCStatusBadge(L("restore.state.conflict"), status: .attention)
        case .parentMissing, .parentNotWritable:
            MCStatusBadge(L("restore.state.location_unavailable"), status: .attention)
        case .invalidIdentity:
            MCStatusBadge(L("restore.state.changed"), status: .attention)
        case .missingFromTrash:
            MCStatusBadge(L("restore.state.not_in_trash"), status: .neutral)
        case .volumeUnavailable:
            MCStatusBadge(L("restore.state.volume_missing"), status: .neutral)
        }
    }

    private func availabilityExplanation(_ availability: RestoreAvailability) -> String {
        L("restore.explain.\(availability.rawValue)")
    }
}

/// Localized display name for the rule/source that produced a Trashed
/// operation. Falls back to the raw id so an unknown/retired rule is shown
/// honestly rather than hidden.
enum RestoreRuleLabel {
    static func display(_ ruleID: String) -> String {
        let key = "restore.source.\(ruleID)"
        let localized = L(key)
        return localized == key ? ruleID : localized
    }
}
