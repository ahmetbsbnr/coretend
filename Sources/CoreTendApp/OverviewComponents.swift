// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import Persistence
import DesignSystem

/// A titled group of rows.
///
/// Not a card. The reference draws every group as a bordered panel, and that
/// is the habit this app removed: eleven `MCCard`s enclosing information that
/// alignment already grouped. A heading, a hairline and the rows beneath it
/// say "these belong together" without spending a rectangle on it, and the
/// screen keeps its depth for the one surface that earns it.
struct MCPanel<Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String?,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(MCFont.sectionTitle)
                    if let subtitle {
                        Text(subtitle).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    }
                }
                Spacer()
                trailing()
            }
            Divider()
            content().padding(.top, MCSpacing.xxs)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// One measured figure, and the way into the module that measured it.
///
/// The one raised surface on the screen. It earns the relief because it is a
/// control — a click goes somewhere — and because four of them in a row need
/// to read as four things rather than as a paragraph of numbers.
struct MetricTile: View {
    let icon: String
    let label: String
    /// Nil when the figure does not exist yet — not zero, which is a finding.
    let value: String?
    let detail: String
    let destination: ModuleID?

    @State private var isHovered = false

    var body: some View {
        let content = VStack(alignment: .leading, spacing: MCSpacing.xxs) {
            HStack(spacing: MCSpacing.xs) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(MCColor.teal)
                    .accessibilityHidden(true)
                Text(label).font(MCFont.groupHeader).foregroundStyle(MCColor.textSecondary)
                    .textCase(.uppercase).lineLimit(1)
                Spacer(minLength: 0)
                if destination != nil {
                    Image(systemName: "chevron.right")
                        .font(MCFont.caption)
                        .foregroundStyle(MCColor.textTertiary)
                        .opacity(isHovered ? 1 : 0.5)
                        .accessibilityHidden(true)
                }
            }
            // A figure that does not exist is said once, in words, at reading
            // size. An em-dash over the caption "Never run" reads as a broken
            // tile rather than as a module nobody has run.
            if let value {
                Text(value).font(MCFont.displayMetric).monospacedDigit().lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !detail.isEmpty {
                    Text(detail).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                        .lineLimit(2)
                }
            } else {
                Text(detail).font(MCFont.body).foregroundStyle(MCColor.textSecondary)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(MCSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: MCRadius.card, style: .continuous)
                .fill(MCColor.elevatedBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: MCRadius.card, style: .continuous)
                        .strokeBorder(isHovered ? Color.accentColor : MCColor.separator,
                                      lineWidth: isHovered ? 1.5 : 1)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: MCRadius.card, style: .continuous))
        .onHover { hovering in
            withAnimation(MCMotion.response) { isHovered = hovering }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value ?? detail)\(value == nil || detail.isEmpty ? "" : ", \(detail)")")

        if let destination {
            Button {
                NotificationCenter.default.post(name: .mcNavigate, object: destination)
            } label: { content }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
        } else {
            content
        }
    }
}

/// One volume as a proportional bar: what is used, what CoreTend's last scan
/// found inside that, and what is free.
///
/// Three real quantities. The reference splits this bar five ways —
/// Applications, Documents, Media, System, Photos — which macOS does not
/// report and no app can compute without reading every directory on the disk,
/// including the ones it is not allowed to open. A bar is a claim about
/// proportions; this one only claims what was counted.
struct VolumeRow: View {
    let volume: OverviewViewModel.Volume
    let isSelected: Bool
    let isSelectable: Bool
    let cleanupScanDate: Date?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: MCSpacing.xs) {
                    Image(systemName: volume.isInternal ? "internaldrive" : "externaldrive")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(MCColor.textSecondary)
                        .accessibilityHidden(true)
                    Text(volume.name).font(MCFont.rowTitle).lineLimit(1)
                    Spacer(minLength: MCSpacing.xs)
                    Text(L("overview.disk_free", mcFormatBytes(volume.free), mcFormatBytes(volume.total)))
                        .font(MCFont.tabular).foregroundStyle(MCColor.textSecondary)
                }
                bar
                legend
            }
            .padding(.vertical, MCSpacing.xxs)
            .padding(.horizontal, MCSpacing.xs)
            .background {
                RoundedRectangle(cornerRadius: MCRadius.small, style: .continuous)
                    // Selection is only drawn when there is something to
                    // choose between. On a Mac with one disk the wash was a
                    // coloured block around the only row on screen.
                    .fill(isSelected && isSelectable ? Color.accentColor.opacity(MCOpacity.hoverWash) : .clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(L("overview.disk_a11y", volume.name,
                              mcFormatBytes(volume.used), mcFormatBytes(volume.total)))
    }

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(MCColor.separator)
                Capsule().fill(MCColor.graphite)
                    .frame(width: max(2, geo.size.width * volume.usedFraction))
                if volume.breakdown.foundFraction > 0 {
                    Capsule().fill(MCColor.teal)
                        .frame(width: max(2, geo.size.width * volume.breakdown.foundFraction))
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    private var legend: some View {
        HStack(spacing: MCSpacing.md) {
            swatch(MCColor.graphite, L("overview.legend_used"), mcFormatBytes(volume.used))
            if let found = volume.breakdown.foundByLastScan, found > 0, let cleanupScanDate {
                swatch(MCColor.teal,
                       L("overview.legend_found", AppDateFormatting.string(cleanupScanDate, style: .dayMonthYear)),
                       mcFormatBytes(found))
            }
            swatch(MCColor.separator, L("overview.legend_free"), mcFormatBytes(volume.free))
            Spacer(minLength: 0)
        }
        .font(MCFont.caption)
        .accessibilityHidden(true)
    }

    private func swatch(_ colour: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: MCSpacing.xxs) {
            Circle().fill(colour).frame(width: 7, height: 7)
            Text(label).foregroundStyle(MCColor.textSecondary)
            Text(value).monospacedDigit()
        }
    }
}

/// One line of the Record, as the Overview shows it.
struct RecentRow: View {
    let item: RecordItem

    var body: some View {
        HStack(spacing: MCSpacing.xs) {
            Text(title).font(MCFont.body).lineLimit(1)
            Text(subtitle).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: MCSpacing.xs)
            Text(AppDateFormatting.string(item.date, style: .dayMonthYearWithTime))
                .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
        }
        .padding(.vertical, MCSpacing.tight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle), \(AppDateFormatting.string(item.date, style: .dayMonthYearWithTime))")
    }

    private var title: String {
        switch item {
        case let .operation(entry): RecordPhrasing.title(entry)
        case let .event(record): RecordPhrasing.eventTitle(record)
        }
    }

    private var subtitle: String {
        switch item {
        case let .operation(entry): RecordPhrasing.subtitle(entry)
        case let .event(record): record.summary
        }
    }
}

/// The context column, shown only when the window is wide enough for it to be
/// extra information rather than a squeeze on the main column.
struct VolumeContextColumn: View {
    let volume: OverviewViewModel.Volume
    let scans: [OverviewFacts.ScanResult]

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.lg) {
            MCPanel(title: volume.name, subtitle: L("overview.volume_subtitle")) {
                VStack(alignment: .leading, spacing: MCSpacing.xs) {
                    // One "Used" row, not two: bytes and percentage are the
                    // same fact twice, and two rows sharing a label read as a
                    // mistake before they read as two views of one number.
                    fact(L("overview.legend_used"),
                         "\(mcFormatBytes(volume.used)) · \(Int((volume.usedFraction * 100).rounded()))%")
                    fact(L("overview.legend_free"), mcFormatBytes(volume.free))
                    fact(L("overview.capacity"), mcFormatBytes(volume.total))
                }
            }
            MCPanel(title: L("overview.scans"), subtitle: nil) {
                VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                    ForEach([ModuleID.cleanup, .spaceLens, .duplicates, .applications], id: \.rawValue) { module in
                        Button {
                            NotificationCenter.default.post(name: .mcNavigate, object: module)
                        } label: {
                            HStack(spacing: MCSpacing.xs) {
                                Image(systemName: module.systemImage)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(MCColor.textSecondary)
                                    .frame(width: 18).accessibilityHidden(true)
                                Text(module.label).font(MCFont.body)
                                Spacer(minLength: MCSpacing.xxs)
                                Text(scans.first { $0.module == module }
                                        .map { AppDateFormatting.string($0.date, style: .dayMonthYear) }
                                     ?? L("overview.never_run"))
                                    .font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("overview.scan_a11y", module.label,
                                              scans.first { $0.module == module }
                                                .map { AppDateFormatting.string($0.date, style: .dayMonthYearWithTime) }
                                              ?? L("overview.never_run")))
                    }
                }
            }
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(MCFont.body).foregroundStyle(MCColor.textSecondary)
            Spacer()
            Text(value).font(MCFont.tabular)
        }
        .accessibilityElement(children: .combine)
    }
}
