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
    @State private var snapshot: SystemSnapshot?
    @State private var loading = false
    @State private var history: [PerformanceSample] = []
    @State private var selectedHistoryDate: Date?
    @State private var historyError = false
    @State private var clearingHistory = false
    @State private var confirmClearHistory = false
    @State private var historyNotice: String?
    @State private var latestActivity: ActivitySummary?
    @State private var activityUnavailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(copy("menubar.metrics.title"))
                    .font(CoreTendTypography.sectionTitle)
                    .foregroundStyle(Palette.ink.color)
                Spacer()
                Button { refresh() } label: { Label(copy("metrics.refresh"), systemImage: "arrow.clockwise") }
                    .disabled(loading || clearingHistory)
            }
            if loading || clearingHistory { ProgressView(copy("metrics.refresh")) }
            if let snapshot {
                if destination == .overview {
                    storage(snapshot)
                    recentActivity
                    Label(french
                          ? "Pour examiner les fichiers, choisissez un dossier dans Explorer. Pour revoir les actions, ouvrez Historique."
                          : "To inspect files, choose a folder in Explore. To review actions, open Record.",
                          systemImage: "arrow.right.circle")
                        .font(CoreTendTypography.secondary)
                        .foregroundStyle(Palette.secondaryInk.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                else {
                    performance(snapshot)
                    performanceHistory
                }
                Text(copy("metrics.scope"))
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            } else if !loading {
                ContentUnavailableView(copy("metrics.unavailable"), systemImage: "gauge.with.dots.needle.67percent",
                                       description: Text(copy("metrics.source.volume")))
            }
        }
        .motion(.standard, value: snapshot?.measuredAt)
        .task { refresh() }
        .alert(copy("metrics.clear.title"), isPresented: $confirmClearHistory) {
            Button(copy("common.cancel"), role: .cancel) {}
            Button(copy("metrics.clear.confirm"), role: .destructive) {
                clearingHistory = true
                Task { await clearPerformanceHistory() }
            }
        } message: { Text(copy("metrics.clear.message")) }
    }

    @ViewBuilder private func storage(_ value: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(copy("metrics.freeSpace")).font(CoreTendTypography.sectionTitle)
                .foregroundStyle(Palette.ink.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(format(value.availableBytes)).font(CoreTendTypography.measurement)
                    .contentTransition(.numericText())
                    .motion(.standard, value: value.availableBytes)
                Text(copy("metrics.available")).font(CoreTendTypography.secondary)
                    .foregroundStyle(Palette.secondaryInk.color)
            }
            if case .known(let free) = value.availableBytes,
               case .known(let total) = value.totalBytes, total > 0, free >= 0, free <= total {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.separator.color)
                        Capsule().fill(Palette.accent.color)
                            .frame(width: geometry.size.width * CGFloat(free) / CGFloat(total))
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)
                Text("\(copy("metrics.freeSpace")): \(format(value.availableBytes)) · \(copy("metrics.volumeTotal")): \(format(value.totalBytes))")
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            } else {
                Text(copy("metrics.volumeTotal") + " " + format(value.totalBytes))
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            }
            Text(copy("metrics.trashNote")).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            measurementSource(copy("metrics.source.volume"), at: value.measuredAt)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 16))
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy("menubar.activity.title"))
                .font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
            if activityUnavailable {
                Label(copy("menubar.activity.unavailable"), systemImage: "exclamationmark.circle")
                    .foregroundStyle(Palette.caution.color)
            } else if let latestActivity {
                Label(copy("activity.\(latestActivity.kind.rawValue)"), systemImage: "clock.arrow.circlepath")
                    .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                Text(timestamp(latestActivity.occurredAt))
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            } else {
                Text(copy("menubar.activity.empty"))
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 16))
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

    private func performance(_ value: SystemSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 16)], alignment: .leading, spacing: 16) {
            metric(copy("metrics.loadAverage"), load(value.loadAverage1m), source: copy("metrics.source.load"), at: value.measuredAt)
            metric(copy("metrics.processors"), "\(value.activeProcessorCount)", source: copy("metrics.source.processors"), at: value.measuredAt)
            metric(copy("metrics.memory"), ByteCountFormatter.string(fromByteCount: value.physicalMemoryBytes, countStyle: .memory), source: copy("metrics.source.memory"), at: value.measuredAt)
            metric(copy("metrics.uptime"), uptime(value.uptimeSeconds), source: copy("metrics.source.uptime"), at: value.measuredAt)
            metric(copy("metrics.thermal"), thermal(value.thermalState), source: copy("metrics.source.thermal"), at: value.measuredAt)
            metric(copy("metrics.freeSpace"), format(value.availableBytes), source: copy("metrics.source.volume"), at: value.measuredAt)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 16))
    }

    private var performanceHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy("metrics.history")).font(CoreTendTypography.sectionTitle)
                .foregroundStyle(Palette.ink.color)
            Text(copy("metrics.historyHelp"))
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            Button(copy("metrics.clear"), role: .destructive) { confirmClearHistory = true }
                .disabled(history.isEmpty || loading || clearingHistory)
            if let historyNotice {
                Text(historyNotice).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            }
            if historyError {
                Label(copy("metrics.historyError"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Palette.caution.color)
            }
            let known = history.filter { $0.loadAverage1m != nil }
            if known.isEmpty {
                Text(copy("metrics.historyEmpty"))
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            } else {
                if let latest = known.last, let load = latest.loadAverage1m {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(load.formatted(.number.precision(.fractionLength(2))))
                            .font(CoreTendTypography.measurement)
                        measurementSource(copy("metrics.source.load"), at: latest.measuredAt)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(copy("metrics.loadAverage")): \(load.formatted(.number.precision(.fractionLength(2)))), \(latest.measuredAt.formatted(.dateTime.day().month().hour().minute().locale(Locale(identifier: french ? "fr_FR" : "en_US"))))")
                }
                Chart(known) { sample in
                    if let load = sample.loadAverage1m {
                        PointMark(x: .value("Time", sample.measuredAt), y: .value(copy("metrics.loadAverage"), load))
                            .symbolSize(44)
                            .foregroundStyle(Palette.accent.color)
                    }
                    if let selectedHistoryDate,
                       let selected = PerformanceHistorySelection.nearestKnownSample(to: selectedHistoryDate, in: known) {
                        RuleMark(x: .value("Time", selected.measuredAt))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .annotation(position: .top, alignment: .leading) {
                                if let load = selected.loadAverage1m {
                                    Text(load.formatted(.number.precision(.fractionLength(2))))
                                        .font(CoreTendTypography.secondary.monospacedDigit().weight(.semibold))
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        .background(.regularMaterial, in: Capsule())
                                }
                            }
                    }
                }
                .chartXSelection(value: $selectedHistoryDate)
                .chartYAxisLabel(copy("metrics.loadAverage"))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(.quaternary)
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month().hour())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(.quaternary)
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartPlotStyle { plot in
                    plot.background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 170)
                .accessibilityLabel(copy("metrics.history"))
                if let selectedHistoryDate,
                   let selected = PerformanceHistorySelection.nearestKnownSample(to: selectedHistoryDate, in: known),
                   let load = selected.loadAverage1m {
                    Text("\(copy("metrics.loadAverage")): \(load.formatted(.number.precision(.fractionLength(2)))) · \(selected.measuredAt.formatted(.dateTime.day().month().hour().minute().locale(Locale(identifier: french ? "fr_FR" : "en_US"))))")
                        .font(CoreTendTypography.secondary.monospacedDigit())
                        .accessibilityAddTraits(.updatesFrequently)
                }
                ForEach(known.suffix(5)) { sample in
                    if let load = sample.loadAverage1m {
                        Text("\(sample.measuredAt.formatted(.dateTime.day().month().hour().minute())) · \(load.formatted(.number.precision(.fractionLength(2))))")
                            .font(CoreTendTypography.secondary.monospacedDigit())
                    }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String, source: String, at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
            Text(value).font(CoreTendTypography.measurement).foregroundStyle(Palette.ink.color)
            measurementSource(source, at: date)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.raisedSurface.color, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value). \(source). \(copy("metrics.measured")) \(timestamp(date))")
    }

    private func format(_ value: ProductMeasurement<Int64>) -> String {
        switch value {
        case .known(let bytes): ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
        case .known(let number): number.formatted(.number.precision(.fractionLength(2)))
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
