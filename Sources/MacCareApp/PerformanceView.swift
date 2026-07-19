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
                    launchAgentsCard
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

    @State private var agents: [LaunchAgentInfo] = []

    private var launchAgentsCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Login LaunchAgents").font(.headline)
                Text("Third-party agents started at login (~/Library/LaunchAgents). Broken entries point to programs that no longer exist. Inspection only — disable them in System Settings › Login Items.")
                    .font(.caption).foregroundStyle(.secondary)
                if agents.isEmpty {
                    Text("No user LaunchAgents.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(agents) { agent in
                    HStack {
                        Image(systemName: agent.broken ? "exclamationmark.triangle.fill" : "checkmark.circle")
                            .foregroundStyle(agent.broken ? MCTheme.warning : MCTheme.success)
                        VStack(alignment: .leading) {
                            Text(agent.label).font(.callout)
                            if let program = agent.programPath {
                                Text(agent.broken ? "missing: \(program)" : program)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: agent.id)])
                        } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { agents = LaunchAgentInspector.userAgents() }
    }

    private func formatUptime(_ seconds: Int64) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        return days > 0 ? "\(days)d \(hours)h" : hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
