import SwiftUI
import Persistence
import DesignSystem
import UniformTypeIdentifiers

/// Groups activity records by calendar day, most recent day first, records
/// within a day kept in their incoming (already date-descending) order.
/// Pure/testable — no view or persistence dependency.
struct ActivityDayGroup: Identifiable {
    let day: Date
    let records: [ActivityRecord]
    var id: Date { day }
}

enum ActivityGrouping {
    static func byDay(_ records: [ActivityRecord], calendar: Calendar = .current) -> [ActivityDayGroup] {
        var order: [Date] = []
        var buckets: [Date: [ActivityRecord]] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(record)
        }
        return order.map { ActivityDayGroup(day: $0, records: buckets[$0] ?? []) }
    }
}

enum ActivityDateRange: String, CaseIterable, Identifiable {
    case all = "All time"
    case last7 = "Last 7 days"
    case last30 = "Last 30 days"

    var id: String { rawValue }

    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .all: return true
        case .last7: return date >= calendar.date(byAdding: .day, value: -7, to: now)!
        case .last30: return date >= calendar.date(byAdding: .day, value: -30, to: now)!
        }
    }
}

/// Real vs. simulated bytes freed across a set of records — cleanup-kind,
/// non-dry-run records are the only ones counted as "real" freed space;
/// dry-run cleanup records are reported separately and never merged in.
struct ActivityImpactSummary {
    let realFreedBytes: Int64
    let simulatedFreedBytes: Int64
    let itemCount: Int

    init(_ records: [ActivityRecord]) {
        var real: Int64 = 0
        var simulated: Int64 = 0
        for record in records where record.kind == .cleanup {
            if record.dryRun { simulated += record.bytes } else { real += record.bytes }
        }
        realFreedBytes = real
        simulatedFreedBytes = simulated
        itemCount = records.reduce(0) { $0 + $1.itemCount }
    }
}

extension Notification.Name {
    static let mcNavigate = Notification.Name("mc.navigate")
    static let mcShowOnboarding = Notification.Name("mc.showOnboarding")
    static let mcShowCommandPalette = Notification.Name("mc.showCommandPalette")
}

@MainActor
@Observable
final class MyActivityViewModel {
    enum Phase: Equatable { case loading, loaded, empty, failed(String) }

    var phase: Phase = .loading
    var allRecords: [ActivityRecord] = []
    var filter: ActivityRecord.Kind?
    var dateRange: ActivityDateRange = .all

    var records: [ActivityRecord] {
        allRecords.filter { dateRange.contains($0.date) }
    }

    var dayGroups: [ActivityDayGroup] { ActivityGrouping.byDay(records) }
    var summary: ActivityImpactSummary { ActivityImpactSummary(records) }

    func load() async {
        guard let store = AppEnvironment.shared.store else {
            phase = .failed("Local database unavailable")
            return
        }
        do {
            allRecords = try await store.activity(limit: 500, kind: filter)
            phase = allRecords.isEmpty ? .empty : .loaded
        } catch {
            phase = .failed("\(error)")
        }
    }

    func clear() async {
        guard let store = AppEnvironment.shared.store else { return }
        try? await store.clearActivity()
        await load()
    }

    /// CSV of the currently visible (filtered) records — straightforward
    /// text export, no new persistence.
    func exportCSV() -> String {
        var lines = ["Date,Kind,Summary,Items,Bytes,Simulated"]
        let formatter = ISO8601DateFormatter()
        for record in records {
            let summary = record.summary.replacingOccurrences(of: "\"", with: "'")
            lines.append("\(formatter.string(from: record.date)),\(record.kind.rawValue),\"\(summary)\",\(record.itemCount),\(record.bytes),\(record.dryRun)")
        }
        return lines.joined(separator: "\n")
    }

    /// JSON of the currently visible (filtered) records, same scope as
    /// exportCSV — one array of plain objects, no envelope metadata to keep
    /// this trivially diffable/greppable.
    func exportJSON() -> String {
        struct ExportRecord: Encodable {
            let date: String, kind: String, summary: String
            let itemCount: Int, bytes: Int64, dryRun: Bool
        }
        let formatter = ISO8601DateFormatter()
        let exportRecords = records.map {
            ExportRecord(date: formatter.string(from: $0.date), kind: $0.kind.rawValue, summary: $0.summary,
                         itemCount: $0.itemCount, bytes: $0.bytes, dryRun: $0.dryRun)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(exportRecords), let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

struct MyActivityView: View {
    @State private var model = MyActivityViewModel()
    @State private var showingSafetyLog = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                emptyState
            case .loaded:
                loadedView
            case let .failed(message):
                Text(message).foregroundStyle(MCTheme.danger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(L("activity.title"))
        .toolbar {
            Picker(L("activity.range"), selection: $model.dateRange) {
                ForEach(ActivityDateRange.allCases) { range in
                    Text(activityRangeLabel(range)).tag(range)
                }
            }
            .pickerStyle(.menu)
            Picker(L("activity.filter"), selection: $model.filter) {
                Text(L("activity.all_kinds")).tag(ActivityRecord.Kind?.none)
                ForEach(ActivityRecord.Kind.allCases, id: \.self) { kind in
                    Text(kind.rawValue.capitalized).tag(Optional(kind))
                }
            }
            .pickerStyle(.menu)
            Menu {
                Button(L("activity.export_csv")) { exportToDownloads(format: .csv) }
                Button(L("activity.export_json")) { exportToDownloads(format: .json) }
            } label: {
                Label(L("activity.export_csv"), systemImage: "square.and.arrow.up")
            }
            .disabled(model.records.isEmpty)
            Button(L("activity.clear_history"), role: .destructive) {
                Task { await model.clear() }
            }
            .disabled(model.allRecords.isEmpty)
            Button {
                showingSafetyLog = true
            } label: {
                Label(L("activity.open_safety_log"), systemImage: "checklist")
            }
        }
        .sheet(isPresented: $showingSafetyLog) { SafetyLogView() }
        .task(id: model.filter) { await model.load() }
    }

    private func activityRangeLabel(_ range: ActivityDateRange) -> String {
        switch range {
        case .all: L("activity.range.all")
        case .last7: L("activity.range.last7")
        case .last30: L("activity.range.last30")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: MCIconSize.emptyState)).foregroundStyle(MCTheme.accent)
                .accessibilityHidden(true)
            Text(model.filter == nil ? L("activity.empty") : L("activity.empty_kind"))
                .font(.title3.weight(.semibold))
            Text(L("activity.empty.subtitle"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadedView: some View {
        VStack(spacing: 0) {
            summaryBar
            if model.records.isEmpty {
                Text(L("activity.empty_range"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.dayGroups) { group in
                        Section {
                            ForEach(group.records) { record in
                                ActivityRow(record: record)
                            }
                        } header: {
                            HStack(spacing: MCSpacing.xs) {
                                Circle()
                                    .fill(MCTheme.accent)
                                    .frame(width: 6, height: 6)
                                    .accessibilityHidden(true)
                                Text(group.day.formatted(date: .complete, time: .omitted))
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: MCSpacing.lg) {
            summaryMetric(label: L("activity.freed_real"), value: mcFormatBytes(model.summary.realFreedBytes), color: MCTheme.success)
            summaryMetric(label: L("activity.simulated_dryrun"), value: mcFormatBytes(model.summary.simulatedFreedBytes), color: .secondary)
            summaryMetric(label: L("activity.items"), value: "\(model.summary.itemCount)", color: .primary)
            Spacer()
        }
        .padding(MCSpacing.md)
        .background(MCColor.elevatedBackground)
        .accessibilityElement(children: .combine)
    }

    private func summaryMetric(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    enum ExportFormat { case csv, json }

    private func exportToDownloads(format: ExportFormat) {
        let panel = NSSavePanel()
        let text: String
        switch format {
        case .csv:
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = "CoreTend-Activity.csv"
            text = model.exportCSV()
        case .json:
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "CoreTend-Activity.json"
            text = model.exportJSON()
        }
        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

private struct ActivityRow: View {
    let record: ActivityRecord
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                Text(L("activity.row.detail", record.itemCount, mcFormatBytes(record.bytes),
                       record.dryRun ? L("activity.row.simulated_suffix") : L("activity.row.real_suffix")))
                    .font(.caption)
                if record.kind == .restore {
                    Button {
                        NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.protection)
                    } label: {
                        Label(L("activity.open_protection"), systemImage: "shield")
                    }
                    .buttonStyle(.link)
                }
            }
            .padding(.top, MCSpacing.xxs)
        } label: {
            HStack {
                Image(systemName: icon(for: record.kind))
                    .foregroundStyle(color(for: record.kind))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(record.summary)
                Spacer()
                if record.kind == .cleanup {
                    Text(record.dryRun ? L("common.dry_run") : L("activity.completed"))
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(record.dryRun ? Color(nsColor: .quaternaryLabelColor) : MCTheme.success.opacity(0.18), in: Capsule())
                        .foregroundStyle(record.dryRun ? .secondary : MCTheme.success)
                }
                Text(mcFormatBytes(record.bytes))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(record.summary), \(record.date.formatted(date: .abbreviated, time: .shortened)), \(record.dryRun ? L("activity.row.simulated_a11y") : L("activity.row.real_a11y")), \(mcFormatBytes(record.bytes))")
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
