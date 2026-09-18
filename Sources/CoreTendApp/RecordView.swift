// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import Persistence
import SafetyCore
import DesignSystem

/// The record — direction B's spine.
///
/// A list of operations with an inspector for the selected one, which is the
/// shape macOS already teaches for a long record with deep evidence: Mail,
/// Console, Time Machine. The alternatives were measured against this one in
/// Documentation/Mockups/COMPARISON.md; a feed of cards fitted three and a
/// half entries in a full-height window, and a flat table had nowhere to put
/// per-item evidence, refusal reasoning, or reversal.
@MainActor
@Observable
final class RecordViewModel {
    enum Phase: Equatable { case loading, loaded, empty, failed(String) }

    var phase: Phase = .loading
    private(set) var entries: [LedgerEntry] = []
    var selection: LedgerEntry.ID?

    var summary: SafetyLedger.Summary { SafetyLedger.summary(of: entries) }

    var selectedEntry: LedgerEntry? {
        guard let selection else { return nil }
        return entries.first { $0.id == selection }
    }

    func load() async {
        guard let store = AppEnvironment.shared.store else {
            phase = .failed(L("record.unavailable"))
            return
        }
        do {
            entries = SafetyLedger.entries(from: try await store.safetyLog(limit: 1000))
            phase = entries.isEmpty ? .empty : .loaded
            // Selecting the newest entry means the inspector is never an empty
            // pane on arrival; a record whose detail side is blank reads as
            // broken rather than as waiting.
            if selection == nil || !entries.contains(where: { $0.id == selection }) {
                selection = entries.first?.id
            }
        } catch {
            phase = .failed("\(error)")
        }
    }

    func purge() async {
        guard let store = AppEnvironment.shared.store else { return }
        try? await store.purgeSafetyLog()
        selection = nil
        await load()
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
                MCEmptyState(icon: "list.bullet.rectangle",
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
            // Behind a menu, not alone in the toolbar. Erasing the record is
            // the only destructive thing this screen can do, and it should not
            // be the most prominent control on the screen whose whole point is
            // that the record is kept.
            Menu {
                Button(L("record.purge"), role: .destructive) { confirmingPurge = true }
                    .disabled(model.entries.isEmpty)
            } label: {
                Label(L("common.more"), systemImage: "ellipsis.circle")
            }
            .menuIndicator(.hidden)
        }
        // The safety log is append-only by design: purgeSafetyLog is the only
        // path that ever removes a row, it removes all of them, and nothing
        // restores them. It fired on a single click with no confirmation.
        .confirmationDialog(L("record.purge_confirm_title"),
                            isPresented: $confirmingPurge, titleVisibility: .visible) {
            Button(L("record.purge_confirm_action"), role: .destructive) {
                Task { await model.purge() }
            }
            Button(L("common.cancel"), role: .cancel) { }
        } message: {
            Text(L("record.purge_confirm_message", model.entries.count))
        }
        .task { await model.load() }
    }

    private var loaded: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                summaryStrip
                Divider()
                List(selection: $model.selection) {
                    ForEach(SafetyLedger.byDay(model.entries)) { group in
                        Section(AppDateFormatting.string(group.day, style: .fullDay)) {
                            ForEach(group.entries) { entry in
                                RecordRow(entry: entry).tag(entry.id)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(width: 320)
            Divider()
            if let entry = model.selectedEntry {
                RecordInspector(entry: entry)
            } else {
                MCEmptyState(icon: "sidebar.left",
                             title: L("record.no_selection_title"),
                             message: L("record.no_selection_message"))
            }
        }
    }

    /// Two figures, both of which CoreTend owns. There is no all-time
    /// "reclaimed" total here on purpose — see SafetyLedger.Summary.
    private var summaryStrip: some View {
        HStack(alignment: .top, spacing: MCSpacing.lg) {
            metric(L("record.summary_moved"), mcFormatBytes(model.summary.movedBytes), MCColor.teal)
            metric(L("record.summary_refused"), "\(model.summary.refusedItems)", MCColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(MCSpacing.md)
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(MCFont.groupHeader).foregroundStyle(MCColor.textSecondary)
            Text(value).font(MCFont.metric).foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

// MARK: - List

private struct RecordRow: View {
    let entry: LedgerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: MCSpacing.xs) {
                Text(RecordPhrasing.title(entry))
                    .font(MCFont.rowTitle).lineLimit(1)
                Spacer(minLength: 0)
                Text(AppDateFormatting.string(entry.date, style: .timeOnly))
                    // Secondary, not tertiary: in a record the time is the
                    // primary key, not decoration. Measured at 3.58:1 as
                    // tertiary in the mockups, under the 4.5:1 minimum.
                    .font(MCFont.micro).foregroundStyle(MCColor.textSecondary)
            }
            Text(RecordPhrasing.subtitle(entry))
                .font(MCFont.micro).foregroundStyle(MCColor.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(RecordPhrasing.title(entry)), \(RecordPhrasing.subtitle(entry)), \(AppDateFormatting.string(entry.date, style: .dayMonthYearWithTime))")
    }
}

// MARK: - Inspector

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
                if entry.isReversible {
                    // The honest form of the claim. The app knows it moved the
                    // items; it is never told when the user empties the Trash,
                    // so it states the condition instead of asserting the state.
                    Text(L("record.reversible_note"))
                        .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                }

                stats

                if !entry.moved.isEmpty {
                    section(L("record.section_moved"), entry.moved)
                }
                if !entry.refused.isEmpty {
                    section(L("record.section_kept_back"), entry.refused)
                }
                if !entry.failed.isEmpty {
                    section(L("record.section_failed"), entry.failed)
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var stats: some View {
        HStack(spacing: MCSpacing.lg) {
            stat(L("record.stat_moved"), mcFormatBytes(entry.movedBytes), MCColor.teal)
            stat(L("record.stat_items"), "\(entry.itemCount)", MCColor.textPrimary)
            stat(L("record.stat_refused"), "\(entry.refused.count)", MCColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(MCSpacing.sm)
        .mcSurface(.raised, radius: MCRadius.card)
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(MCFont.groupHeader).foregroundStyle(MCColor.textSecondary)
            Text(value).font(MCFont.metric).foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    private func section(_ title: String, _ rows: [SafetyLogRecord]) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            Text(title).font(MCFont.groupHeader).foregroundStyle(MCColor.textSecondary)
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(spacing: MCSpacing.sm) {
                        Text(row.redactedPath)
                            .font(MCFont.monoCaption)
                            .lineLimit(1).truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if row.size > 0 {
                            Text(mcFormatBytes(row.size))
                                .font(MCFont.micro).foregroundStyle(MCColor.textSecondary)
                        }
                        Text(row.result)
                            .font(MCFont.micro).foregroundStyle(MCColor.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, MCSpacing.sm).padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    if row.id != rows.last?.id { Divider() }
                }
            }
            .mcSurface(.raised, radius: MCRadius.card)
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

/// How an entry reads. Separated from the views so the wording is testable and
/// there is exactly one place where an operation becomes a sentence.
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
    static func subtitle(_ entry: LedgerEntry) -> String {
        var parts: [String] = []
        if !entry.moved.isEmpty { parts.append(mcFormatBytes(entry.movedBytes)) }
        if !entry.refused.isEmpty { parts.append(plural("record.subtitle_refused", entry.refused.count)) }
        if !entry.failed.isEmpty { parts.append(plural("record.subtitle_failed", entry.failed.count)) }
        if parts.isEmpty { parts.append(plural("record.subtitle_approved", entry.approved.count)) }
        return parts.joined(separator: " · ")
    }
}
