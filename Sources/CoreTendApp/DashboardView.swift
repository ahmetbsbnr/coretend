// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem
import Persistence
import SystemMetrics

struct DashboardView: View {
    @State private var snapshot: MetricsSnapshot?
    @State private var activity: [ActivityRecord] = []
    @State private var exclusions: [String] = []
    @State private var collector = MetricsCollector()
    @State private var revealed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Secondary tools sit in a tighter, denser grid; Storage gets the hero.
    private let toolColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 320), spacing: MCSpacing.sm, alignment: .top),
    ]
    private let statusColumns = [
        GridItem(.adaptive(minimum: 168, maximum: 260), spacing: MCSpacing.sm, alignment: .top),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.xl) {
                brandRow
                    .modifier(Reveal(revealed: revealed, index: 0, reduceMotion: reduceMotion))
                scanHero
                    .modifier(Reveal(revealed: revealed, index: 1, reduceMotion: reduceMotion))
                statusStrip
                    .modifier(Reveal(revealed: revealed, index: 2, reduceMotion: reduceMotion))
                VStack(alignment: .leading, spacing: MCSpacing.sm) {
                    MCSectionHeader(L("sidebar.more"))
                    LazyVGrid(columns: toolColumns, alignment: .leading, spacing: MCSpacing.sm) {
                        toolTile("dashboard.spacelens", L("dashboard.spacelens.title"),
                                 L("dashboard.spacelens.detail"), ModuleID.spaceLens.systemImage, .spaceLens)
                        toolTile("dashboard.duplicates", L("dashboard.duplicates.title"),
                                 L("dashboard.duplicates.detail"), ModuleID.duplicates.systemImage, .duplicates)
                        toolTile("dashboard.applications", L("dashboard.applications.title"),
                                 L("dashboard.applications.detail"), ModuleID.applications.systemImage, .applications)
                        toolTile("dashboard.integrity", L("dashboard.integrity.title"),
                                 L("dashboard.integrity.detail"), ModuleID.protection.systemImage, .protection)
                        toolTile("dashboard.activity", L("dashboard.activity.title"),
                                 latestActivityText, ModuleID.myActivity.systemImage, .myActivity)
                    }
                }
                .modifier(Reveal(revealed: revealed, index: 3, reduceMotion: reduceMotion))
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(L("module.dashboard"))
        .accessibilityIdentifier("dashboard.root")
        .task {
            await refresh()
            if reduceMotion { revealed = true }
            else { withAnimation(MCMotion.reveal) { revealed = true } }
        }
    }

    // MARK: - Brand row: quiet identity line above the scan panel

    private var brandRow: some View {
        HStack(alignment: .center, spacing: MCSpacing.md) {
            CoreBloomMark(tint: [MCColor.teal], lineWidthFraction: 0.08)
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "CoreTend")
                    .font(MCFont.heroTitle)
                Text(L("dashboard.subtitle"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(MCColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Scan panel: the imposing centrepiece the dashboard is built around

    private var scanHero: some View {
        let ringSize: CGFloat = 128
        return HStack(alignment: .center, spacing: MCSpacing.xl) {
            ZStack {
                Circle()
                    .stroke(MCColor.storage.opacity(MCOpacity.orbitTrack), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: freeSpaceFraction)
                    .stroke(MCColor.storage, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .mcAnimation(MCMotion.settle, value: freeSpaceFraction)
                Image(systemName: ModuleID.cleanup.systemImage)
                    .font(.system(size: MCIconSize.feature, weight: .semibold))
                    .foregroundStyle(MCColor.storage)
            }
            .frame(width: ringSize, height: ringSize)
            .accessibilityHidden(true)

            // Three columns share this row: a fixed ring, this copy block, and
            // a 40pt metric. Without priorities the metric took the width it
            // wanted and squeezed this column until the primary action read
            // "Sc…". The copy block is the one that must survive, so it gets
            // the priority and a floor; the metric gives way instead.
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                Text(L("dashboard.storage.title")).font(MCFont.pageTitle)
                Text(L("dashboard.storage.detail"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(MCColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    navigate(.cleanup)
                } label: {
                    Label(L("dashboard.primary_action"), systemImage: "sparkles")
                        .font(MCFont.actionLabel)
                        // The label of the app's primary action never
                        // truncates. If the window is too narrow for it, the
                        // window is too narrow.
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.vertical, MCSpacing.sm)
                        .padding(.horizontal, MCSpacing.lg)
                }
                .mcPrimaryButton()
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, MCSpacing.sm)
                .accessibilityIdentifier("dashboard.scan.start")
                .accessibilityLabel(L("dashboard.primary_action"))
            }
            .frame(minWidth: 220, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: MCSpacing.md)
            if let snap = snapshot {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(mcFormatBytes(snap.diskFreeBytes))
                        .font(MCFont.displayMetric)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(L("dashboard.storage.free_of_total", mcFormatBytes(snap.diskTotalBytes)))
                        .font(MCFont.badge)
                        .foregroundStyle(MCColor.textSecondary)
                }
                .fixedSize()
                .accessibilityElement(children: .combine)
            }
        }
        .padding(MCSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The one panel this screen is built around, so the one surface that
        // carries the accent tint and a shadow.
        .mcSurface(.feature)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard.storage")
    }

    // MARK: - Status strip

    // A short live read of the machine — what the user is here to act on.
    // Build/signature status is meta and lives in Settings, not here.
    private var statusStrip: some View {
        LazyVGrid(columns: statusColumns, alignment: .leading, spacing: MCSpacing.sm) {
            statusPill(L("dashboard.status.free_space"),
                       value: snapshot.map { mcFormatBytes($0.diskFreeBytes) } ?? L("dashboard.status.loading"),
                       icon: "internaldrive",
                       attention: (snapshot?.diskFreeBytes ?? 20_000_000_000) < 20_000_000_000)
            statusPill(L("dashboard.status.safety"),
                       value: L("dashboard.status.trash_enabled"),
                       icon: "trash",
                       attention: false)
            statusPill(L("dashboard.status.exclusions"),
                       value: L("dashboard.status.exclusion_count", exclusions.count),
                       icon: "line.3.horizontal.decrease.circle",
                       attention: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var freeSpaceFraction: CGFloat {
        guard let snap = snapshot, snap.diskTotalBytes > 0 else { return 0 }
        return CGFloat(Double(snap.diskFreeBytes) / Double(snap.diskTotalBytes))
    }

    // MARK: - Secondary tool tiles

    private func toolTile(_ id: String, _ title: String, _ detail: String, _ icon: String,
                          _ module: ModuleID, attention: Bool = false) -> some View {
        Button {
            navigate(module)
        } label: {
            MCCard {
                VStack(alignment: .leading, spacing: MCSpacing.xs) {
                    HStack(spacing: MCSpacing.xs) {
                        Image(systemName: attention ? "exclamationmark.triangle.fill" : icon)
                            .font(.system(size: MCIconSize.row, weight: .semibold))
                            .foregroundStyle(attention ? MCColor.attention : .secondary)
                            .frame(width: 20)
                        Text(title).font(MCFont.cardTitle)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                            .font(.system(size: MCIconSize.chevron, weight: .semibold))
                            .foregroundStyle(MCColor.textTertiary)
                    }
                    Text(detail)
                        .font(MCFont.caption)
                        .foregroundStyle(MCColor.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityAddTraits(.isButton)
    }

    private func statusPill(_ title: String, value: String, icon: String, attention: Bool) -> some View {
        HStack(spacing: MCSpacing.xs) {
            Image(systemName: attention ? "exclamationmark.triangle.fill" : icon)
                .foregroundStyle(attention ? MCColor.attention : MCColor.teal)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(MCFont.badge)
                    .foregroundStyle(MCColor.textSecondary)
                    .textCase(.uppercase)
                    .kerning(0.4)
                Text(value)
                    .font(MCFont.secondaryBody)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .contentTransition(.opacity)
            }
        }
        .padding(.horizontal, MCSpacing.sm)
        .padding(.vertical, MCSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcSurface(.raised, radius: MCRadius.small)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Derived text

    private var latestActivityText: String {
        guard let record = activity.first else { return L("dashboard.activity.empty") }
        return "\(record.summary) · \(AppDateFormatting.string(record.date, style: .dayMonthYearWithTime))"
    }

    private func refresh() async {
        async let latestSnapshot = collector.snapshot()
        if let store = AppEnvironment.shared.store {
            activity = (try? await store.activity(limit: 5)) ?? []
            exclusions = (try? await store.exclusions()) ?? []
        }
        snapshot = await latestSnapshot
    }

    private func navigate(_ module: ModuleID) {
        NotificationCenter.default.post(name: .mcNavigate, object: module)
    }
}

/// Load-time staggered reveal. Transform/opacity only; a no-op under Reduce
/// Motion, where `revealed` is set without an animation.
private struct Reveal: ViewModifier {
    let revealed: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed || reduceMotion ? 0 : 10)
            // Capped stagger: an ungated `index * 0.06` makes the last card of
            // a long grid wait seconds for its turn.
            .mcAnimation(MCMotion.reveal.delay(MCMotion.stagger(index: index)), value: revealed)
    }
}
