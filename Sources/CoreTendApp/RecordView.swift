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
    private enum FocusTarget: Hashable { case list, detail }
    @FocusState private var focus: FocusTarget?
    @State private var model = RecordViewModel()
    @State private var confirmingPurge = false
    /// Only the compact layout pushes. Nil on arrival, always.
    @State private var pushed: RecordItem.ID?

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
                MCEmptyState(icon: "exclamationmark.triangle.fill",
                             title: L("record.error_title"), message: message)
            case .loaded:
                loaded
            }
        }
        .navigationTitle(L("record.title"))
        .toolbar {
            ToolbarItemGroup {
                // A pop-up button in a toolbar sizes itself to its widest
                // option and, with its label shown, reserves room for a title
                // it never draws — which is why it stood a head taller than
                // its neighbours and sat off their centre line. Labelled for
                // VoiceOver, hidden on screen, and given the one width it
                // needs, it lines up with the rest of the toolbar.
                Picker(L("record.filter"), selection: $model.filter) {
                    ForEach(RecordViewModel.Filter.allCases) { f in Text(f.label).tag(f) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 130)
                .accessibilityLabel(L("record.filter"))
                Menu {
                    Button(L("record.export_csv")) { exportCSV() }.disabled(model.items.isEmpty)
                    Divider()
                    Button(L("record.purge"), role: .destructive) { confirmingPurge = true }
                        .disabled(model.items.isEmpty)
                } label: {
                    // Icon-only *and* indicator-hidden: hiding the indicator
                    // alone leaves its width behind, and the glyph drifts left
                    // of the button it sits in.
                    Label(L("common.more"), systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .help(L("common.more"))
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
        .onChange(of: focus) { _, value in FocusTrace.snapshot("swiftui:record.focus=\(String(describing: value))") }
        .onChange(of: pushed) { old, new in
            if old != nil, new == nil {
                focus = .list
                DispatchQueue.main.async { FocusTrace.snapshot("record:detail.closed") }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcExportRecord)) { _ in
            if !model.items.isEmpty { exportCSV() }
        }
    }

    /// One line describing an entry, for the clipboard.
    static func summaryLine(for item: RecordItem) -> String {
        let when = AppDateFormatting.string(item.date, style: .dayMonthYearWithTime)
        switch item {
        case let .operation(entry): return "\(when) — \(RecordPhrasing.title(entry))"
        case let .event(record): return "\(when) — \(RecordPhrasing.eventTitle(record)): \(record.summary)"
        }
    }

    /// List and inspector side by side, unless the window is too narrow for
    /// both to be usable — then the list fills the width and selecting an
    /// entry pushes its detail, the way a split view behaves when it
    /// collapses. At 1000pt a 380pt list left the inspector 600pt for paths
    /// that are routinely longer than that.
    ///
    /// The width is measured rather than inferred from `ViewThatFits`,
    /// because the two layouts need different state: side by side there is
    /// always a selection, and pushed there must not be one on arrival or the
    /// person lands on a detail screen they never asked for. The first
    /// compact capture opened straight into an entry.
    private var loaded: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                HStack(spacing: 0) {
                    // The journal takes the slack, the inspector is capped.
                    //
                    // These were the other way round: on a standard window the
                    // list had 780 points and the inspector 1060 to show four
                    // facts. A register's value is how much of it you can see.
                    listPane.frame(minWidth: 420, maxWidth: .infinity)
                    Divider()
                    inspector.frame(width: 380).frame(maxHeight: .infinity)
                        .focusable().focused($focus, equals: .detail)
                        .onKeyPress(.escape) { focus = .list; return .handled }
                }
                .onAppear { pushed = nil }
            } else {
                NavigationStack {
                    listPane
                        .navigationDestination(item: $pushed) { id in
                            inspectorFor(id).navigationTitle(L("record.entry"))
                                .focusable().focused($focus, equals: .detail)
                                .onAppear { focus = .detail }
                                .onKeyPress(.escape) { pushed = nil; return .handled }
                        }
                }
            }
        }
    }

    private var listPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryLine
            Divider()
            list
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
            List(selection: Binding(
                get: { model.selection },
                set: { id in
                    model.selection = id
                }
            )) {
                ForEach(SafetyLedger.byDay(visible)) { group in
                    Section {
                        ForEach(group.entries) { item in
                            RecordRow(item: item).tag(item.id)
                        }
                    } header: {
                        Text(AppDateFormatting.string(group.day, style: .fullDay))
                            .font(MCFont.micro.weight(.semibold))
                            .foregroundStyle(MCColor.textTertiary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 22)
            .focused($focus, equals: .list)
            // Real actions, not an empty menu.
            //
            // This rendered `EmptyView()`, so right-clicking a journal entry
            // opened an empty grey rectangle — the same defect as the
            // "Inspect" action lost from Integrity, found by the same audit.
            // `primaryAction` (double-click opens the entry) was the part that
            // was wanted; the menu came along with it and was never filled.
            .contextMenu(forSelectionType: RecordItem.ID.self) { ids in
                if let id = ids.first, let item = model.items.first(where: { $0.id == id }) {
                    Button(L("record.context.open")) {
                        model.selection = id
                        pushed = id
                        focus = .detail
                    }
                    Divider()
                    Button(L("common.copy_summary")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.summaryLine(for: item), forType: .string)
                    }
                }
            } primaryAction: { ids in
                guard let id = ids.first else { return }
                model.selection = id
                pushed = id
                focus = .detail
            }
        }
    }

    @ViewBuilder
    private func inspectorFor(_ id: RecordItem.ID) -> some View {
        switch model.items.first(where: { $0.id == id }) {
        case let .operation(entry): RecordInspector(entry: entry)
        case let .event(record): RecordEventInspector(record: record)
        case nil: EmptyView()
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
            Text(title)
                .font(MCFont.rowTitle)
                .lineLimit(1)
            Text(subtitle)
                .font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
                .lineLimit(1).truncationMode(.tail)
                .layoutPriority(-1)
            Spacer(minLength: MCSpacing.xs)
            // A column, not a value floating after the sentence. Sizes are
            // what a reader compares down a register, and comparing needs
            // them on one axis.
            Text(sizeText)
                .font(MCFont.tabular)
                .foregroundStyle(MCColor.textSecondary)
                .frame(width: 78, alignment: .trailing)
            Text(AppDateFormatting.string(item.date, style: .timeOnly))
                .font(MCFont.tabular).foregroundStyle(MCColor.textTertiary)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle), \(AppDateFormatting.string(item.date, style: .dayMonthYearWithTime))")
    }

    private var title: String {
        switch item {
        case let .operation(e): RecordPhrasing.title(e)
        case let .event(r): RecordPhrasing.eventTitle(r)
        }
    }

    /// The bytes this entry concerns, or nothing when it concerns none.
    private var sizeText: String {
        switch item {
        case let .operation(e): e.movedBytes > 0 ? mcFormatBytes(e.movedBytes) : ""
        case let .event(r): r.bytes > 0 ? mcFormatBytes(r.bytes) : ""
        }
    }

    /// What the title does not already say.
    ///
    /// For an operation this was the byte figure — which now has its own
    /// right-aligned column, so printing it here too put the same number on
    /// the row twice. Operations keep their subtitle only when it carries
    /// something other than the size (a refusal count, a failure count).
    private var subtitle: String {
        switch item {
        case let .operation(e):
            let text = RecordPhrasing.subtitle(e)
            return text == mcFormatBytes(e.movedBytes) ? "" : text
        case let .event(r):
            return r.summary
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
                case .scan: return ("sparkle.magnifyingglass", MCColor.textTertiary)
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

    /// A section of evidence.
    ///
    /// The per-row result is printed only where the rows disagree. Four rows
    /// under "What moved" each ending in "moved to Trash" is the heading said
    /// four more times; the one case that matters — a volume with no Trash,
    /// where an item was removed outright — is exactly the case where the
    /// results differ, and there the column appears.
    private func section(_ title: String, _ rows: [SafetyLogRecord]) -> some View {
        let resultsAgree = Set(rows.map(\.result)).count <= 1
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(MCFont.groupHeader).foregroundStyle(MCColor.textSecondary)
                if resultsAgree, let result = rows.first?.result, !result.isEmpty {
                    Text("· \(result)").font(MCFont.groupHeader)
                        .foregroundStyle(MCColor.textTertiary)
                }
            }
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
                    if !resultsAgree {
                        Text(row.result).font(MCFont.caption)
                            .foregroundStyle(MCColor.textSecondary).lineLimit(1)
                    }
                }
                .padding(.vertical, MCSpacing.tight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.redactedPath), \(row.size > 0 ? mcFormatBytes(row.size) + ", " : "")\(row.result)")
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

/// The inspector for an event.
///
/// This used to be four lines of text in a pane 900 points wide, which is what
/// a dense-history capture exposed: the list beside it was carrying twenty-four
/// rows of information and the detail pane was the emptiest surface in the app.
/// An event has more to say than its own summary — what kind of thing it was,
/// what it measured, and where it sits in the history around it — and saying
/// it is what makes the pane worth its width.
private struct RecordEventInspector: View {
    let record: ActivityRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                header
                if !facts.isEmpty { factGrid }
                meaning
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: MCSize.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            HStack(spacing: MCSpacing.xs) {
                MCStatusTag(kindLabel, tone: kindTone)
                Text(AppDateFormatting.string(record.date, style: .dayMonthYearWithTime))
                    .font(MCFont.caption)
                    .foregroundStyle(MCColor.textSecondary)
            }
            Text(RecordPhrasing.eventTitle(record))
                .font(MCFont.pageTitle)
            Text(record.summary)
                .font(MCFont.body)
                .foregroundStyle(MCColor.textSecondary)
        }
    }

    /// The measured quantities, as figures rather than as a sentence. A number
    /// a person may want to compare against another screen should be set as a
    /// number.
    private var factGrid: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(facts.enumerated()), id: \.element.label) { index, fact in
                if index > 0 {
                    Rectangle().fill(MCColor.separator.opacity(MCOpacity.hairline))
                        .frame(width: 1, height: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label.uppercased())
                        .font(MCFont.groupHeader)
                        .foregroundStyle(MCColor.textSecondary)
                    Text(fact.value)
                        .font(MCFont.displaySecondary)
                        .foregroundStyle(MCColor.textPrimary)
                }
                .padding(.horizontal, MCSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, -MCSpacing.sm)
        .padding(.vertical, MCSpacing.sm)
        .overlay(alignment: .top) {
            Rectangle().fill(MCColor.separator.opacity(MCOpacity.hairline)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(MCColor.separator.opacity(MCOpacity.hairline)).frame(height: 1)
        }
    }

    private var facts: [(label: String, value: String)] {
        var out: [(String, String)] = []
        if record.itemCount > 0 { out.append((L("record.fact_label_items"), "\(record.itemCount)")) }
        if record.bytes > 0 { out.append((L("record.fact_label_seen"), mcFormatBytes(record.bytes))) }
        return out
    }

    /// What this event does and does not entitle the reader to conclude. A
    /// scan found things; it did not change anything, and the record should
    /// say so rather than leaving the reader to infer it from the absence of
    /// an evidence section.
    private var meaning: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            Text(L("record.section_meaning"))
                .font(MCFont.groupHeader)
                .foregroundStyle(MCColor.textSecondary)
            Text(meaningText)
                .font(MCFont.secondaryBody)
                .foregroundStyle(MCColor.textSecondary)
        }
    }

    private var meaningText: String {
        switch record.kind {
        case .scan: L("record.meaning_scan")
        case .cleanup: L("record.meaning_cleanup")
        case .restore: L("record.meaning_restore")
        case .error: L("record.meaning_error")
        }
    }

    private var kindLabel: String {
        switch record.kind {
        case .scan: L("record.filter_scans")
        case .cleanup: L("record.tag_recorded")
        case .restore: L("record.tag_reversible")
        case .error: L("record.tag_failed")
        }
    }

    private var kindTone: MCStatusTag.Tone {
        switch record.kind {
        case .scan: .inert
        case .cleanup: .accent
        case .restore: .success
        case .error: .failure
        }
    }
}

private struct RecordStateTag: View {
    let entry: LedgerEntry

    var body: some View {
        MCStatusTag(label, tone: tone)
    }

    private var label: String {
        if !entry.failed.isEmpty { return L("record.tag_failed") }
        if entry.isRefusalOnly { return L("record.tag_refused") }
        if entry.isReversible { return L("record.tag_reversible") }
        return L("record.tag_recorded")
    }

    private var tone: MCStatusTag.Tone {
        if !entry.failed.isEmpty { return .failure }
        if entry.isRefusalOnly { return .attention }
        if entry.isReversible { return .success }
        return .inert
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
