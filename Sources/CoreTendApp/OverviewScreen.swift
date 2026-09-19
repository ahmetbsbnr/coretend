// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// Overview, recomposed.
///
/// The screen this replaces was a single scrolled column: a title, four
/// paragraphs of metric, one progress bar, a permission row carrying as much
/// structural weight as the storage it was interrupting, and a raw list. It
/// used a 1180-point window without ever laying anything out across it.
///
/// This is a composition instead of a stack. Four bands, each with its own
/// surface level, density and rhythm:
///
/// 1. **Masthead** — who this screen is, which volume it is about, when it was
///    last measured, and the one verb that changes any of that.
/// 2. **Signals** — three figures, large, on a raised band. Each is a way into
///    the module that produced it, so a number is navigation, not decoration.
/// 3. **Storage** — a capacity ring and a segmented bar that name their
///    categories, with the volume switcher in the band itself. Multi-volume is
///    built in rather than retrofitted.
/// 4. **Activity + context** — a dense operation log beside a narrow context
///    rail that carries the volume summary, anything needing a person, and the
///    quick actions. The rail appears only when the window is wide enough for
///    it to add information rather than squeeze the log.
///
/// The figures are the same measured quantities the previous screen showed.
/// Nothing here invents a number: what is drawn is what macOS reported or what
/// CoreTend recorded when it did the work.
struct OverviewScreen: View {
    @State private var model = OverviewViewModel()
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// The width at which the context rail stops being a squeeze. Below it the
    /// rail's content folds back into the main column rather than vanishing —
    /// a compact window is a different layout, not a cropped large one.
    private static let railThreshold: CGFloat = 860

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= Self.railThreshold
            // How many entries the journal can show in the height left over.
            //
            // It was a fixed nine. Removing the ring and the signals band made
            // the page shorter, so nine rows now stopped two fifths of the way
            // down the window — the density won by deleting redundancy was
            // handed straight back as empty space. The list takes what is
            // there instead.
            let rows = max(6, Int((geo.size.height - 430) / 34))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    masthead
                    // Capacity is the hero, and it absorbed the free-space
                    // figure that used to open the signals band.
                    //
                    // Free space was stated three times on one screen: as a
                    // signal, inside the ring, and again in the legend. The
                    // ring and the segmented bar also encoded the same
                    // proportion twice. One band now answers "how full is this
                    // disk", and the signals that remain are the two findings
                    // the capacity bar cannot show.
                    storage
                    if wide {
                        HStack(alignment: .top, spacing: 0) {
                            activity(rows: rows)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            OverviewRailSeparator()
                            contextRail
                                .frame(width: 292)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            activity(rows: rows)
                            contextRail
                        }
                    }
                }
            }
            .scrollIndicators(.automatic)
        }
        .navigationTitle(L("module.overview"))
        .task { await model.load() }
        // A Visual Beta scenario seeds the store asynchronously, which can
        // land after this view's `.task` has already read an empty table.
        // Without this the fixture captures showed the empty state.
        .onReceive(NotificationCenter.default.publisher(for: .mcFixtureSeeded)) { _ in
            Task { await model.load() }
        }
    }

    // MARK: - 1. Masthead

    /// The screen's identity and its one verb. Set on its own surface so the
    /// window has a head rather than starting straight into content, and so
    /// the scroll passes underneath something instead of under nothing.
    private var masthead: some View {
        HStack(alignment: .center, spacing: MCSpacing.lg) {
            // No module name here.
            //
            // The typography audit put every screen side by side: only this one
            // and Integrity printed their own name in the content, and both
            // printed it directly under the same name already in the toolbar.
            // The masthead keeps what the toolbar cannot say — which volume,
            // measured when — and the ~40 points the redundant title occupied
            // go back to the content.
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                HStack(spacing: MCSpacing.xs) {
                    if let volume = model.selectedVolume {
                        Label(volume.name, systemImage: "internaldrive")
                            .labelStyle(.titleAndIcon)
                            .font(MCFont.secondaryBody)
                            .foregroundStyle(MCColor.textSecondary)
                        Text("·").foregroundStyle(MCColor.textTertiary)
                    }
                    Text(lastScanPhrase)
                        .font(MCFont.secondaryBody)
                        .foregroundStyle(MCColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: MCSpacing.md)
            Button {
                NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.cleanup)
                NotificationCenter.default.post(name: .mcStartScan, object: nil)
            } label: {
                Label(L("overview.action_scan_now"), systemImage: "sparkle.magnifyingglass")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, MCSpacing.xxs)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("overview.scanNow")
        }
        .padding(.horizontal, MCSpacing.page)
        .padding(.top, MCSpacing.md)
        .padding(.bottom, MCSpacing.sm)
    }

    /// Relative, because "when was this measured" is a question about distance
    /// from now, not a calendar lookup the reader has to perform.
    private var lastScanPhrase: String {
        guard let date = model.lastScanDate else { return L("overview.never_run") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return L("overview.measured_relative", formatter.localizedString(for: date, relativeTo: Date()))
    }

    // MARK: - 2. Signals

    /// The measures the capacity bar cannot show, at the same weight as its
    /// legend rather than in a band of their own.
    ///
    /// They had a full-width raised band with 30-point figures. Two of the
    /// three restated something the capacity legend beside them already said —
    /// free space, then what Cleanup found — so the band was mostly a second
    /// printing of the band above it. What is left is genuinely elsewhere:
    /// what Duplicates found, and what CoreTend has actually moved.
    private var measures: some View {
        HStack(alignment: .top, spacing: MCSpacing.xl) {
            ForEach(signalTiles) { tile in
                SignalTile(tile: tile)
                    .frame(maxWidth: 260, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, MCSpacing.sm)
        .padding(.bottom, MCSpacing.xxs)
    }

    /// Three figures, not four paragraphs. Large enough to be read from the
    /// other side of a desk, each with one compact line of provenance beneath
    /// it, each a link into the module that measured it.
    private var signals: some View {
        HStack(spacing: 0) {
            ForEach(Array(signalTiles.enumerated()), id: \.element.id) { index, tile in
                if index > 0 {
                    Rectangle()
                        .fill(MCColor.separator.opacity(MCOpacity.hairline))
                        .frame(width: 1, height: 52)
                }
                SignalTile(tile: tile)
            }
        }
        .padding(.horizontal, MCSpacing.page - MCSpacing.sm)
        .padding(.vertical, MCSpacing.md)
        .background(alignment: .top) {
            Rectangle().fill(MCColor.secondaryBackground)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(MCColor.separator.opacity(MCOpacity.hairline)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(MCColor.separator.opacity(MCOpacity.hairline)).frame(height: 1)
        }
    }

    private var signalTiles: [SignalTileModel] {
        let volume = model.selectedVolume
        return [
            SignalTileModel(
                id: "duplicates",
                label: L("overview.metric_duplicates"),
                value: model.scan(for: .duplicates).map { mcFormatBytes($0.bytes) },
                detail: scanDetail(.duplicates),
                destination: .duplicates),
            SignalTileModel(
                id: "record",
                label: L("overview.metric_record"),
                value: model.recordSummary.movedItems > 0
                    ? mcFormatBytes(model.recordSummary.movedBytes) : nil,
                detail: model.recordSummary.movedItems > 0
                    ? L("overview.metric_record_detail", model.recordSummary.movedItems)
                    : L("overview.never_run_detail"),
                destination: .record),
        ]
    }

    private func scanDetail(_ module: ModuleID) -> String {
        guard let scan = model.scan(for: module) else { return L("overview.never_run") }
        return L("overview.metric_found_detail", scan.itemCount,
                 AppDateFormatting.string(scan.date, style: .dayMonthYear))
    }

    // MARK: - 3. Storage

    /// A capacity ring beside a named segmented bar, with the volume switcher
    /// in the band. The previous screen drew one flat progress bar whose
    /// segments had no legend a reader could use.
    private var storage: some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                OverviewBandTitle(title: L("overview.disk"), subtitle: L("overview.disk_subtitle"))
                Spacer(minLength: MCSpacing.md)
                if model.volumes.count > 1 {
                    VolumeSwitcher(volumes: model.volumes,
                                   selected: model.selectedVolume?.id) { model.selectedVolumeID = $0 }
                }
            }
            if let volume = model.selectedVolume {
                // The ring is gone.
                //
                // It drew the same proportion the segmented bar underneath it
                // already drew, printed a percentage nothing else needed, and
                // put "214 Go libres" on screen for the third time. A ring that
                // restates its neighbour is filling space, not explaining
                // anything — and a 132-point hollow circle is a lot of space to
                // fill. The bar keeps the job, at a size worth reading.
                CapacityBreakdown(volume: volume,
                                  found: model.scan(for: .cleanup)?.bytes,
                                  foundDate: model.scan(for: .cleanup)?.date)
                    .frame(maxWidth: .infinity, alignment: .leading)
                measures
            } else {
                Text(L("overview.no_volumes"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(MCColor.textSecondary)
            }
        }
        .padding(.horizontal, MCSpacing.page)
        .padding(.vertical, MCSpacing.lg)
    }

    // MARK: - 4. Activity

    /// Desktop density: a column header, several operations visible at once,
    /// and a tone chip that makes the state of each one legible before the
    /// text is read.
    private func activity(rows: Int) -> some View {
        let recent = Array(model.recent.prefix(rows))
        return VStack(alignment: .leading, spacing: MCSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                OverviewBandTitle(title: L("overview.recent"), subtitle: L("overview.recent_subtitle"))
                Spacer(minLength: MCSpacing.md)
                Button(L("overview.see_record")) {
                    NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.record)
                }
                .buttonStyle(.link)
            }
            if recent.isEmpty {
                Text(L("record.empty_message"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(MCColor.textSecondary)
                    .padding(.vertical, MCSpacing.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                        ActivityRow(item: item, striped: index.isMultiple(of: 2))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: MCRadius.card, style: .continuous))
            }
        }
        .padding(.horizontal, MCSpacing.page)
        .padding(.vertical, MCSpacing.lg)
    }

    // MARK: - Context rail

    private var contextRail: some View {
        VStack(alignment: .leading, spacing: MCSpacing.lg) {
            if !model.attention.isEmpty {
                AttentionStack(items: model.attention)
            }
            QuickActions()
        }
        .padding(.horizontal, MCSpacing.page)
        .padding(.vertical, MCSpacing.lg)
    }
}

// MARK: - Band furniture

/// The hairline that separates two bands, full-bleed so the bands read as
/// bands rather than as cards with gaps between them.
private struct OverviewDivider: View {
    var body: some View {
        Rectangle()
            .fill(MCColor.separator.opacity(MCOpacity.hairline))
            .frame(height: 1)
    }
}

private struct OverviewRailSeparator: View {
    var body: some View {
        Rectangle()
            .fill(MCColor.separator.opacity(MCOpacity.hairline))
            .frame(width: 1)
            .padding(.vertical, MCSpacing.lg)
    }
}

private struct OverviewBandTitle: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(MCFont.sectionTitle)
                .foregroundStyle(MCColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(MCFont.caption)
                    .foregroundStyle(MCColor.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Signals

struct SignalTileModel: Identifiable {
    let id: String
    let label: String
    let value: String?
    let detail: String
    let destination: ModuleID?
}

/// A figure at display size, its name above it in small caps, and its
/// provenance below. Hover and press are real, because a tile that navigates
/// has to look like it does before it is clicked.
private struct SignalTile: View {
    let tile: SignalTileModel
    @State private var hovered = false

    var body: some View {
        let content = VStack(alignment: .leading, spacing: MCSpacing.xxs) {
            HStack(spacing: MCSpacing.xxs) {
                // No colour swatch. The dot carried no information — it was
                // the same teal on every tile — and spending the accent on
                // decoration is exactly what stopped it meaning anything.
                Text(tile.label.uppercased())
                    .font(MCFont.groupHeader)
                    .foregroundStyle(MCColor.textSecondary)
                    .lineLimit(1)
                if tile.destination != nil {
                    Image(systemName: "arrow.up.right")
                        .font(MCFont.micro.weight(.semibold))
                        .foregroundStyle(MCColor.textTertiary)
                        .opacity(hovered ? 1 : 0)
                }
            }
            if let value = tile.value {
                Text(value)
                    .font(MCFont.displayAbsent)
                    .foregroundStyle(MCColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(tile.detail)
                    .font(MCFont.caption)
                    .foregroundStyle(MCColor.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text(L("overview.never_run"))
                    .font(MCFont.rowTitle)
                    .foregroundStyle(MCColor.textTertiary)
                    .lineLimit(1)
                Text(L("overview.never_run_detail"))
                    .font(MCFont.caption)
                    .foregroundStyle(MCColor.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, MCSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        Group {
            if let destination = tile.destination {
                Button {
                    NotificationCenter.default.post(name: .mcNavigate, object: destination)
                } label: { content }
                .buttonStyle(.plain)
                .onHover { hovered = $0 }
                .background(hovered ? MCColor.textPrimary.opacity(MCOpacity.hoverWash) : .clear)
                .accessibilityIdentifier("overview.signal.\(tile.id)")
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tile.label), \(tile.value ?? L("overview.never_run")), \(tile.detail)")
    }
}

// MARK: - Storage visualisation

/// The volume as a named, segmented bar — used, what the last scan found
/// inside that used space, and free — each segment legible in the legend
/// beneath it with its own figure.
private struct CapacityBreakdown: View {
    let volume: OverviewViewModel.Volume
    let found: Int64?
    let foundDate: Date?

    private var segments: [(label: String, bytes: Int64, colour: Color)] {
        // `found` is a subset of used, not a fourth quantity: drawing it
        // alongside used would total more than the disk holds.
        let foundBytes = min(found ?? 0, volume.used)
        return [
            (L("overview.segment_used"), volume.used - foundBytes, MCColor.graphite),
            (L("overview.segment_found"), foundBytes, MCColor.teal),
            (L("overview.segment_free"), volume.free, MCColor.textTertiary.opacity(0.32)),
        ].filter { $0.bytes > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: MCSpacing.xs) {
                Text(volume.name)
                    .font(MCFont.cardTitle)
                    .foregroundStyle(MCColor.textPrimary)
                Text(L("overview.capacity_of", mcFormatBytes(volume.total)))
                    .font(MCFont.caption)
                    .foregroundStyle(MCColor.textTertiary)
            }
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(segments, id: \.label) { segment in
                        let width = geo.size.width
                            * CGFloat(Double(segment.bytes) / Double(max(volume.total, 1)))
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(segment.colour)
                            .frame(width: max(4, width))
                    }
                }
            }
            // Carries the band now that the ring is gone, so it is worth
            // reading rather than a 4-point rule across a 1200-point window.
            .frame(height: 30)
            HStack(spacing: MCSpacing.xl) {
                ForEach(segments, id: \.label) { segment in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: MCSpacing.xxs) {
                            RoundedRectangle(cornerRadius: 2).fill(segment.colour)
                                .frame(width: 8, height: 8)
                            Text(segment.label)
                                .font(MCFont.caption)
                                .foregroundStyle(MCColor.textSecondary)
                        }
                        // The figure, at the weight the ring's centre used to
                        // carry. This is where the eye lands after the bar.
                        Text(mcFormatBytes(segment.bytes))
                            .font(MCFont.displayAbsent)
                            .foregroundStyle(MCColor.textPrimary)
                    }
                }
                Spacer(minLength: 0)
            }
            if let foundDate {
                Text(L("overview.found_on", AppDateFormatting.string(foundDate, style: .dayMonthYear)))
                    .font(MCFont.micro)
                    .foregroundStyle(MCColor.textTertiary)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Volume selection as segmented chips in the band's own header, so a second
/// disk is a visible choice rather than a row further down a list.
private struct VolumeSwitcher: View {
    let volumes: [OverviewViewModel.Volume]
    let selected: String?
    let choose: (String) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(volumes) { volume in
                let isOn = volume.id == selected
                Button {
                    choose(volume.id)
                } label: {
                    Label(volume.name,
                          systemImage: volume.isInternal ? "internaldrive" : "externaldrive")
                        .labelStyle(.titleAndIcon)
                        .font(MCFont.captionEmphasis)
                        .padding(.horizontal, MCSpacing.xs)
                        .padding(.vertical, MCSpacing.xxs + 1)
                        .background(isOn ? MCColor.teal.opacity(MCOpacity.selectionWash) : .clear,
                                    in: Capsule())
                        .foregroundStyle(isOn ? MCColor.textPrimary : MCColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2)
        .background(MCColor.secondaryBackground, in: Capsule())
    }
}

// MARK: - Activity

/// One operation. The verb is the loudest thing in the row, the size is
/// tabular so a column of them can be compared, and the state is a chip so it
/// is legible before any of the text is.
private struct ActivityRow: View {
    let item: RecordItem
    let striped: Bool
    @State private var hovered = false

    var body: some View {
        HStack(spacing: MCSpacing.sm) {
            Image(systemName: icon)
                .font(MCFont.caption.weight(.medium))
                .foregroundStyle(tone.tint)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(title)
                .font(MCFont.rowTitle)
                .foregroundStyle(MCColor.textPrimary)
                .lineLimit(1)
            Text(subtitle)
                .font(MCFont.caption)
                .foregroundStyle(MCColor.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: MCSpacing.sm)
            Text(AppDateFormatting.string(item.date, style: .dayMonthYearWithTime))
                .font(MCFont.tabular)
                .foregroundStyle(MCColor.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, MCSpacing.sm)
        .padding(.vertical, MCSpacing.xs)
        .background(background)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle), \(AppDateFormatting.string(item.date, style: .dayMonthYearWithTime))")
    }

    private var background: some View {
        Group {
            if hovered {
                MCColor.textPrimary.opacity(MCOpacity.hoverWash)
            } else if striped {
                MCColor.secondaryBackground.opacity(0.6)
            } else {
                Color.clear
            }
        }
    }

    private enum Tone {
        case moved, scanned, neutral
        /// Neutral. These were teal on every operation row, which put the
        /// accent on roughly two thirds of the densest list in the app and
        /// left it meaning nothing anywhere else.
        var tint: Color {
            switch self {
            case .moved: MCColor.textSecondary
            case .scanned: MCColor.textTertiary
            case .neutral: MCColor.textTertiary
            }
        }
    }

    private var tone: Tone {
        switch item {
        case .operation: .moved
        case .event: .scanned
        }
    }

    private var icon: String {
        switch item {
        case .operation: "arrow.uturn.backward.circle"
        case .event: "sparkle.magnifyingglass"
        }
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

// MARK: - Attention

/// A missing permission explains its impact and offers its action, in the
/// width of the rail — not across the page at the same visual weight as the
/// storage it was interrupting.
private struct AttentionStack: View {
    let items: [OverviewViewModel.Attention]

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            OverviewBandTitle(title: L("overview.attention"), subtitle: nil)
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: MCSpacing.xs) {
                    HStack(alignment: .top, spacing: MCSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(MCFont.caption)
                            .foregroundStyle(MCTheme.warning)
                            .accessibilityHidden(true)
                        Text(text(item))
                            .font(MCFont.caption)
                            .foregroundStyle(MCColor.textSecondary)
                            // No .fixedSize here: in a detail column it
                            // starves the split view's sidebar (repo
                            // principle 9). Wrapping is asked for with a
                            // line limit instead.
                            .lineLimit(4)
                    }
                    Button(action(item)) { act(on: item) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(MCSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                // A tinted surface with an amber edge, not a bordered card.
                // Two of these stacked in the rail read as two boxes; they now
                // read as two notices.
                .background(MCColor.secondaryBackground,
                            in: RoundedRectangle(cornerRadius: MCRadius.card, style: .continuous))
                .overlay(alignment: .leading) {
                    Rectangle().fill(MCTheme.warning).frame(width: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        .padding(.vertical, MCSpacing.xs)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private func text(_ item: OverviewViewModel.Attention) -> String {
        switch item {
        case .fullDiskAccessMissing: L("overview.attention_fda")
        case let .brokenLoginItems(n): L(n == 1 ? "overview.attention_login_one" : "overview.attention_login_other", n)
        case .neverScanned: L("overview.attention_never")
        case let .scansAreStale(days): L("overview.attention_stale", days)
        }
    }

    private func action(_ item: OverviewViewModel.Attention) -> String {
        switch item {
        case .fullDiskAccessMissing: L("overview.action_open_settings")
        case .brokenLoginItems: L("overview.action_review")
        case .neverScanned, .scansAreStale: L("overview.action_open_cleanup")
        }
    }

    private func act(on item: OverviewViewModel.Attention) {
        switch item {
        case .fullDiskAccessMissing:
            if let url = SystemAuthorization.fullDiskAccessSettingsURL { NSWorkspace.shared.open(url) }
        case .brokenLoginItems:
            NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.protection)
        case .neverScanned, .scansAreStale:
            NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.cleanup)
        }
    }
}

/// The work a person arriving at Overview most often wants to start, as a
/// list of verbs rather than a grid of cards.
private struct QuickActions: View {
    private struct Action: Identifiable {
        let id: String
        let label: String
        let icon: String
        let module: ModuleID
    }

    private var actions: [Action] {
        [
            Action(id: "cleanup", label: L("overview.quick_cleanup"),
                   icon: ModuleID.cleanup.systemImage, module: .cleanup),
            Action(id: "duplicates", label: L("overview.quick_duplicates"),
                   icon: ModuleID.duplicates.systemImage, module: .duplicates),
            Action(id: "explore", label: L("overview.quick_explore"),
                   icon: ModuleID.spaceLens.systemImage, module: .spaceLens),
            Action(id: "applications", label: L("overview.quick_applications"),
                   icon: ModuleID.applications.systemImage, module: .applications),
        ].filter { AppCapabilities.forCurrentBuild().supports($0.module) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            OverviewBandTitle(title: L("overview.quick_actions"), subtitle: nil)
            VStack(spacing: 0) {
                ForEach(actions) { action in
                    QuickActionRow(label: action.label, icon: action.icon) {
                        NotificationCenter.default.post(name: .mcNavigate, object: action.module)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: MCRadius.card, style: .continuous))
        }
    }
}

private struct QuickActionRow: View {
    let label: String
    let icon: String
    let perform: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: perform) {
            HStack(spacing: MCSpacing.xs) {
                Image(systemName: icon)
                    .font(MCFont.caption)
                    .foregroundStyle(MCColor.textSecondary)
                    .frame(width: 18)
                Text(label)
                    .font(MCFont.rowTitle)
                    .foregroundStyle(MCColor.textPrimary)
                Spacer(minLength: MCSpacing.xs)
                Image(systemName: "chevron.right")
                    .font(MCFont.micro.weight(.semibold))
                    .foregroundStyle(MCColor.textTertiary)
            }
            .padding(.horizontal, MCSpacing.sm)
            .padding(.vertical, MCSpacing.xs + 1)
            .background(hovered ? MCColor.textPrimary.opacity(MCOpacity.hoverWash) : MCColor.secondaryBackground.opacity(0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
