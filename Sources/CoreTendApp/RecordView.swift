import SwiftUI
import UniformTypeIdentifiers
import Persistence
import AppShell
import Domain
import DesignSystem

struct RecordView: View {
    let french: Bool
    @State private var store: SQLiteStore?
    @State private var events: [ActivityEvent] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var selectedKind = "all"
    @State private var query = ""
    @State private var selectedRange: ActivityDateRange = .all
    @State private var confirmClear = false
    @State private var isExporting = false
    @State private var exportDocument: ActivityExportDocument?
    @State private var exportName = "coretend-activity"

    private var filtered: [ActivityEvent] {
        search(ActivityHistoryGrouping.filteredEvents(events, kind: ActivityKind(rawValue: selectedKind), range: selectedRange))
    }
    private var groups: [ActivityDayGroup] {
        ActivityHistoryGrouping.groups(filtered)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(copy("record.localNotice"), systemImage: "lock.shield")
                .font(CoreTendTypography.secondary)
                .foregroundStyle(Palette.secondaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 14))
            TextField(french ? "Rechercher dans l’historique" : "Search history", text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(french ? "Rechercher dans l’historique" : "Search history")
            VStack(alignment: .leading, spacing: 6) {
                Picker(copy("record.filter"), selection: $selectedKind) {
                    Text(copy("record.all")).tag("all")
                    ForEach(ActivityKind.allCases, id: \.rawValue) { kind in
                        Text(copy("activity.\(kind.rawValue)")).tag(kind.rawValue)
                    }
                }
                .frame(maxWidth: 250)
                Picker(copy("record.range"), selection: $selectedRange) {
                    Text(copy("record.range.all")).tag(ActivityDateRange.all)
                    Text(copy("record.range.last7")).tag(ActivityDateRange.last7Days)
                    Text(copy("record.range.last30")).tag(ActivityDateRange.last30Days)
                }
                .frame(maxWidth: 250)
            }
            Text("\(filtered.count) \(french ? "événement(s)" : "event(s)")")
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            HStack(spacing: 12) {
                Menu {
                    Button(copy("record.export.json")) { prepareExport(json: true) }
                    Button(copy("record.export.csv")) { prepareExport(json: false) }
                } label: { Label(french ? "Exporter…" : "Export…", systemImage: "square.and.arrow.up") }
                .disabled(store == nil || loading)
                Button(role: .destructive) { confirmClear = true } label: {
                    Label(copy("record.clear"), systemImage: "trash")
                }
                .disabled(store == nil || loading)
            }
            if loading { ProgressView(french ? "Chargement de l’historique" : "Loading history") }
            if let errorMessage { ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle") }
            else if filtered.isEmpty && !loading {
                ContentUnavailableView(events.isEmpty ? copy("record.empty") :
                                       (french ? "Aucun résultat pour ces filtres" : "No results for these filters"),
                                       systemImage: events.isEmpty ? "clock.arrow.circlepath" : "line.3.horizontal.decrease.circle")
            }
            else {
                List {
                    ForEach(groups, id: \.day) { group in
                        Section(group.day.formatted(.dateTime.year().month().day().locale(Locale(identifier: french ? "fr_FR" : "en_US")))) {
                            ForEach(group.events, id: \.id) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(copy("activity.\(event.kind.rawValue)"),
                                          systemImage: event.kind == .failed ? "exclamationmark.circle" : "circle.inset.filled")
                                            .font(CoreTendTypography.body.weight(.semibold))
                                            .foregroundStyle(Palette.ink.color)
                                    Text(ProductCopy.activityDetail(event.detail, failureCode: event.kind == .failed ? event.failureCode : nil, french: french))
                                        .font(CoreTendTypography.body)
                                        .foregroundStyle(Palette.secondaryInk.color)
                                        .textSelection(.enabled)
                                    Text(event.occurredAt.formatted(.dateTime.hour().minute()))
                                        .font(CoreTendTypography.secondary.monospacedDigit())
                                        .foregroundStyle(Palette.secondaryInk.color)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
        }
        .motion(.quick, value: selectedKind)
        .motion(.quick, value: selectedRange)
        .task { await load() }
        .alert(copy("record.clear.title"), isPresented: $confirmClear) {
            Button(copy("common.cancel"), role: .cancel) {}
                .keyboardShortcut(.defaultAction)
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
                let visible = search(current)
                let data = json ? try ActivityExport.json(visible) : Data(ActivityExport.csv(visible).utf8)
                let type: UTType = json ? .json : .commaSeparatedText
                exportDocument = ActivityExportDocument(data: data, contentType: type)
                exportName = json ? "coretend-activity.json" : "coretend-activity.csv"
                isExporting = true
            } catch { errorMessage = copy("record.error") }
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }

    private func search(_ events: [ActivityEvent]) -> [ActivityEvent] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return events }
        return events.filter { event in
            copy("activity.\(event.kind.rawValue)").localizedStandardContains(term) ||
            ProductCopy.activityDetail(event.detail, failureCode: event.kind == .failed ? event.failureCode : nil, french: french)
                .localizedStandardContains(term)
        }
    }
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
