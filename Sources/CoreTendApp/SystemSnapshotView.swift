import DesignSystem
import SwiftUI
import Domain
import ProductContract
import AppShell
import Persistence
import Charts

struct SystemSnapshotView: View {
    let destination: Destination
    let french: Bool
    @Environment(CoreTendNavigation.self) private var navigation
    @State private var snapshot: SystemSnapshot?
    @State private var loading = false
    @State private var history: [PerformanceSample] = []
    @State private var selectedHistoryDate: Date?
    @State private var historyError = false
    @State private var clearingHistory = false
    @State private var confirmClearHistory = false
    @State private var historyNotice: String?
    @State private var latestActivity: ActivitySummary?
    /// The last few events with their object, for the Overview.
    @State private var recentEvents: [ActivityEvent] = []
    @State private var activityUnavailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(copy("menubar.metrics.title"))
                    .font(CoreTendTypography.sectionTitle)
                    .foregroundStyle(Palette.ink.color)
                Spacer()
                if destination == .performance, let snapshot {
                    Text("\(copy("metrics.measured")) \(timestamp(snapshot.measuredAt))")
                        .font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
                }
                Button { refresh() } label: { Label(copy("metrics.refresh"), systemImage: "arrow.clockwise") }
                    .buttonStyle(.serre(.secondary))
                    .disabled(loading || clearingHistory)
            }
            .serreRise(1)
            if (loading || clearingHistory) && snapshot == nil {
                Text(copy("metrics.refresh")).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            }
            if let snapshot {
                if destination == .overview {
                    GreenhouseScene(state: greenhouseState(snapshot)).serreRise(1)
                    // Side by side when the window is wide enough, stacked otherwise.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            storage(snapshot).frame(minWidth: 560)
                            recentActivity.frame(width: 320)
                        }
                        VStack(alignment: .leading, spacing: 20) {
                            storage(snapshot)
                            recentActivity
                        }
                    }
                    .serreRise(2)
                    nextSteps.serreRise(4)
                }
                else {
                    performance(snapshot)
                    performanceHistory
                }
                Text(copy("metrics.scope"))
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .serreRise(5)
            } else if !loading {
                SerreBanner(.error, title: copy("metrics.unavailable"), message: copy("metrics.source.volume")) {
                    Button(copy("metrics.refresh")) { refresh() }.padding(.top, 6)
                }
            }
        }
        .motion(.standard, value: snapshot?.measuredAt)
        .task { refresh() }
        .alert(copy("metrics.clear.title"), isPresented: $confirmClearHistory) {
            Button(copy("common.cancel"), role: .cancel) {}
                .keyboardShortcut(.defaultAction)
            Button(copy("metrics.clear.confirm"), role: .destructive) {
                clearingHistory = true
                Task { await clearPerformanceHistory() }
            }
        } message: { Text(copy("metrics.clear.message")) }
    }

    /// The state of the greenhouse: free space as the hero figure over a soil band of what was measured.
    @ViewBuilder private func storage(_ value: SystemSnapshot) -> some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 10) {
                Text(copy("metrics.freeSpace")).font(CoreTendTypography.sectionTitle)
                    .foregroundStyle(Palette.secondaryInk.color)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(format(value.availableBytes)).font(CoreTendTypography.hero)
                        .foregroundStyle(Palette.ink.color)
                        .contentTransition(.numericText())
                        .motion(.standard, value: value.availableBytes)
                    Text(copy("metrics.available")).font(CoreTendTypography.secondary)
                        .foregroundStyle(Palette.secondaryInk.color)
                }
                if case .known(let free) = value.availableBytes, case .known(let total) = value.totalBytes,
                   let soil = SoilFractions(free: free, total: total) {
                    SoilBand(used: soil.used, free: soil.free)
                    HStack(spacing: 14) {
                        legend(copy("metrics.used"), ProductFormat.bytes(total - free, french: french), tone: Palette.strongSeparator.color)
                        legend(copy("metrics.free.short"), ProductFormat.bytes(free, french: french), tone: Palette.accent.color)
                        Spacer(minLength: 0)
                        Text("\(copy("metrics.volumeTotal")) \(ProductFormat.bytes(total, french: french))")
                            .font(CoreTendTypography.secondary.monospacedDigit()).foregroundStyle(Palette.secondaryInk.color)
                    }
                } else {
                    Text(copy("metrics.volumeTotal") + " " + format(value.totalBytes))
                        .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                }
                Text(copy("metrics.trashNote")).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                measurementSource(copy("metrics.source.volume"), at: value.measuredAt)
            }
        }
    }

    /// The scene reflects measurements only: free ground, last action failed, recent pruning.
    private func greenhouseState(_ value: SystemSnapshot) -> GreenhouseState {
        var free: Double?
        if case .known(let f) = value.availableBytes, case .known(let total) = value.totalBytes,
           let soil = SoilFractions(free: f, total: total) { free = soil.free }
        let day: TimeInterval = 86_400
        return GreenhouseState(freeFraction: free,
                               lastActionFailed: recentEvents.first?.kind == .failed,
                               recentlyPruned: recentEvents.contains { $0.kind == .movedToTrash && $0.occurredAt > .now - day })
    }

    @ViewBuilder private func eventLeaf(_ kind: ActivityKind) -> some View {
        switch kind {
        case .movedToTrash, .migrationImported: RiskLeaf(.low, size: 12)
        case .failed: RiskLeaf(.high, size: 12)
        default: RiskLeafShape(level: .low).stroke(Palette.secondaryInk.color, lineWidth: 1.2)
        }
    }

    private func legend(_ title: String, _ value: String, tone: Color) -> some View {
        HStack(spacing: 6) {
            LeafCorner.control.shape.fill(tone).frame(width: 12, height: 10)
            Text("\(title) \(value)").font(CoreTendTypography.secondary.monospacedDigit()).foregroundStyle(Palette.ink.color)
        }
        .accessibilityElement(children: .combine)
    }

    /// The herbarium's latest page.
    private var recentActivity: some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 8) {
                Label { Text(copy("menubar.activity.title")) } icon: { SerreIcon(.record, size: 16).foregroundStyle(Palette.accent.color) }
                    .font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.secondaryInk.color)
                if activityUnavailable {
                    SerreBanner(.partial, title: copy("menubar.activity.unavailable"))
                } else if !recentEvents.isEmpty {
                    ForEach(recentEvents, id: \.id) { event in
                        HStack(alignment: .top, spacing: 10) {
                            eventLeaf(event.kind).frame(width: 12, height: 12).padding(.top, 3)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(copy("activity.\(event.kind.rawValue)"))
                                    .font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                                // What it was about, and why it failed when it did.
                                Text(ProductCopy.activityDetail(event.detail, failureCode: event.kind == .failed ? event.failureCode : nil, french: french))
                                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                                    .lineLimit(2).truncationMode(.middle)
                                Text(timestamp(event.occurredAt))
                                    .font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
                            }
                        }
                    }
                } else {
                    Text(copy("menubar.activity.empty"))
                        .font(CoreTendTypography.body).foregroundStyle(Palette.secondaryInk.color)
                }
            }
        }
    }

    /// Where to go from here: two paths into the greenhouse.
    private var nextSteps: some View {
        HStack(alignment: .top, spacing: 14) {
            path(.explore, title: copy("overview.next.explore"), help: copy("overview.next.explore.help"))
            path(.record, title: copy("overview.next.record"), help: copy("overview.next.record.help"))
        }
    }

    private func path(_ target: Destination, title: String, help: String) -> some View {
        Button { navigation.selection = target } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label { Text(title) } icon: { SerreIcon(target.glyph, size: 18).foregroundStyle(Palette.accent.color) }
                    .font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                Text(help).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface.color, in: LeafCorner.parcel.shape)
            .overlay(LeafCorner.parcel.shape.strokeBorder(Palette.separator.color, lineWidth: 1))
        }
        .buttonStyle(.serre(.tile))
    }

    private func measurementSource(_ source: String, at date: Date) -> some View {
        Text("\(source) · \(copy("metrics.measured")) \(timestamp(date))")
            .font(CoreTendTypography.secondary)
            .foregroundStyle(Palette.secondaryInk.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func timestamp(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().hour().minute().locale(Locale(identifier: french ? "fr_FR" : "en_US")))
    }

    /// The measurements of now, one parcel each, figures in Iowan.
    private func performance(_ value: SystemSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], alignment: .leading, spacing: 14) {
            metric(copy("metrics.loadAverage"), load(value.loadAverage1m), source: copy("metrics.source.load"), at: value.measuredAt, order: 2)
            metric(copy("metrics.processors"), "\(value.activeProcessorCount)", source: copy("metrics.source.processors"), at: value.measuredAt, order: 3)
            metric(copy("metrics.memory"), ProductFormat.memory(value.physicalMemoryBytes, french: french), source: copy("metrics.source.memory"), at: value.measuredAt, order: 4)
            metric(copy("metrics.uptime"), uptime(value.uptimeSeconds), source: copy("metrics.source.uptime"), at: value.measuredAt, order: 5)
            metric(copy("metrics.thermal"), thermal(value.thermalState), source: copy("metrics.source.thermal"), at: value.measuredAt, order: 6,
                   tone: thermalTone(value.thermalState))
            metric(copy("metrics.freeSpace"), format(value.availableBytes), source: copy("metrics.source.volume"), at: value.measuredAt, order: 7)
        }
    }

    /// The sap: the 1-minute load, reading by reading. The curve is traced from left to right when
    /// it appears, and the newest reading pulses once; nothing moves at rest.
    private var performanceHistory: some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(copy("metrics.sap")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(copy("metrics.clear")) { confirmClearHistory = true }
                        .buttonStyle(.serre(.icon))
                        .disabled(history.isEmpty || loading || clearingHistory)
                }
                Text(copy("metrics.historyHelp"))
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let historyNotice {
                    SerreBanner(.note, title: historyNotice)
                }
                if historyError {
                    SerreBanner(.error, title: copy("metrics.historyError"))
                }
                let known = history.filter { $0.loadAverage1m != nil }
                if known.isEmpty {
                    SerreEmptyState(title: copy("metrics.historyEmpty"), message: copy("metrics.source.load"))
                } else {
                    sapChart(known)
                    if let selectedHistoryDate,
                       let selected = PerformanceHistorySelection.nearestKnownSample(to: selectedHistoryDate, in: known),
                       let load = selected.loadAverage1m {
                        Text("\(copy("metrics.loadAverage")) : \(load.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: french ? "fr_FR" : "en_US")))) · \(timestamp(selected.measuredAt))")
                            .font(CoreTendTypography.secondary.monospacedDigit()).foregroundStyle(Palette.ink.color)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy("metrics.latest")).font(CoreTendTypography.caption.weight(.semibold)).foregroundStyle(Palette.secondaryInk.color)
                        ForEach(known.suffix(5).reversed()) { sample in
                            if let load = sample.loadAverage1m {
                                Text("\(timestamp(sample.measuredAt)) · \(load.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: french ? "fr_FR" : "en_US"))))")
                                    .font(CoreTendTypography.caption.monospacedDigit()).foregroundStyle(Palette.secondaryInk.color)
                            }
                        }
                    }
                }
            }
        }
        .serreRise(8)
    }

    private func sapChart(_ known: [PerformanceSample]) -> some View {
        let latest = known.last
        return Chart(known) { sample in
            if let load = sample.loadAverage1m {
                AreaMark(x: .value("Time", sample.measuredAt), y: .value(copy("metrics.loadAverage"), load))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Palette.accent.color.opacity(0.28), Palette.accent.color.opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Time", sample.measuredAt), y: .value(copy("metrics.loadAverage"), load))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .foregroundStyle(Palette.accent.color)
                PointMark(x: .value("Time", sample.measuredAt), y: .value(copy("metrics.loadAverage"), load))
                    .symbolSize(sample.id == latest?.id ? 60 : 18)
                    .foregroundStyle(Palette.accent.color)
            }
            if let selectedHistoryDate,
               let selected = PerformanceHistorySelection.nearestKnownSample(to: selectedHistoryDate, in: known) {
                RuleMark(x: .value("Time", selected.measuredAt))
                    .foregroundStyle(Palette.strongSeparator.color)
            }
        }
        .chartXSelection(value: $selectedHistoryDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Palette.separator.color)
                AxisValueLabel(format: .dateTime.day().month().hour().minute().locale(Locale(identifier: french ? "fr_FR" : "en_US")))
                    .foregroundStyle(Palette.secondaryInk.color)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Palette.separator.color)
                AxisValueLabel().foregroundStyle(Palette.secondaryInk.color)
            }
        }
        .chartOverlay { proxy in
            // The newest reading pulses once; a new reading brings a new pulse.
            if let latest, let load = latest.loadAverage1m,
               let point = proxy.position(for: (x: latest.measuredAt, y: load)) {
                OncePulse()
                    .position(point)
                    .id(latest.id)
            }
        }
        .padding(.vertical, 8)
        .traceReveal()
        .frame(height: 200)
        .accessibilityLabel(copy("metrics.history"))
    }

    private func metric(_ title: String, _ value: String, source: String, at date: Date, order: Int,
                        tone: SerreSignalTone? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let tone { toneLeaf(tone) }
                Text(title).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            }
            Text(value).font(CoreTendTypography.figure).foregroundStyle(Palette.ink.color)
                .contentTransition(.numericText())
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(source).font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: LeafCorner.parcel.shape)
        .overlay(LeafCorner.parcel.shape.strokeBorder(Palette.separator.color, lineWidth: 1))
        .serreRise(order)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value). \(source). \(copy("metrics.measured")) \(timestamp(date))")
    }

    @ViewBuilder private func toneLeaf(_ tone: SerreSignalTone) -> some View {
        switch tone {
        case .good: RiskLeaf(.low, size: 11)
        case .caution: RiskLeaf(.medium, size: 11)
        case .bad: RiskLeaf(.high, size: 11)
        case .neutral: RiskLeafShape(level: .low).stroke(Palette.secondaryInk.color, lineWidth: 1.2).frame(width: 11, height: 11)
        }
    }

    private func thermalTone(_ state: Domain.ThermalState) -> SerreSignalTone {
        switch state {
        case .nominal: .good
        case .fair: .neutral
        case .serious: .caution
        case .critical: .bad
        case .unknown: .neutral
        }
    }

    private func format(_ value: ProductMeasurement<Int64>) -> String {
        switch value {
        case .known(let bytes): ProductFormat.bytes(bytes, french: french)
        case .unknown: copy("metrics.unknown")
        }
    }

    private func uptime(_ seconds: TimeInterval) -> String {
        let hours = max(0, Int(seconds / 3600))
        let days = hours / 24
        let remainder = hours % 24
        return french ? "\(days) j \(remainder) h" : "\(days)d \(remainder)h"
    }

    private func load(_ value: ProductMeasurement<Double>) -> String {
        switch value {
        case .known(let number): number.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: french ? "fr_FR" : "en_US")))
        case .unknown: copy("metrics.unknown")
        }
    }

    private func thermal(_ state: Domain.ThermalState) -> String {
        copy("thermal.\(state.rawValue)")
    }

    private func refresh() {
        loading = true
        historyNotice = nil
        Task {
            let service = SystemSnapshotService()
            let newSnapshot = await Task.detached(priority: .utility) { service.snapshot() }.value
            snapshot = newSnapshot
            if destination == .performance {
                do {
                    let store = try await LocalStoreAccess.open()
                    try await store.appendPerformanceSample(newSnapshot.performanceSample)
                    history = try await store.performanceSamples()
                    selectedHistoryDate = nil
                    historyError = false
                } catch { historyError = true }
            } else {
                do {
                    let store = try await LocalStoreAccess.open()
                    latestActivity = try await store.latestActivity()
                    recentEvents = Array(try await store.events().sorted { $0.occurredAt > $1.occurredAt }.prefix(3))
                    activityUnavailable = false
                } catch {
                    latestActivity = nil
                    activityUnavailable = true
                }
            }
            loading = false
        }
    }

    @MainActor private func clearPerformanceHistory() async {
        defer { clearingHistory = false }
        do {
            let store = try await LocalStoreAccess.open()
            try await store.clearPerformanceHistory()
            history = []
            selectedHistoryDate = nil
            historyError = false
            historyNotice = copy("metrics.clear.done")
        } catch {
            historyError = true
            historyNotice = nil
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
