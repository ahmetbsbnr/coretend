// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import UniformTypeIdentifiers
import Persistence
import SafetyCore
import DesignSystem

/// The Record — the app's spine: every operation and every event, readable
/// backwards, with the evidence for each.
///
/// List + inspector, the shape macOS teaches for a long record with deep
/// evidence (Mail, Console). Rows are one line so a full window shows a
/// month, not an afternoon; the summary is a sentence, not tiles; the
/// inspector is plain sections separated by hairlines. See
/// docs/INFORMATION_ARCHITECTURE.md and docs/FRONTEND_REBUILD.md.
@MainActor
@Observable
final class RecordViewModel {
    enum Phase: Equatable { case loading, loaded, empty, failed(String) }

    enum Filter: String, CaseIterable, Identifiable {
        case all, moved, refused, failed, scans
        var id: String { rawValue }
        var label: String { L("record.filter_\(rawValue)") }

        func admits(_ item: RecordItem) -> Bool {
            switch (self, item) {
            case (.all, _): true
            case (.moved, .operation(let e)): !e.moved.isEmpty
            case (.refused, .operation(let e)): !e.refused.isEmpty
            case (.failed, .operation(let e)): !e.failed.isEmpty
            case (.failed, .event(let r)): r.kind == .error
            case (.scans, .event(let r)): r.kind == .scan
            default: false
            }
        }
    }

    var phase: Phase = .loading
    private(set) var entries: [LedgerEntry] = []
    private(set) var items: [RecordItem] = []
    var selection: RecordItem.ID?
    var filter: Filter = .all
    var query = ""

    var summary: SafetyLedger.Summary { SafetyLedger.summary(of: entries) }

    /// Filter, then search. Search matches the row's title and subtitle and,
    /// for operations, any path in its evidence — a person looking for "the
    /// time it touched Downloads" should find it from the path.
    var visibleItems: [RecordItem] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return items.filter { item in
            guard filter.admits(item) else { return false }
            guard !needle.isEmpty else { return true }
            return Self.searchText(item).contains(needle)
        }
    }

    nonisolated static func searchText(_ item: RecordItem) -> String {
        switch item {
        case let .operation(e):
            return ([RecordPhrasing.title(e), RecordPhrasing.subtitle(e)]
                    + (e.moved + e.refused + e.failed).map(\.redactedPath)).joined(separator: " ").lowercased()
        case let .event(r):
            return "\(RecordPhrasing.eventTitle(r)) \(r.summary)".lowercased()
        }
    }

    var selectedItem: RecordItem? {
        guard let selection else { return nil }
        return items.first { $0.id == selection }
    }

    func load() async {
        guard let store = AppEnvironment.shared.store else {
            phase = .failed(L("record.unavailable"))
            return
        }
        do {
            entries = SafetyLedger.entries(from: try await store.safetyLog(limit: 1000))
            let events = try await store.activity(limit: 500)
            items = SafetyLedger.items(operations: entries, events: events)
            phase = items.isEmpty ? .empty : .loaded
            if selection == nil || !items.contains(where: { $0.id == selection }) {
                selection = items.first?.id
            }
        } catch {
            phase = .failed("\(error)")
        }
    }

    /// Erases both tables. The record is one history to the person reading
    /// it; erasing "the record" and leaving half of it would be a lie by
    /// omission.
    func purge() async {
        guard let store = AppEnvironment.shared.store else { return }
        try? await store.purgeSafetyLog()
        try? await store.clearActivity()
        selection = nil
        await load()
    }

    func exportCSV() -> String {
        var lines = ["Date,Kind,Summary,Items,Bytes moved to Trash,Refused,Failed"]
        let formatter = ISO8601DateFormatter()
        for item in items {
            switch item {
            case let .operation(entry):
                let summary = RecordPhrasing.title(entry).replacingOccurrences(of: "\"", with: "'")
                lines.append("\(formatter.string(from: entry.date)),operation,\"\(summary)\",\(entry.itemCount),\(entry.movedBytes),\(entry.refused.count),\(entry.failed.count)")
            case let .event(record):
                let summary = record.summary.replacingOccurrences(of: "\"", with: "'")
                lines.append("\(formatter.string(from: record.date)),\(record.kind.rawValue),\"\(summary)\",\(record.itemCount),\(record.bytes),,")
            }
        }
        return lines.joined(separator: "\n")
    }
}

struct RecordView: View {
    @State private var model = RecordViewModel()
    @State private var confirmingPurge = false

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                MCEmptyState(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                             title: L("record.empty_title"),
                             message: L("record.empty_message"))
            case let .failed(message):
                MCEmptyState(icon: "exclamationmark.triangle",
                             title: L("record.error_title"), message: message)
            case .loaded:
                loaded
            }
        }
        .navigationTitle(L("record.title"))
        .toolbar {
            ToolbarItemGroup {
                Picker(L("record.filter"), selection: $model.filter) {
                    ForEach(RecordViewModel.Filter.allCases) { f in Text(f.label).tag(f) }
                }
                .pickerStyle(.menu)
                .accessibilityLabel(L("record.filter"))
                Menu {
                    Button(L("record.export_csv")) { exportCSV() }.disabled(model.items.isEmpty)
                    Divider()
                    Button(L("record.purge"), role: .destructive) { confirmingPurge = true }
                        .disabled(model.items.isEmpty)
                } label: {
                    Label(L("common.more"), systemImage: "ellipsis.circle")
                }
                .menuIndicator(.hidden)
            }
        }
        .searchable(text: $model.query, placement: .toolbar, prompt: L("record.search"))
        .confirmationDialog(L("record.purge_confirm_title"),
                            isPresented: $confirmingPurge, titleVisibility: .visible) {
            Button(L("record.purge_confirm_action"), role: .destructive) { Task { await model.purge() } }
            Button(L("common.cancel"), role: .cancel) { }
        } message: {
            Text(L("record.purge_confirm_message", model.items.count))
        }
        .task { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .mcExportRecord)) { _ in
            if !model.items.isEmpty { exportCSV() }
        }
    }

    private var loaded: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                summaryLine
                Divider()
                list
            }
            .frame(minWidth: 300, idealWidth: 360, maxWidth: 440)
            Divider()
            inspector.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// One sentence. Two facts CoreTend owns and nothing it cannot compute.
    private var summaryLine: some View {
        let s = model.summary
        var parts = [L("record.summary_moved_sentence", mcFormatBytes(s.movedBytes), s.movedItems)]
        if s.refusedItems > 0 { parts.append(L("record.summary_refused_sentence", s.refusedItems)) }
        if s.failedItems > 0 { parts.append(L("record.summary_failed_sentence", s.failedItems)) }
        return Text(parts.joined(separator: " · "))
            .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            .lineLimit(2)
            .padding(.horizontal, MCSpacing.md).padding(.vertical, MCSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(parts.joined(separator: ", "))
    }

    @ViewBuilder
    private var list: some View {
        let visible = model.visibleItems
        if visible.isEmpty {
            MCEmptyState(icon: "line.3.horizontal.decrease",
                         title: L("record.nothing_matches_title"),
                         message: L("record.nothing_matches_message"))
        } else {
            List(selection: $model.selection) {
                ForEach(SafetyLedger.byDay(visible)) { group in
                    Section {
                        ForEach(group.entries) { item in
                            RecordRow(item: item).tag(item.id)
                        }
                    } header: {
                        Text(AppDateFormatting.string(group.day, style: .fullDay))
                            .font(MCFont.groupHeader).foregroundStyle(MCColor.textSecondary)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 28)
        }
    }

    @ViewBuilder
    private var inspector: some View {
        switch model.selectedItem {
        case let .operation(entry): RecordInspector(entry: entry)
        case let .event(record): RecordEventInspector(record: record)
        case nil:
            MCEmptyState(icon: "sidebar.left",
                         title: L("record.no_selection_title"),
                         message: L("record.no_selection_message"))
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "CoreTend Record.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? model.exportCSV().write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Rows: one line each

private struct RecordRow: View {
    let item: RecordItem

    var body: some View {
        HStack(spacing: MCSpacing.xs) {
            glyph
            Text(title).font(MCFont.body).lineLimit(1)
            Text(subtitle).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: MCSpacing.xs)
            Text(AppDateFormatting.string(item.date, style: .timeOnly))
                .font(MCFont.tabular).foregroundStyle(MCColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle), \(AppDateFormatting.string(item.date, style: .dayMonthYearWithTime))")
    }

    private var title: String {
        switch item {
        case let .operation(e): RecordPhrasing.title(e)
        case let .event(r): RecordPhrasing.eventTitle(r)
        }
    }

    private var subtitle: String {
        switch item {
        case let .operation(e): RecordPhrasing.subtitle(e)
        case let .event(r): r.summary
        }
    }

    /// One glyph per outcome, from the fixed status vocabulary. A scan is a
    /// plain magnifier; it did not change anything.
    private var glyph: some View {
        let (name, color): (String, Color) = {
            switch item {
            case let .operation(e):
                if !e.failed.isEmpty { return ("xmark.octagon.fill", MCTheme.danger) }
                if e.isRefusalOnly { return ("lock.fill", MCTheme.warning) }
                return ("trash.fill", MCColor.textSecondary)
            case let .event(r):
                switch r.kind {
                case .scan: return ("magnifyingglass", MCColor.textTertiary)
                case .restore: return ("arrow.uturn.backward", MCTheme.success)
                case .error: return ("xmark.octagon.fill", MCTheme.danger)
                case .cleanup: return ("trash.fill", MCColor.textSecondary)
                }
            }
        }()
        return Image(systemName: name).foregroundStyle(color)
            .frame(width: 16).accessibilityHidden(true)
    }
}

// MARK: - Inspector: plain sections, hairlines, no tiles

private struct RecordInspector: View {
    let entry: LedgerEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.md) {
                Text(RecordPhrasing.title(entry)).font(MCFont.pageTitle)
                HStack(spacing: MCSpacing.xs) {
                    RecordStateTag(entry: entry)
                    Text(AppDateFormatting.string(entry.date, style: .dayMonthYearWithTime))
                        .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                }
                Text(factLine).font(MCFont.body).foregroundStyle(MCColor.textSecondary)
                if entry.isReversible {
                    // CoreTend does not reimplement restore. macOS already
                    // knows where each trashed file came from and offers Put
                    // Back; reproducing that would mean storing every real
                    // path, which the audit trail deliberately never does.
                    HStack(spacing: MCSpacing.xs) {
                        Button(L("record.open_trash")) {
                            NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser
                                .appendingPathComponent(".Trash"))
                        }
                        .buttonStyle(.bordered)
                        Text(L("record.reversible_note"))
                            .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    }
                } else if !entry.removedOutright.isEmpty {
                    Text(L("record.removed_note"))
                        .font(MCFont.caption).foregroundStyle(MCTheme.warning)
                }
                if !entry.moved.isEmpty { section(L("record.section_moved"), entry.moved) }
                if !entry.refused.isEmpty { section(L("record.section_kept_back"), entry.refused) }
                if !entry.failed.isEmpty { section(L("record.section_failed"), entry.failed) }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: MCSize.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var factLine: String {
        var parts = [L("record.fact_moved", mcFormatBytes(entry.movedBytes), entry.itemCount)]
        if !entry.refused.isEmpty { parts.append(L("record.subtitle_refused_other", entry.refused.count)) }
        if !entry.failed.isEmpty { parts.append(L("record.subtitle_failed_other", entry.failed.count)) }
        return parts.joined(separator: " · ")
    }

    private func section(_ title: String, _ rows: [SafetyLogRecord]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(MCFont.groupHeader).foregroundStyle(MCColor.textSecondary)
                .padding(.bottom, MCSpacing.xxs)
            Divider()
            ForEach(rows) { row in
                HStack(spacing: MCSpacing.sm) {
                    Text(row.redactedPath).font(MCFont.monoCaption)
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if row.size > 0 {
                        Text(mcFormatBytes(row.size)).font(MCFont.tabular)
                            .foregroundStyle(MCColor.textSecondary)
                    }
                    Text(row.result).font(MCFont.caption)
                        .foregroundStyle(MCColor.textSecondary).lineLimit(1)
                }
                .padding(.vertical, 5)
                .accessibilityElement(children: .combine)
                .contextMenu {
                    Button(L("common.copy_path")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(row.redactedPath, forType: .string)
                    }
                }
                if row.id != rows.last?.id { Divider() }
            }
        }
    }
}

private struct RecordEventInspector: View {
    let record: ActivityRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.md) {
                Text(RecordPhrasing.eventTitle(record)).font(MCFont.pageTitle)
                Text(AppDateFormatting.string(record.date, style: .dayMonthYearWithTime))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                Text(record.summary).font(MCFont.body)
                if record.itemCount > 0 || record.bytes > 0 {
                    Text([record.itemCount > 0 ? L("record.fact_items", record.itemCount) : nil,
                          record.bytes > 0 ? L("record.fact_seen", mcFormatBytes(record.bytes)) : nil]
                         .compactMap { $0 }.joined(separator: " · "))
                        .font(MCFont.body).foregroundStyle(MCColor.textSecondary)
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RecordStateTag: View {
    let entry: LedgerEntry

    var body: some View {
        Text(label)
            .font(MCFont.badge)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        if !entry.failed.isEmpty { return L("record.tag_failed") }
        if entry.isRefusalOnly { return L("record.tag_refused") }
        if entry.isReversible { return L("record.tag_reversible") }
        return L("record.tag_recorded")
    }

    private var color: Color {
        if !entry.failed.isEmpty { return MCTheme.danger }
        if entry.isRefusalOnly { return MCTheme.warning }
        if entry.isReversible { return MCTheme.success }
        return MCColor.textSecondary
    }
}

// MARK: - Phrasing

enum RecordPhrasing {

    /// Singular and plural as separate keys, chosen at n == 1.
    ///
    /// No .stringsdict: these counts are never zero — a title is only built
    /// from a bucket that is already non-empty — and at n >= 1 English and
    /// French split in the same place. Zero is where the two languages differ
    /// ("0 items" but "0 élément"), and zero cannot reach here.
    private static func plural(_ base: String, _ count: Int) -> String {
        L(count == 1 ? base + "_one" : base + "_other", count)
    }

    /// Named for what the operation mainly did.
    ///
    /// An operation that moved 1.24 GB *and* hit one permission error is a
    /// move with a failure in it, not a failure. Titling it by the failure
    /// buried the substance and contradicted its own subtitle — visible only
    /// once the module was captured against a seeded store, never in a mockup.
    /// The failure is not lost: it sets the state tag and gets its own section.
    static func title(_ entry: LedgerEntry) -> String {
        if !entry.moved.isEmpty {
            return plural("record.title_moved", entry.itemCount)
        }
        if !entry.failed.isEmpty {
            return plural("record.title_failed", entry.failed.count)
        }
        if !entry.refused.isEmpty {
            return plural("record.title_refused", entry.refused.count)
        }
        return plural("record.title_approved", entry.approved.count)
    }

    /// The quantity, and only the counts that are actually non-zero. "0
    /// refused" on an operation that refused nothing is noise dressed up as
    /// information.
    /// Events are titled by kind. The sentence the app wrote is the subtitle,
    /// because it was written for exactly this and is the only thing the
    /// record knows about the event.
    static func eventTitle(_ record: ActivityRecord) -> String {
        switch record.kind {
        case .scan: L("record.event_scan")
        case .restore: L("record.event_restore")
        case .error: L("record.event_error")
        case .cleanup: L("record.event_cleanup")
        }
    }

    static func subtitle(_ entry: LedgerEntry) -> String {
        var parts: [String] = []
        if !entry.moved.isEmpty { parts.append(mcFormatBytes(entry.movedBytes)) }
        if !entry.refused.isEmpty { parts.append(plural("record.subtitle_refused", entry.refused.count)) }
        if !entry.failed.isEmpty { parts.append(plural("record.subtitle_failed", entry.failed.count)) }
        if parts.isEmpty { parts.append(plural("record.subtitle_approved", entry.approved.count)) }
        return parts.joined(separator: " · ")
    }
}
