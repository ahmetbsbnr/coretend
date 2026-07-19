import SwiftUI
import SystemMetrics
import DesignSystem

@MainActor
@Observable
final class PerformanceViewModel {
    var snapshot: MetricsSnapshot?
    var history: [Double] = []          // CPU history ring, newest last
    private let collector = MetricsCollector()
    private var timerTask: Task<Void, Never>?

    func start() {
        guard timerTask == nil else { return }
        timerTask = Task {
            while !Task.isCancelled {
                let snap = await collector.snapshot()
                snapshot = snap
                history.append(snap.cpuUsedFraction)
                if history.count > 60 { history.removeFirst(history.count - 60) }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }
}

struct PerformanceView: View {
    @State private var model = PerformanceViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let snap = model.snapshot {
                    HStack(spacing: 16) {
                        gaugeCard(title: "CPU", fraction: snap.cpuUsedFraction,
                                  detail: "\(Int(snap.cpuUsedFraction * 100))%")
                        gaugeCard(title: "Memory", fraction: snap.memoryUsedFraction,
                                  detail: "\(mcFormatBytes(snap.memoryUsedBytes)) of \(mcFormatBytes(snap.memoryTotalBytes))")
                        gaugeCard(title: "Storage", fraction: snap.diskUsedFraction,
                                  detail: "\(mcFormatBytes(snap.diskFreeBytes)) free")
                    }
                    MCCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CPU — last 2 minutes").font(.headline)
                            cpuChart
                                .frame(height: 80)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    MCCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("System").font(.headline)
                            LabeledContent("Memory pressure", value: snap.memoryPressureLevel.capitalized)
                            LabeledContent("Thermal state", value: snap.thermalState.capitalized)
                            LabeledContent("Uptime", value: formatUptime(snap.uptimeSeconds))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ProgressView().padding(48)
                }
            }
            .padding(24)
        }
        .navigationTitle("Performance")
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var cpuChart: some View {
        Canvas { context, size in
            guard model.history.count > 1 else { return }
            let step = size.width / CGFloat(max(model.history.count - 1, 1))
            var path = Path()
            for (index, value) in model.history.enumerated() {
                let point = CGPoint(x: CGFloat(index) * step,
                                    y: size.height * (1 - CGFloat(value)))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(MCTheme.accent), lineWidth: 2)
        }
        .accessibilityLabel("CPU usage chart, currently \(Int((model.history.last ?? 0) * 100)) percent")
    }

    private func gaugeCard(title: String, fraction: Double, detail: String) -> some View {
        MCCard {
            VStack(spacing: 8) {
                Gauge(value: min(max(fraction, 0), 1)) {
                    Text(title)
                } currentValueLabel: {
                    Text("\(Int(fraction * 100))%")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(fraction > 0.85 ? MCTheme.danger : fraction > 0.65 ? MCTheme.warning : MCTheme.accent)
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func formatUptime(_ seconds: Int64) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        return days > 0 ? "\(days)d \(hours)h" : hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
