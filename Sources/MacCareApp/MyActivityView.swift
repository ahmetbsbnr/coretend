import SwiftUI
import AppKit
import Persistence
import DesignSystem

@MainActor
@Observable
final class MyActivityViewModel {
    enum Phase: Equatable { case loading, loaded, empty, failed(String) }

    var phase: Phase = .loading
    var records: [ActivityRecord] = []
    var filter: ActivityRecord.Kind?

    var groupedByDay: [(day: Date, records: [ActivityRecord])] {
        ActivityGrouping.groupByDay(records)
    }

    var byteSummary: (real: Int64, simulated: Int64) {
        ActivityGrouping.byteSummary(records)
    }

    func load() async {
        guard let store = AppEnvironment.shared.store else {
            phase = .failed("Local database unavailable")
            return
        }
        do {
            records = try await store.activity(limit: 500, kind: filter)
            phase = records.isEmpty ? .empty : .loaded
        } catch {
            phase = .failed("\(error)")
        }
    }

    func clear() async {
        guard let store = AppEnvironment.shared.store else { return }
        try? await store.clearActivity()
        await load()
    }

    func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MacCareActivity.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? ActivityGrouping.csv(records).write(to: url, atomically: true, encoding: .utf8)
    }
}

struct MyActivityView: View {
    @State private var model = MyActivityViewModel()
    @State private var expandedDays: Set<Date> = []
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48)).foregroundStyle(MCTheme.accent)
                    Text("No activity yet").font(.title3.weight(.semibold))
                    Text("Scans and cleanups will appear here. Everything stays on this Mac.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                VStack(spacing: 0) {
                    summaryBar
                    Divider()
                    List {
                        ForEach(model.groupedByDay, id: \.day) { group in
                            Section {
                                ForEach(group.records) { record in
                                    ActivityRow(record: record)
                                }
                            } header: {
                                DayHeader(day: group.day, records: group.records)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            case let .failed(message):
                Text(message).foregroundStyle(MCTheme.danger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("My Activity")
        .toolbar {
            Picker("Filter", selection: $model.filter) {
                Text("All").tag(ActivityRecord.Kind?.none)
                ForEach(ActivityRecord.Kind.allCases, id: \.self) { kind in
                    Text(kind.rawValue.capitalized).tag(Optional(kind))
                }
            }
            .pickerStyle(.menu)
            Button {
                model.exportCSV()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(model.records.isEmpty)
            Button("Clear History", role: .destructive) {
                Task { await model.clear() }
            }
            .disabled(model.records.isEmpty)
        }
        .task(id: model.filter) { await model.load() }
    }

    @ViewBuilder
    private var summaryBar: some View {
        let summary = model.byteSummary
        let counts = ActivityGrouping.successFailCounts(model.records)
        HStack(spacing: 20) {
            summaryTile(title: "Real bytes freed", value: mcFormatBytes(summary.real), color: MCTheme.accent)
            summaryTile(title: "Simulated (dry run)", value: mcFormatBytes(summary.simulated), color: MCTheme.warning)
            summaryTile(title: "Success / Fail", value: "\(counts.success) / \(counts.fail)", color: counts.fail > 0 ? MCTheme.danger : .secondary)
            Spacer()
        }
        .padding(12)
        .background(reduceTransparency ? AnyShapeStyle(.background) : AnyShapeStyle(.thinMaterial))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(MyActivitySummary.accessibilityDescription(real: summary.real, simulated: summary.simulated, success: counts.success, fail: counts.fail))
    }

    private func summaryTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(color)
        }
    }
}

/// Data-only helper — kept separate from the View so it can stay `nonisolated`.
/// (View conformance infers @MainActor on all members, including statics.)
enum MyActivitySummary {
    nonisolated static func accessibilityDescription(real: Int64, simulated: Int64, success: Int, fail: Int) -> String {
        "\(mcFormatBytes(real)) freed from real cleanups, \(mcFormatBytes(simulated)) simulated in dry runs. "
        + "\(success) successful operations, \(fail) failed."
    }
}

private struct DayHeader: View {
    let day: Date
    let records: [ActivityRecord]

    var body: some View {
        HStack {
            Text(day.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(records.count) event\(records.count == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct ActivityRow: View {
    let record: ActivityRecord
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon(for: record.kind))
                    .foregroundStyle(color(for: record.kind))
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text(record.summary)
                    Text(record.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if record.dryRun {
                    Text("Dry run")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Text(mcFormatBytes(record.bytes))
                    .monospacedDigit().foregroundStyle(.secondary)
                Button {
                    if reduceMotion {
                        expanded.toggle()
                    } else {
                        withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                    }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Collapse details" : "Expand details")
            }
            if expanded {
                HStack(spacing: 16) {
                    Label("\(record.kind == .error ? 0 : record.itemCount) succeeded", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                    Label("\(record.kind == .error ? record.itemCount : 0) failed", systemImage: "xmark.circle")
                        .foregroundStyle(record.kind == .error ? MCTheme.danger : .secondary)
                }
                .font(.caption)
                .padding(.leading, 32)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func icon(for kind: ActivityRecord.Kind) -> String {
        switch kind {
        case .scan: "magnifyingglass"
        case .cleanup: "sparkles"
        case .restore: "arrow.uturn.backward"
        case .error: "exclamationmark.triangle"
        }
    }

    private func color(for kind: ActivityRecord.Kind) -> Color {
        switch kind {
        case .scan: MCTheme.accentSecondary
        case .cleanup: MCTheme.accent
        case .restore: MCTheme.warning
        case .error: MCTheme.danger
        }
    }
}
