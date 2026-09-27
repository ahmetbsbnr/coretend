import SwiftUI
import UniformTypeIdentifiers
import Persistence
import AppShell
import Domain

struct RecordView: View {
    let french: Bool
    @State private var store: SQLiteStore?
    @State private var events: [ActivityEvent] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var selectedKind = "all"
    @State private var selectedRange: ActivityDateRange = .all
    @State private var confirmClear = false
    @State private var isExporting = false
    @State private var exportDocument: ActivityExportDocument?
    @State private var exportName = "coretend-activity"

    private var filtered: [ActivityEvent] {
        ActivityHistoryGrouping.filteredEvents(events, kind: ActivityKind(rawValue: selectedKind), range: selectedRange)
    }
    private var groups: [ActivityDayGroup] {
        ActivityHistoryGrouping.groups(events, kind: ActivityKind(rawValue: selectedKind), range: selectedRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy("record.localNotice")).font(.callout).foregroundStyle(.secondary)
            HStack {
                Picker(copy("record.filter"), selection: $selectedKind) {
                    Text(copy("record.all")).tag("all")
                    ForEach(ActivityKind.allCases, id: \.rawValue) { kind in
                        Text(copy("activity.\(kind.rawValue)")).tag(kind.rawValue)
                    }
                }
                .frame(maxWidth: 210)
                Picker(copy("record.range"), selection: $selectedRange) {
                    Text(copy("record.range.all")).tag(ActivityDateRange.all)
                    Text(copy("record.range.last7")).tag(ActivityDateRange.last7Days)
                    Text(copy("record.range.last30")).tag(ActivityDateRange.last30Days)
                }
                .frame(maxWidth: 180)
                Spacer()
                Menu {
                    Button(copy("record.export.json")) { prepareExport(json: true) }
                    Button(copy("record.export.csv")) { prepareExport(json: false) }
                    Divider()
                    Button(copy("record.clear"), role: .destructive) { confirmClear = true }
                } label: { Label(copy("record.actions"), systemImage: "ellipsis.circle") }
                .disabled(store == nil || loading)
            }
            if loading { ProgressView() }
            if let errorMessage { ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle") }
            else if filtered.isEmpty && !loading { ContentUnavailableView(copy("record.empty"), systemImage: "clock.arrow.circlepath") }
            else {
                List {
                    ForEach(groups, id: \.day) { group in
                        Section(group.day.formatted(.dateTime.year().month().day().locale(Locale(identifier: french ? "fr_FR" : "en_US")))) {
                            ForEach(group.events, id: \.id) { event in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: event.kind == .failed ? "exclamationmark.circle" : "circle.inset.filled")
                                        .foregroundStyle(event.kind == .failed ? .orange : .secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(copy("activity.\(event.kind.rawValue)")).font(.headline)
                                        Text(ProductCopy.activityDetail(event.detail, failureCode: event.kind == .failed ? event.failureCode : nil, french: french)).textSelection(.enabled)
                                    }
                                    Spacer()
                                    Text(event.occurredAt.formatted(.dateTime.hour().minute()))
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
        .alert(copy("record.clear.title"), isPresented: $confirmClear) {
            Button(copy("common.cancel"), role: .cancel) {}
            Button(copy("record.clear.confirm"), role: .destructive) { Task { await clear() } }
        } message: { Text(copy("record.clear.message")) }
        .fileExporter(isPresented: $isExporting, document: exportDocument,
                      contentType: exportDocument?.contentType ?? .json,
                      defaultFilename: exportName) { result in
            if case .failure = result { errorMessage = copy("record.error") }
        }
    }

    @MainActor private func load() async {
        loading = true
        defer { loading = false }
        do {
            let localStore = try await LocalStoreAccess.open()
            store = localStore
            events = try await localStore.events()
        } catch { errorMessage = copy("record.error") }
    }

    @MainActor private func clear() async {
        guard let store else { return }
        do { try await store.clearHistory(); events = [] }
        catch { errorMessage = copy("record.error") }
    }

    @MainActor private func prepareExport(json: Bool) {
        guard let store else { return }
        Task {
            do {
                let current = ActivityHistoryGrouping.filteredEvents(
                    try await store.events(), kind: ActivityKind(rawValue: selectedKind), range: selectedRange
                )
                let data = json ? try ActivityExport.json(current) : Data(ActivityExport.csv(current).utf8)
                let type: UTType = json ? .json : .commaSeparatedText
                exportDocument = ActivityExportDocument(data: data, contentType: type)
                exportName = json ? "coretend-activity.json" : "coretend-activity.csv"
                isExporting = true
            } catch { errorMessage = copy("record.error") }
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}

private struct ActivityExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    let data: Data
    let contentType: UTType
    init(data: Data, contentType: UTType) { self.data = data; self.contentType = contentType }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        contentType = configuration.contentType
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
