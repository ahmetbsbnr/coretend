// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem
import Persistence
import SystemMetrics

/// Overview — the first screen. Answers three questions in reading order:
/// how much room does this Mac have (and what do I do about it), what keeps
/// me safe, and what happened recently. Everything else is one row away.
struct DashboardView: View {
    @State private var snapshot: MetricsSnapshot?
    @State private var activity: [ActivityRecord] = []
    @State private var impact = ActivityImpactSummary([])
    @State private var impactRecordCount = 0
    @State private var exclusions: [String] = []
    @State private var collector = MetricsCollector()

    var body: some View {
        VStack(spacing: 0) {
            MCPageHeader(L("module.dashboard"),
                         eyebrow: L("dashboard.eyebrow"),
                         subtitle: L("dashboard.subtitle"))
            ScrollView {
                VStack(alignment: .leading, spacing: MCSpacing.lg) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: MCSpacing.md) {
                            storagePanel
                            safeguardsPanel.frame(width: 300)
                        }
                        VStack(spacing: MCSpacing.md) {
                            storagePanel
                            safeguardsPanel
                        }
                    }
                    .mcAppear()

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: MCSpacing.md) {
                            toolsPanel
                            activityPanel.frame(width: 360)
                        }
                        VStack(spacing: MCSpacing.md) {
                            toolsPanel
                            activityPanel
                        }
                    }
                    .mcAppear(delay: 0.05)
                }
                .padding(MCSpacing.page)
                .frame(maxWidth: MCSize.contentMax, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(L("module.dashboard"))
        .accessibilityIdentifier("dashboard.root")
        .task { await refresh() }
    }

    // MARK: - Storage: the headline figure and the primary action

    private var storagePanel: some View {
        MCPanel(L("dashboard.storage.title")) {
            VStack(alignment: .leading, spacing: MCSpacing.md) {
                HStack(alignment: .bottom, spacing: MCSpacing.lg) {
                    MCReadout(L("dashboard.status.free_space"),
                              value: snapshot.map { mcFormatBytes($0.diskFreeBytes) } ?? "—",
                              detail: snapshot.map { L("dashboard.storage.free_of_total", mcFormatBytes($0.diskTotalBytes)) },
                              large: true)
                    Spacer(minLength: MCSpacing.md)
                    if impact.freedBytes > 0 {
                        MCReadout(L("dashboard.reclaimed"),
                                  value: mcFormatBytes(impact.freedBytes),
                                  detail: L("dashboard.reclaimed.detail", impactRecordCount))
                            .fixedSize()
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    MCMeter(fraction: snapshot?.diskUsedFraction ?? 0,
                            tint: lowOnSpace ? MCTheme.warning : MCTheme.accent,
                            segments: 60, height: 10)
                    HStack {
                        Text(L("dashboard.storage.used", Int(((snapshot?.diskUsedFraction ?? 0) * 100).rounded())))
                        Spacer()
                        if lowOnSpace {
                            Label(L("menubar.status_attention"), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(MCTheme.warning)
                        }
                    }
                    .font(MCFont.mono)
                    .foregroundStyle(.secondary)
                }
                MCHairline()
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: MCSpacing.md) {
                        storageCopy
                        Spacer(minLength: MCSpacing.sm)
                        storageActions
                    }
                    VStack(alignment: .leading, spacing: MCSpacing.sm) {
                        storageCopy
                        storageActions
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard.storage")
    }

    private var storageCopy: some View {
        Text(L("dashboard.storage.detail"))
            .font(MCFont.secondaryBody)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 420, alignment: .leading)
    }

    private var storageActions: some View {
        HStack(spacing: MCSpacing.xs) {
            Button {
                navigate(.spaceLens)
            } label: {
                Label(L("dashboard.secondary_action"), systemImage: ModuleID.spaceLens.systemImage)
            }
            .buttonStyle(.mcSecondaryLarge)
            Button {
                navigate(.cleanup)
            } label: {
                Label(L("dashboard.primary_action"), systemImage: "sparkles")
            }
            .buttonStyle(.mcPrimaryLarge)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("dashboard.scan.start")
            .accessibilityLabel(L("dashboard.primary_action"))
        }
        .fixedSize()
    }

    private var lowOnSpace: Bool {
        (snapshot?.diskFreeBytes ?? .max) < 20_000_000_000
    }

    // MARK: - Safeguards: why it is safe to press the button

    private var safeguardsPanel: some View {
        MCPanel(L("dashboard.safeguards")) {
            VStack(spacing: 0) {
                MCKeyValueRow(L("dashboard.status.safety"), value: L("dashboard.status.trash_enabled"),
                              icon: "trash", status: .success)
                MCHairline()
                MCKeyValueRow(L("dashboard.status.exclusions"),
                              value: L("dashboard.status.exclusion_count", exclusions.count),
                              icon: "eye.slash")
                MCHairline()
                MCKeyValueRow(L("performance.memory_pressure"),
                              value: snapshot?.memoryPressureLevel.capitalized ?? "—",
                              icon: "memorychip",
                              status: snapshot.map { s -> MCStatus in s.memoryPressureLevel == "normal" ? .success : .attention })
                MCHairline()
                MCKeyValueRow(L("performance.thermal_state"),
                              value: snapshot?.thermalState.capitalized ?? "—",
                              icon: "thermometer.medium",
                              status: snapshot.map { s -> MCStatus in ["serious", "critical"].contains(s.thermalState) ? .attention : .success })
            }
        }
    }

    // MARK: - Tools: a dense list, not a tile wall

    private var toolsPanel: some View {
        MCPanel(L("dashboard.tools"), padded: false) {
            VStack(spacing: 0) {
                toolRow("dashboard.spacelens", L("dashboard.spacelens.title"),
                        L("dashboard.spacelens.detail"), ModuleID.spaceLens.systemImage, .spaceLens)
                MCHairline().padding(.leading, 56)
                toolRow("dashboard.duplicates", L("dashboard.duplicates.title"),
                        L("dashboard.duplicates.detail"), ModuleID.duplicates.systemImage, .duplicates)
                MCHairline().padding(.leading, 56)
                toolRow("dashboard.applications", L("dashboard.applications.title"),
                        L("dashboard.applications.detail"), ModuleID.applications.systemImage, .applications)
                MCHairline().padding(.leading, 56)
                toolRow("dashboard.integrity", L("dashboard.integrity.title"),
                        L("dashboard.integrity.detail"), ModuleID.protection.systemImage, .protection)
            }
        }
    }

    private func toolRow(_ id: String, _ title: String, _ detail: String, _ icon: String,
                         _ module: ModuleID) -> some View {
        Button {
            navigate(module)
        } label: {
            HStack(alignment: .center, spacing: MCSpacing.sm) {
                MCIconTile(icon, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(MCFont.cardTitle)
                    Text(detail)
                        .font(MCFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: MCSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, MCSpacing.md)
            .padding(.vertical, MCSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.mcRow)
        .accessibilityIdentifier(id)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Recent activity

    private var activityPanel: some View {
        MCPanel(L("dashboard.activity.title"), padded: false, accessory: {
            Button(L("dashboard.view_all")) { navigate(.myActivity) }
                .buttonStyle(.mcQuiet)
                .accessibilityIdentifier("dashboard.activity")
        }) {
            if activity.isEmpty {
                Text(L("dashboard.activity.empty"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .padding(MCSpacing.md)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(activity.prefix(5).enumerated()), id: \.element.id) { index, record in
                        if index > 0 { MCHairline().padding(.leading, MCSpacing.md) }
                        activityRow(record)
                    }
                }
            }
        }
    }

    private func activityRow(_ record: ActivityRecord) -> some View {
        HStack(alignment: .top, spacing: MCSpacing.sm) {
            Image(systemName: activityIcon(record.kind))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(record.kind == .error ? MCTheme.danger
                                 : record.kind == .cleanup ? MCTheme.accent : .secondary)
                .frame(width: 16, height: 16)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.summary)
                    .font(MCFont.secondaryBody)
                    .lineLimit(2)
                Text(AppDateFormatting.string(record.date, style: .dayMonthYearWithTime))
                    .font(MCFont.badge)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: MCSpacing.xs)
            if record.bytes > 0 {
                Text(mcFormatBytes(record.bytes))
                    .font(MCFont.mono)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, MCSpacing.md)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func activityIcon(_ kind: ActivityRecord.Kind) -> String {
        switch kind {
        case .scan: "magnifyingglass"
        case .cleanup: "trash"
        case .restore: "arrow.uturn.backward"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    // MARK: - Data

    private func refresh() async {
        async let latestSnapshot = collector.snapshot()
        if let store = AppEnvironment.shared.store {
            let history = (try? await store.activity(limit: 1000)) ?? []
            activity = Array(history.prefix(5))
            impact = ActivityImpactSummary(history)
            impactRecordCount = history.filter { $0.kind == .cleanup }.count
            exclusions = (try? await store.exclusions()) ?? []
        }
        snapshot = await latestSnapshot
    }

    private func navigate(_ module: ModuleID) {
        NotificationCenter.default.post(name: .mcNavigate, object: module)
    }
}
