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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let snap = model.snapshot {
                    HStack(spacing: MCSpacing.md) {
                        MCMetricCard(title: L("performance.cpu"),
                                     value: "\(Int(snap.cpuUsedFraction * 100))%",
                                     detail: L("performance.of_all_cores"),
                                     fraction: snap.cpuUsedFraction,
                                     color: statusColor(snap.cpuUsedFraction, base: MCColor.performance),
                                     isElevated: snap.cpuUsedFraction > 0.75,
                                     elevatedLabel: L("performance.elevated"))
                        MCMetricCard(title: L("performance.memory"),
                                     value: "\(Int(snap.memoryUsedFraction * 100))%",
                                     detail: L("performance.memory_detail", mcFormatBytes(snap.memoryUsedBytes), mcFormatBytes(snap.memoryTotalBytes)),
                                     fraction: snap.memoryUsedFraction,
                                     color: statusColor(snap.memoryUsedFraction, base: MCColor.protection),
                                     isElevated: snap.memoryUsedFraction > 0.75,
                                     elevatedLabel: L("performance.elevated"))
                        MCMetricCard(title: L("performance.storage"),
                                     value: "\(Int(snap.diskUsedFraction * 100))%",
                                     detail: L("performance.free_detail", mcFormatBytes(snap.diskFreeBytes)),
                                     fraction: snap.diskUsedFraction,
                                     color: statusColor(snap.diskUsedFraction, base: MCColor.storage),
                                     isElevated: snap.diskUsedFraction > 0.75,
                                     elevatedLabel: L("performance.elevated"))
                    }
                    MCCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("performance.cpu_chart_title")).font(.headline)
                            cpuChart
                                .frame(height: MCSize.chartHeight)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    MCCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L("performance.system")).font(.headline)
                            LabeledContent(L("performance.memory_pressure"), value: snap.memoryPressureLevel.capitalized)
                            LabeledContent(L("performance.thermal_state"), value: snap.thermalState.capitalized)
                            LabeledContent(L("performance.uptime"), value: formatUptime(snap.uptimeSeconds))
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
        .navigationTitle(L("performance.nav_title"))
        .onAppear { if scenePhase == .active { model.start() } }
        .onDisappear { model.stop() }
        // Idle-window behavior: stop sampling while the app is hidden/backgrounded
        // (window occluded, minimized, or app not frontmost) so no timer runs unseen.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.start() } else { model.stop() }
        }
    }

    private func statusColor(_ fraction: Double, base: Color) -> Color {
        fraction > 0.9 ? MCColor.destructive : fraction > 0.75 ? MCColor.attention : base
    }

    @ViewBuilder
    private var cpuChart: some View {
        if model.history.count > 1 {
            Canvas { context, size in
                // Grid: 25 / 50 / 75 %
                for level in [0.25, 0.5, 0.75] {
                    let y = size.height * (1 - level)
                    var grid = Path()
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(grid, with: .color(MCColor.graphGrid.opacity(0.4)), lineWidth: 1)
                }
                let step = size.width / CGFloat(max(model.history.count - 1, 1))
                var line = Path()
                for (index, value) in model.history.enumerated() {
                    let point = CGPoint(x: CGFloat(index) * step,
                                        y: size.height * (1 - CGFloat(value)))
                    if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
                }
                var fill = line
                fill.addLine(to: CGPoint(x: CGFloat(model.history.count - 1) * step, y: size.height))
                fill.addLine(to: CGPoint(x: 0, y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .linearGradient(
                    Gradient(colors: [Color(MCColor.performance).opacity(0.25), .clear]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                context.stroke(line, with: .color(MCColor.performance), lineWidth: 2)
            }
            .accessibilityLabel(L("performance.chart_a11y", Int((model.history.last ?? 0) * 100)))
        } else {
            Text(L("performance.collecting_samples"))
                .font(MCFont.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @State private var agents: [LaunchAgentInfo] = []

    private var launchAgentsCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("performance.launchagents.title")).font(.headline)
                Text(L("performance.launchagents.subtitle"))
                    .font(.caption).foregroundStyle(.secondary)
                if agents.isEmpty {
                    Text(L("performance.launchagents.empty")).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(agents) { agent in
                    HStack {
                        Image(systemName: agent.broken ? "exclamationmark.triangle.fill" : "checkmark.circle")
                            .foregroundStyle(agent.broken ? MCTheme.warning : MCTheme.success)
                        VStack(alignment: .leading) {
                            Text(agent.label).font(.callout)
                            if let program = agent.programPath {
                                Text(agent.broken ? L("performance.launchagents.missing", program) : program)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: agent.id)])
                        } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(L("common.reveal_in_finder"))
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
