// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import Persistence
import SafetyCore
import DesignSystem

/// Read-only view over the persistent SafetyCore audit trail (safety_log).
/// Every row carries its own execution stage and redacted path.
@MainActor
@Observable
final class SafetyLogViewModel {
    enum Phase: Equatable { case loading, loaded, empty, failed(String) }

    var phase: Phase = .loading
    var records: [SafetyLogRecord] = []
    /// Audit events that could not be written since launch. A log that is
    /// short must say so; a counter nobody reads is the same silence with an
    /// extra step.
    var unrecordedEvents = 0

    var executedCount: Int { records.filter { $0.stage == .executed }.count }
    var skippedOrErrorCount: Int { records.filter { $0.stage == .skipped || $0.stage == .error }.count }

    func load() async {
        guard let store = AppEnvironment.shared.store else {
            phase = .failed(L("safetylog.unavailable"))
            return
        }
        do {
            records = try await store.safetyLog(limit: 1000)
            unrecordedEvents = await store.unrecordedEventCount
            phase = records.isEmpty ? .empty : .loaded
        } catch {
            phase = .failed("\(error)")
        }
    }

    func purge() async {
        guard let store = AppEnvironment.shared.store else { return }
        try? await store.purgeSafetyLog()
        await load()
    }
}

struct SafetyLogView: View {
    @State private var model = SafetyLogViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            switch model.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                Text(L("safetylog.empty"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                Text(message).foregroundStyle(MCTheme.danger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                List(model.records) { record in
                    SafetyLogRow(record: record)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .task { await model.load() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("safetylog.title")).font(MCFont.cardTitle)
                Text(L("safetylog.subtitle_detail", model.executedCount, model.skippedOrErrorCount))
                    .font(.caption).foregroundStyle(.secondary)
                if model.unrecordedEvents > 0 {
                    // The log admitting its own gap — the only figure here
                    // that is about the journal rather than about the files,
                    // and the only one that can make the rest untrue.
                    Text(L("safetylog.unrecorded", model.unrecordedEvents))
                        .font(.caption)
                        .foregroundStyle(MCTheme.warning)
                }
            }
            Spacer()
            Button(L("safetylog.purge"), role: .destructive) {
                Task { await model.purge() }
            }
            .disabled(model.records.isEmpty)
            Button(L("common.done")) { dismiss() }
        }
        .padding(MCSpacing.md)
    }
}

private struct SafetyLogRow: View {
    let record: SafetyLogRecord

    var body: some View {
        HStack(spacing: MCSpacing.sm) {
            stageBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(record.redactedPath)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1).truncationMode(.middle)
                Text("\(record.ruleID) · \(FindingMetadata.riskLabel(rawValue: record.risk)) · \(mcFormatBytes(record.size)) · \(AppDateFormatting.string(record.date, style: .dayMonthYearWithTime))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.result)
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(stageLabel), \(record.redactedPath), \(L("safetylog.a11y.rule", record.ruleID)), \(L("safetylog.a11y.risk", FindingMetadata.riskLabel(rawValue: record.risk))), \(mcFormatBytes(record.size)), \(AppDateFormatting.string(record.date, style: .dayMonthYearWithTime)), \(record.result)"
        )
    }

    private var stageLabel: String {
        switch record.stage {
        case .approved: L("safetylog.stage.approved")
        case .executed: L("safetylog.stage.executed")
        case .skipped: L("safetylog.stage.skipped")
        case .error: L("safetylog.stage.error")
        }
    }

    private var stageColor: Color {
        switch record.stage {
        case .approved: MCTheme.accentSecondary
        case .executed: MCTheme.success
        case .skipped: MCTheme.warning
        case .error: MCTheme.danger
        }
    }

    private var stageBadge: some View {
        Text(stageLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(stageColor.opacity(0.18), in: Capsule())
            .foregroundStyle(stageColor)
            .accessibilityHidden(true)
    }
}
