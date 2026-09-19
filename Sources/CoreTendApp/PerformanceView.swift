// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import Charts
import SystemMetrics
import Persistence
import DesignSystem

@MainActor
@Observable
final class PerformanceViewModel {
    var snapshot: MetricsSnapshot?
    /// One point every two seconds, the last two minutes. Newest last.
    struct Sample: Identifiable {
        let date: Date
        let cpu: Double
        let memory: Double
        var id: Date { date }
    }
    var samples: [Sample] = []
    private var firstSnapshotSeen = false
    var history: [Double] { samples.map(\.cpu) }

    /// What CoreTend has recorded over weeks, not seconds.
    struct ScanPoint: Identifiable {
        let id: Int64
        let date: Date
        let bytes: Int64
        let items: Int
        let kind: ActivityRecord.Kind
    }
    var scanHistory: [ScanPoint] = []

    /// Loaded from the store rather than sampled: this is history CoreTend
    /// already owns, and plotting it costs nothing at runtime.
    func loadHistory() async {
        guard let store = AppEnvironment.shared.store else { return }
        let records = (try? await store.activity(limit: 400)) ?? []
        scanHistory = records
            .filter { $0.kind == .scan && $0.bytes > 0 }
            .map { ScanPoint(id: $0.id, date: $0.date, bytes: $0.bytes,
                             items: $0.itemCount, kind: $0.kind) }
            .sorted { $0.date < $1.date }
    }
    private let collector = MetricsCollector()
    private var timerTask: Task<Void, Never>?

    func start() {
        guard timerTask == nil else { return }
        timerTask = Task {
            while !Task.isCancelled {
                let snap = await collector.snapshot()
                snapshot = snap
                // The first snapshot has no interval to measure CPU over, so
                // its 0% is a reading of nothing; it is not kept as a sample.
                if firstSnapshotSeen {
                    samples.append(Sample(date: snap.date, cpu: snap.cpuUsedFraction, memory: snap.memoryUsedFraction))
                }
                firstSnapshotSeen = true
                if samples.count > 60 { samples.removeFirst(samples.count - 60) }
                if samples.count == 2 { CaptureHarness.note(state: "charting") }
                // Dense at first, then settle. A two-second interval meant the
                // curves were empty for the first four seconds every single
                // time this screen was opened — the state a capture caught,
                // and the state a person sees too.
                try? await Task.sleep(for: .seconds(samples.count < 12 ? 0.35 : 2))
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }
}

/// One user LaunchAgent with validity check (does its program still exist?).
struct LaunchAgentInfo: Identifiable {
    let id: String
    let label: String
    let programPath: String?
    let broken: Bool
}

enum LaunchAgentInspector {
    static func userAgents() -> [LaunchAgentInfo] {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "plist" }.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            else {
                return LaunchAgentInfo(id: url.path, label: url.lastPathComponent, programPath: nil, broken: true)
            }
            let program = plist["Program"] as? String
                ?? (plist["ProgramArguments"] as? [String])?.first
            let broken = program.map { !FileManager.default.fileExists(atPath: $0) } ?? false
            return LaunchAgentInfo(
                id: url.path,
                label: plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent,
                programPath: program,
                broken: broken)
        }
        .sorted { ($0.broken ? 0 : 1, $0.label) < ($1.broken ? 0 : 1, $1.label) }
    }
}

/// How far back the recorded-scan section looks.
///
/// Not a filter over a fixed picture: the x scale is pinned to the window, so
/// "30 days" is thirty days of calendar even where no scan was run. A chart
/// that silently closes its gaps answers a different question than the one
/// the control asks.
enum ScanHistoryRange: String, CaseIterable, Identifiable {
    case month
    case quarter
    case all
    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .month: return 30
        case .quarter: return 90
        case .all: return nil
        }
    }

    var label: String {
        switch self {
        case .month: return L("performance.history.range.month")
        case .quarter: return L("performance.history.range.quarter")
        case .all: return L("performance.history.range.all")
        }
    }
}

struct PerformanceView: View {
    @State private var model = PerformanceViewModel()
    @State private var range: ScanHistoryRange = .month
    /// One hovered instant shared by both live curves, so reading CPU at a
    /// moment also reads memory at that same moment. Two independent hovers
    /// would let the screen show two different times at once.
    @State private var liveHover: Date?
    @State private var scanHover: PerformanceViewModel.ScanPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Performance is about time. The screen is the current values in one
    /// line, then two curves over the last two minutes with a real time axis,
    /// then the long view: what every recorded scan found, and over how many
    /// items.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                if let snap = model.snapshot {
                    currentLine(snap)
                    Divider()
                    liveSection(snap)
                    Divider()
                    scanHistorySection
                } else {
                    Text(L("performance.collecting_samples"))
                        .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(L("performance.nav_title"))
        .task { await model.loadHistory() }
        .onReceive(NotificationCenter.default.publisher(for: .mcFixtureSeeded)) { _ in
            Task { await model.loadHistory() }
        }
        .onAppear { if scenePhase == .active { model.start() } }
        .onDisappear { model.stop() }
        // Idle-window behavior: stop sampling while the app is hidden/backgrounded
        // (window occluded, minimized, or app not frontmost) so no timer runs unseen.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.start() } else { model.stop() }
        }
    }

    // MARK: - Live

    /// The sample the pointer is over, or the newest one when it is not over
    /// the chart. Everything downstream reads this, so the readouts and the
    /// rule can never disagree about which instant is being shown.
    private var focusedSample: PerformanceViewModel.Sample? {
        guard let hover = liveHover else { return model.samples.last }
        return model.samples.min { a, b in
            abs(a.date.timeIntervalSince(hover)) < abs(b.date.timeIntervalSince(hover))
        }
    }

    @ViewBuilder
    private func liveSection(_ snap: MetricsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: MCSpacing.sm) {
                Text(L("performance.live.title")).font(MCFont.sectionTitle)
                Spacer(minLength: MCSpacing.sm)
                // Says *when* the readouts on the right refer to. Without it
                // a hovered value is indistinguishable from the live one.
                Text(liveHover == nil
                     ? L("performance.live.now")
                     : AppDateFormatting.string(focusedSample?.date ?? snap.date, style: .timeOnly))
                    .font(MCFont.micro).monospacedDigit()
                    .foregroundStyle(liveHover == nil ? MCColor.textTertiary : MCColor.textSecondary)
            }
            chart(L("performance.cpu"), keyPath: \.cpu, color: MCColor.teal,
                  readout: { "\(Int($0 * 100))%" },
                  liveDetail: "\(Int(snap.cpuUsedFraction * 100))%")
            chart(L("performance.memory"), keyPath: \.memory, color: MCColor.graphite,
                  readout: { fraction in
                      let used = Double(snap.memoryTotalBytes) * fraction
                      return "\(Int(fraction * 100))% · \(mcFormatBytes(Int64(used)))"
                  },
                  liveDetail: L("performance.memory_detail",
                                mcFormatBytes(snap.memoryUsedBytes),
                                mcFormatBytes(snap.memoryTotalBytes)))
        }
    }

    private func currentLine(_ snap: MetricsSnapshot) -> some View {
        HStack(spacing: MCSpacing.lg) {
            // The first sample has no interval to measure CPU over; 0% there
            // would be a reading of nothing. Say so until the second sample.
            fact(L("performance.cpu"), model.samples.isEmpty ? "—" : "\(Int(snap.cpuUsedFraction * 100))%")
            fact(L("performance.memory"), "\(Int(snap.memoryUsedFraction * 100))%")
            fact(L("performance.memory_pressure"), snap.memoryPressureLevel.capitalized)
            fact(L("performance.thermal_state"), snap.thermalState.capitalized)
            fact(L("performance.uptime"), formatUptime(snap.uptimeSeconds))
            Spacer(minLength: 0)
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(MCFont.groupHeader).foregroundStyle(MCColor.textSecondary).textCase(.uppercase)
            Text(value).font(MCFont.metric).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    @ViewBuilder
    private func chart(_ title: String, keyPath: KeyPath<PerformanceViewModel.Sample, Double>,
                       color: Color, readout: @escaping (Double) -> String,
                       liveDetail: String) -> some View {
        let focused = focusedSample
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: MCSpacing.xs) {
                // A 6pt swatch is the whole legend: two series, two colours,
                // named in place. A legend box below the chart would be a
                // third element saying what the label beside it already says.
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).font(MCFont.sectionTitle)
                Spacer()
                Text(liveHover == nil ? liveDetail : (focused.map { readout($0[keyPath: keyPath]) } ?? liveDetail))
                    .font(MCFont.caption).monospacedDigit()
                    .foregroundStyle(liveHover == nil ? MCColor.textSecondary : MCColor.textPrimary)
            }
            if model.samples.count > 1 {
                Chart(model.samples) { sample in
                    AreaMark(x: .value("Time", sample.date), y: .value(title, sample[keyPath: keyPath]))
                        .foregroundStyle(color.opacity(MCOpacity.chartArea))
                    // No gradient AreaMark here.
                    //
                    // One was added to give the curve a body, and it rendered
                    // as a row of disconnected triangular shards: a per-mark
                    // gradient `foregroundStyle` breaks Charts' implicit series
                    // grouping, so every sample became its own area. The line
                    // alone states the same thing correctly, and a chart that
                    // draws the wrong shape is worse than a plain one.
                    LineMark(x: .value("Time", sample.date), y: .value(title, sample[keyPath: keyPath]))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.monotone)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    // Two gridlines, not three, and both recessive. A chart
                    // whose grid is as strong as its data reads as a spreadsheet.
                    //
                    // Leading, because trailing put the scale labels in the
                    // same column as the value readout in the header above —
                    // a capture showed "44%" sitting directly on top of the
                    // axis's "100%", and the axis of the memory curve doing
                    // the same to "5,68 Go sur 8,59 Go".
                    AxisMarks(position: .leading, values: [0.5, 1]) { value in
                        AxisGridLine().foregroundStyle(MCColor.graphGrid)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v * 100))%")
                                    .font(MCFont.micro)
                                    .foregroundStyle(MCColor.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    // Let Charts choose the ticks.
                    //
                    // A fixed 60-second stride was landing every tick outside
                    // the visible domain for the first two minutes — the exact
                    // window this chart covers — so a screen whose whole claim
                    // is "this is temporal" rendered with no time axis at all.
                    // A capture caught it. Three or four marks, wherever the
                    // data actually is.
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(MCColor.graphGrid)
                        AxisValueLabel(format: .dateTime.minute().second())
                            .font(MCFont.micro)
                            .foregroundStyle(MCColor.textTertiary)
                    }
                }
                .chartOverlay { proxy in
                    hoverSurface(proxy: proxy, color: color, keyPath: keyPath)
                }
                .frame(height: MCSize.chartHeight)
                .accessibilityLabel(L("performance.chart_a11y", Int((model.samples.last?[keyPath: keyPath] ?? 0) * 100)))
            } else {
                Text(L("performance.collecting_samples"))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    .frame(height: MCSize.chartHeight)
            }
        }
    }

    /// Pointer tracking for one live curve.
    ///
    /// Writes into the *shared* hover date, so moving across the CPU chart
    /// also moves the rule on the memory chart below. The rule and dot are
    /// drawn here rather than as chart marks so that hovering never mutates
    /// the plotted data — a hover that changes the series is a hover that
    /// changes the answer.
    @ViewBuilder
    private func hoverSurface(proxy: ChartProxy, color: Color,
                              keyPath: KeyPath<PerformanceViewModel.Sample, Double>) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let sample = focusedSample, liveHover != nil,
                   let plot = proxy.plotFrame.map({ geo[$0] }),
                   let x = proxy.position(forX: sample.date),
                   let y = proxy.position(forY: sample[keyPath: keyPath]) {
                    Rectangle()
                        .fill(MCColor.textTertiary.opacity(0.5))
                        .frame(width: 1, height: plot.height)
                        .position(x: plot.minX + x, y: plot.midY)
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .position(x: plot.minX + x, y: plot.minY + y)
                }
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point):
                            guard let plot = proxy.plotFrame.map({ geo[$0] }) else { return }
                            liveHover = proxy.value(atX: point.x - plot.minX, as: Date.self)
                        case .ended:
                            liveHover = nil
                        }
                    }
            }
        }
    }

    // MARK: - Recorded scans

    private var rangedHistory: [PerformanceViewModel.ScanPoint] {
        guard let days = range.days,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        else { return model.scanHistory }
        return model.scanHistory.filter { $0.date >= cutoff }
    }

    /// The x window both recorded-scan charts are pinned to, so the bars and
    /// the item line sit on the same dates even where one of them is empty.
    private var historyDomain: ClosedRange<Date> {
        let now = Date()
        if let days = range.days,
           let start = Calendar.current.date(byAdding: .day, value: -days, to: now) {
            return start...now
        }
        let first = model.scanHistory.first?.date ?? now.addingTimeInterval(-86_400)
        return first...max(now, first.addingTimeInterval(86_400))
    }

    /// Every scan CoreTend has run, over time.
    ///
    /// Two series that answer one question the live curves cannot: is this Mac
    /// accumulating faster than it is being cleared? The bars are what each
    /// scan found; the strip below is how many items that was. A scan that
    /// finds more bytes in fewer items is a different situation from one that
    /// finds the same bytes spread over thousands, and the two series apart
    /// say so. They are stacked rather than overlaid on a second y axis
    /// because two scales sharing one frame make every crossing look like a
    /// relationship.
    private var scanHistorySection: some View {
        let points = rangedHistory
        return VStack(alignment: .leading, spacing: MCSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("performance.history.title"))
                        .font(MCFont.sectionTitle)
                    Text(L("performance.history.subtitle"))
                        .font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
                }
                Spacer(minLength: MCSpacing.md)
                // No period control over nothing. With no scan recorded, a
                // three-way choice of which empty window to look at is a
                // control that cannot change anything on screen.
                if !model.scanHistory.isEmpty {
                    Picker("", selection: $range) {
                        ForEach(ScanHistoryRange.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 210)
                    .accessibilityLabel(L("performance.history.range.a11y"))
                }
            }

            if !model.scanHistory.isEmpty { summaryLine(points) }

            if model.scanHistory.isEmpty {
                // Shown rather than omitted. With the section hidden, a Mac
                // that had never run a scan rendered Performance as two short
                // curves at the top of an otherwise empty page, and nothing
                // on screen said whether that was the whole module or a
                // loading state. The section states what will appear here.
                MCEmptyState(icon: "chart.bar",
                             title: L("performance.history.never_scanned"),
                             message: L("performance.history.never_scanned_detail"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else if points.isEmpty {
                Text(L("performance.history.empty_range"))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    .frame(height: 170, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                bytesChart(points)
                itemsStrip(points)
            }
        }
        .mcAnimation(MCMotion.transition, value: range)
    }

    /// What the selected window adds up to, read left to right: how many
    /// scans, how much they found in total, and the single largest one.
    /// Three figures the charts cannot state precisely, and no fourth.
    @ViewBuilder
    private func summaryLine(_ points: [PerformanceViewModel.ScanPoint]) -> some View {
        let total = points.reduce(Int64(0)) { $0 + $1.bytes }
        HStack(spacing: MCSpacing.md) {
            Text(L("performance.history.span", points.count))
            if !points.isEmpty {
                Text("·").foregroundStyle(MCColor.textTertiary)
                Text(L("performance.history.total", mcFormatBytes(total)))
                if let peak = points.max(by: { $0.bytes < $1.bytes }) {
                    Text("·").foregroundStyle(MCColor.textTertiary)
                    Text(L("performance.history.peak",
                           mcFormatBytes(peak.bytes),
                           AppDateFormatting.string(peak.date, style: .dayMonthYear)))
                }
            }
            Spacer(minLength: 0)
        }
        .font(MCFont.caption)
        .monospacedDigit()
        .foregroundStyle(MCColor.textSecondary)
    }

    @ViewBuilder
    private func bytesChart(_ points: [PerformanceViewModel.ScanPoint]) -> some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value(L("performance.history.axis_date"), point.date, unit: .day),
                    y: .value(L("performance.history.axis_found"),
                              Double(point.bytes) / 1_000_000_000))
                // The hovered bar is the only one at full strength. Dimming
                // the rest is what makes "this one" legible without a badge,
                // a stroke, or a colour that means something else elsewhere.
                .foregroundStyle(MCColor.teal.opacity(
                    scanHover == nil || scanHover?.id == point.id ? 0.75 : 0.28))
            }
            if let hovered = scanHover {
                RuleMark(x: .value(L("performance.history.axis_date"), hovered.date, unit: .day))
                    .foregroundStyle(MCColor.textTertiary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .center, spacing: 4) {
                        scanTooltip(hovered)
                    }
            }
        }
        // The unit belongs on the axis, once, not repeated on every tick.
        .chartYAxisLabel(L("performance.history.axis_found_unit"), alignment: .leading)
        .chartXScale(domain: historyDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) {
                AxisGridLine().foregroundStyle(MCColor.graphGrid)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(MCColor.graphGrid)
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            scanHoverSurface(proxy: proxy, points: points)
        }
        .frame(height: 170)
        .accessibilityLabel(L("performance.history.a11y", points.count))
    }

    /// Items found, on its own baseline under the bytes.
    ///
    /// Deliberately short: it is a second reading of the same events, not a
    /// second chart competing for the same attention. Its whole job is to let
    /// a tall bar over a flat strip read as "one big thing", and a short bar
    /// over a tall strip as "thousands of small ones".
    @ViewBuilder
    private func itemsStrip(_ points: [PerformanceViewModel.ScanPoint]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: MCSpacing.xs) {
                Circle().fill(MCColor.graphite).frame(width: 6, height: 6)
                Text(L("performance.history.items_axis"))
                    .font(MCFont.micro).foregroundStyle(MCColor.textTertiary)
                Spacer(minLength: 0)
                if let hovered = scanHover {
                    Text(L("performance.history.items_count", hovered.items))
                        .font(MCFont.micro).monospacedDigit()
                        .foregroundStyle(MCColor.textSecondary)
                }
            }
            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value(L("performance.history.axis_date"), point.date, unit: .day),
                        y: .value(L("performance.history.items_axis"), point.items))
                        .foregroundStyle(MCColor.graphite)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.monotone)
                    PointMark(
                        x: .value(L("performance.history.axis_date"), point.date, unit: .day),
                        y: .value(L("performance.history.items_axis"), point.items))
                        .foregroundStyle(MCColor.graphite.opacity(
                            scanHover == nil || scanHover?.id == point.id ? 1 : 0.3))
                        .symbolSize(scanHover?.id == point.id ? 34 : 12)
                }
            }
            .chartXScale(domain: historyDomain)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 2)) {
                    AxisGridLine().foregroundStyle(MCColor.graphGrid)
                    AxisValueLabel()
                }
            }
            .frame(height: 64)
            .accessibilityLabel(L("performance.history.items_a11y", points.count))
        }
    }

    private func scanTooltip(_ point: PerformanceViewModel.ScanPoint) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(AppDateFormatting.string(point.date, style: .dayMonthYearWithTime))
                .font(MCFont.micro).foregroundStyle(MCColor.textSecondary)
            Text(mcFormatBytes(point.bytes))
                .font(MCFont.captionEmphasis).monospacedDigit()
            Text(L("performance.history.items_count", point.items))
                .font(MCFont.micro).monospacedDigit()
                .foregroundStyle(MCColor.textSecondary)
        }
        .padding(.horizontal, MCSpacing.xs)
        .padding(.vertical, MCSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: MCRadius.small, style: .continuous)
                .fill(MCColor.elevatedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: MCRadius.small, style: .continuous)
                        .strokeBorder(MCColor.separator.opacity(MCOpacity.hairline))))
        .fixedSize()
    }

    @ViewBuilder
    private func scanHoverSurface(proxy: ChartProxy,
                                  points: [PerformanceViewModel.ScanPoint]) -> some View {
        GeometryReader { geo in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        guard let plot = proxy.plotFrame.map({ geo[$0] }),
                              let date = proxy.value(atX: location.x - plot.minX, as: Date.self)
                        else { return }
                        scanHover = points.min {
                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                        }
                    case .ended:
                        scanHover = nil
                    }
                }
        }
    }

    private func formatUptime(_ seconds: Int64) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        return days > 0 ? "\(days)d \(hours)h" : hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
