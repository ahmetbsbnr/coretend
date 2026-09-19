// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import Charts
import SystemMetrics
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
                try? await Task.sleep(for: .seconds(2))
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

struct PerformanceView: View {
    @State private var model = PerformanceViewModel()
    @Environment(\.scenePhase) private var scenePhase

    /// Performance is about time. The screen is the current values in one
    /// line, then two curves over the last two minutes with a real time axis.
    /// The three rings that used to sit on top answered "what is it now" with
    /// a gauge and could not answer "what was it a minute ago" at all.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                if let snap = model.snapshot {
                    currentLine(snap)
                    Divider()
                    chart(L("performance.cpu"), keyPath: \.cpu, color: MCColor.teal,
                          latest: "\(Int(snap.cpuUsedFraction * 100))%")
                    chart(L("performance.memory"), keyPath: \.memory, color: MCColor.graphite,
                          latest: L("performance.memory_detail", mcFormatBytes(snap.memoryUsedBytes), mcFormatBytes(snap.memoryTotalBytes)))
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
        .onAppear { if scenePhase == .active { model.start() } }
        .onDisappear { model.stop() }
        // Idle-window behavior: stop sampling while the app is hidden/backgrounded
        // (window occluded, minimized, or app not frontmost) so no timer runs unseen.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.start() } else { model.stop() }
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
                       color: Color, latest: String) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(MCFont.sectionTitle)
                Spacer()
                Text(latest).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            }
            if model.samples.count > 1 {
                Chart(model.samples) { sample in
                    AreaMark(x: .value("Time", sample.date), y: .value(title, sample[keyPath: keyPath]))
                        .foregroundStyle(color.opacity(MCOpacity.chartArea))
                    LineMark(x: .value("Time", sample.date), y: .value(title, sample[keyPath: keyPath]))
                        .foregroundStyle(color)
                        .interpolationMethod(.monotone)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1]) { value in
                        AxisGridLine()
                        AxisValueLabel { if let v = value.as(Double.self) { Text("\(Int(v * 100))%") } }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .second, count: 30)) { _ in
                        AxisGridLine(); AxisValueLabel(format: .dateTime.minute().second())
                    }
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

    private func formatUptime(_ seconds: Int64) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        return days > 0 ? "\(days)d \(hours)h" : hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
