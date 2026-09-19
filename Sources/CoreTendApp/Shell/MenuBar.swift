// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

// The menu bar extra: icon model and panel.

import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence

@MainActor
@Observable
final class MenuBarIconModel {
    var needsAttention = false
    private let collector = MetricsCollector()
    private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
        task = Task {
            while !Task.isCancelled {
                let snap = await collector.snapshot()
                needsAttention = Self.needsAttention(
                    thermalState: snap.thermalState,
                    memoryPressureLevel: snap.memoryPressureLevel,
                    diskFreeBytes: snap.diskFreeBytes)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    /// Pure so it's directly testable without a live metrics collector.
    nonisolated static func needsAttention(thermalState: String, memoryPressureLevel: String, diskFreeBytes: Int64) -> Bool {
        thermalState == "serious" || thermalState == "critical"
            || memoryPressureLevel == "critical"
            || diskFreeBytes < 5_000_000_000
    }
}

struct MenuBarLabel: View {
    @State private var iconModel = MenuBarIconModel()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = CoreTendApp.menuBarImage {
                Image(nsImage: image)
            } else {
                Image(systemName: "circle.hexagonpath")
            }
            if iconModel.needsAttention {
                // Shape + position carries the meaning, not color alone.
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: MCIconSize.inline))
                    .offset(x: 5, y: -5)
            }
        }
        .task { iconModel.start() }
    }
}

/// Lightweight status popover. Samples system metrics only while the menu is open.
struct MenuBarView: View {
    @State private var snapshot: MetricsSnapshot?
    @State private var collector = MetricsCollector()
    @State private var lastActivity: ActivityRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.sm) {
            HStack(spacing: MCSpacing.xs) {
                CoreBloomMark(tint: [MCColor.teal], lineWidthFraction: 0.1)
                    .frame(width: 18, height: 18)
                Text(verbatim: "CoreTend").font(MCFont.cardTitle)
                Spacer(minLength: 0)
            }
            if let snap = snapshot {
                gaugeRow("cpu", L("menubar.cpu"), fraction: snap.cpuUsedFraction,
                         value: "\(Int(snap.cpuUsedFraction * 100))%",
                         warn: snap.cpuUsedFraction > 0.85)
                gaugeRow("memorychip", L("menubar.memory"), fraction: snap.memoryUsedFraction,
                         value: "\(Int(snap.memoryUsedFraction * 100))% · \(snap.memoryPressureLevel)",
                         warn: snap.memoryPressureLevel != "normal")
                gaugeRow("internaldrive", L("menubar.free_space"), fraction: snap.diskUsedFraction,
                         value: mcFormatBytes(snap.diskFreeBytes),
                         warn: snap.diskFreeBytes < 20_000_000_000)
                metricRow(icon: "thermometer.medium", label: L("menubar.thermal"),
                          value: snap.thermalState.capitalized,
                          warn: snap.thermalState == "serious" || snap.thermalState == "critical")
            } else {
                HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }
                    .padding(.vertical, MCSpacing.sm)
            }
            Divider()
            if let last = lastActivity {
                Text(L("menubar.last_activity", last.summary))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    .lineLimit(2)
                Text(last.date, style: .relative)
                    .font(MCFont.micro).foregroundStyle(MCColor.textTertiary)
            } else {
                Text(L("menubar.no_activity_yet"))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            }
            Divider()
            Button(L("menubar.open_app")) { openWindow() }
            SettingsLink {
                Text(L("menubar.settings"))
            }
            Button(L("menubar.quit")) { NSApp.terminate(nil) }
        }
        .padding(MCSpacing.md)
        .frame(width: 288)
        .task {
            // Adaptive: only samples while this view exists (menu open).
            _ = await collector.snapshot()
            while !Task.isCancelled {
                snapshot = await collector.snapshot()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .task {
            guard let store = AppEnvironment.shared.store else { return }
            let recent = (try? await store.activity(limit: 20)) ?? []
            lastActivity = recent.first
        }
    }

    private func openWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title == "CoreTend" }?.makeKeyAndOrderFront(nil)
    }

    /// Metric with an inline fill bar — for the 0…1 gauges (CPU, memory, disk).
    private func gaugeRow(_ icon: String, _ label: String, fraction: Double, value: String, warn: Bool) -> some View {
        let tint: Color = warn ? MCTheme.warning : MCTheme.accent
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: MCSpacing.xs) {
                Image(systemName: icon).frame(width: 16).foregroundStyle(tint)
                Text(label)
                Spacer(minLength: MCSpacing.xs)
                if warn {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(MCFont.micro).foregroundStyle(MCTheme.warning)
                        .accessibilityHidden(true)
                }
                Text(value).foregroundStyle(MCColor.textSecondary).monospacedDigit()
            }
            .font(MCFont.secondaryBody)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MCColor.separator.opacity(MCOpacity.hairline))
                    Capsule().fill(tint)
                        .frame(width: max(3, geo.size.width * min(max(fraction, 0), 1)))
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)" + (warn ? ", \(L("menubar.warning_a11y"))" : ""))
    }

    /// Metric with no meaningful 0…1 fraction — a plain label/value row.
    private func metricRow(icon: String, label: String, value: String, warn: Bool) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 16)
                .foregroundStyle(warn ? MCTheme.warning : MCTheme.accent)
            Text(label)
            Spacer()
            if warn {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(MCFont.micro).foregroundStyle(MCTheme.warning)
                    .accessibilityHidden(true)
            }
            Text(value).foregroundStyle(MCColor.textSecondary).monospacedDigit()
        }
        .font(MCFont.secondaryBody)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)" + (warn ? ", \(L("menubar.warning_a11y"))" : ""))
    }
}
