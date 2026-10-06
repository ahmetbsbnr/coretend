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
    /// Changes per load, so entries are pressed in once per load, not on every filter change.
    @State private var pressSeed = UUID()

    private var filtered: [ActivityEvent] {
        search(ActivityHistoryGrouping.filteredEvents(events, kind: ActivityKind(rawValue: selectedKind), range: selectedRange))
    }
    private var groups: [ActivityDayGroup] {
        ActivityHistoryGrouping.groups(filtered)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SerreBanner(.note, title: copy("record.localNotice"))
            tools
            if loading && events.isEmpty {
                Text(french ? "Chargement de l’historique…" : "Loading history…")
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            }
            if let message = errorMessage {
                SerreBanner(.error, title: message) {
                    Button(copy("record.retry")) { errorMessage = nil; Task { await load() } }
                        .buttonStyle(.serre(.secondary)).padding(.top, 6)
                }
            } else if filtered.isEmpty && !loading {
                if events.isEmpty {
                    SerreEmptyState(title: copy("record.empty"), message: copy("record.empty.help"))
                } else {
                    SerreEmptyState(title: copy("record.noResults"), message: copy("record.noResults.help"))
                }
            } else {
                // One herbarium page per day; entries are pressed in when the pages appear.
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(groups.enumerated()), id: \.element.day) { pageIndex, group in
                        page(group, first: pageIndex * 6)
                    }
                }
                .id(pressSeed)
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

    private var tools: some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    SerreIcon(.search, size: 15).foregroundStyle(Palette.accent.color).accessibilityHidden(true)
                    TextField(copy("record.search"), text: $query)
                        .textFieldStyle(.plain).font(CoreTendTypography.body)
                        .accessibilityLabel(copy("record.search"))
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Palette.raisedSurface.color, in: LeafCorner.control.shape)
                .overlay(LeafCorner.control.shape.strokeBorder(query.isEmpty ? Palette.strongSeparator.color : Palette.accent.color, lineWidth: 1))
                HStack(spacing: 12) {
                    Picker(copy("record.filter"), selection: $selectedKind) {
                        Text(copy("record.all")).tag("all")
                        ForEach(ActivityKind.allCases, id: \.rawValue) { kind in
                            Text(copy("activity.\(kind.rawValue)")).tag(kind.rawValue)
                        }
                    }
                    Picker(copy("record.range"), selection: $selectedRange) {
                        Text(copy("record.range.all")).tag(ActivityDateRange.all)
                        Text(copy("record.range.last7")).tag(ActivityDateRange.last7Days)
                        Text(copy("record.range.last30")).tag(ActivityDateRange.last30Days)
                    }
                }
                .pickerStyle(.menu)
                .font(CoreTendTypography.secondary)
                .tint(Palette.accent.color)
                HStack(spacing: 12) {
                    let count = filtered.count
                    Text(french ? "\(ProductFormat.count(count, french: true)) événement\(ProductFormat.frenchPlural(count))"
                                : "\(ProductFormat.count(count, french: false)) event\(count == 1 ? "" : "s")")
                        .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                        .contentTransition(.numericText(value: Double(count)))
                    Spacer()
                    Menu {
                        Button(copy("record.export.json")) { prepareExport(json: true) }
                        Button(copy("record.export.csv")) { prepareExport(json: false) }
                    } label: {
                        Label(copy("record.export"), systemImage: "square.and.arrow.up")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.serre(.secondary))
                    .fixedSize()
                    .disabled(store == nil || loading)
                    Button(copy("record.clear")) { confirmClear = true }
                        .buttonStyle(.serre(.icon))
                        .disabled(store == nil || loading || events.isEmpty)
                }
            }
        }
    }

    /// A herbarium page: the day in Iowan, then its entries pressed in, newest first.
    private func page(_ group: ActivityDayGroup, first: Int) -> some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 10) {
                Text(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Locale(identifier: french ? "fr_FR" : "en_US"))))
                    .font(.custom("IowanOldStyle-Roman", size: 20, relativeTo: .title3))
                    .foregroundStyle(Palette.ink.color)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
                    entry(event).serrePress(first + index)
                }
            }
        }
    }

    private func entry(_ event: ActivityEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            marker(event.kind).frame(width: 14, height: 14).padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(copy("activity.\(event.kind.rawValue)"))
                    .font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                Text(ProductCopy.activityDetail(event.detail, failureCode: event.kind == .failed ? event.failureCode : nil, french: french))
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .lineLimit(2).truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            Text(event.occurredAt.formatted(.dateTime.hour().minute().locale(Locale(identifier: french ? "fr_FR" : "en_US"))))
                .font(CoreTendTypography.caption.monospacedDigit()).foregroundStyle(Palette.tertiaryInk.color)
        }
        .accessibilityElement(children: .combine)
    }

    /// What happened, as a leaf: moved and imported in green, failed split, the rest outlined.
    @ViewBuilder private func marker(_ kind: ActivityKind) -> some View {
        switch kind {
        case .movedToTrash, .migrationImported, .restoredFromTrash: RiskLeaf(.low, size: 14)
        case .failed: RiskLeaf(.high, size: 14)
        case .proposed, .approved:
            RiskLeafShape(level: .low).stroke(Palette.accent.color, lineWidth: 1.3).accessibilityHidden(true)
        case .refused, .cancelled:
            RiskLeafShape(level: .low).stroke(Palette.secondaryInk.color, lineWidth: 1.3).accessibilityHidden(true)
        }
    }

    @MainActor private func load() async {
        loading = true
        defer { loading = false }
        do {
            let localStore = try await LocalStoreAccess.open()
            store = localStore
            events = try await localStore.events()
            pressSeed = UUID()
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
