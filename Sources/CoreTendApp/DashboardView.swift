// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import Persistence
import SystemMetrics
import DesignSystem

/// Overview: in five seconds — how the disk is, what needs attention, what
/// changed, what to run next.
///
/// Four sections, each omitted when it has nothing to say. No score, no
/// gauge, no total that adds unlike things. Every figure is something the
/// Mac or CoreTend measured; where nothing has been measured yet the row says
/// so instead of estimating. See docs/FRONTEND_REBUILD.md § Overview.
@MainActor
@Observable
final class OverviewViewModel {
    struct Volume: Identifiable {
        let url: URL
        let name: String
        let total: Int64
        let free: Int64
        var id: String { url.path }
        var used: Int64 { max(0, total - free) }
        var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    }

    enum Attention: Identifiable {
        case fullDiskAccessMissing
        case brokenLoginItems(Int)
        case neverScanned
        var id: String {
            switch self {
            case .fullDiskAccessMissing: "fda"
            case .brokenLoginItems: "login"
            case .neverScanned: "never"
            }
        }
    }

    struct Scan: Identifiable {
        let module: ModuleID
        let lastRun: Date?
        var id: String { module.rawValue }
    }

    private(set) var volumes: [Volume] = []
    private(set) var attention: [Attention] = []
    private(set) var recent: [RecordItem] = []
    private(set) var scans: [Scan] = []
    private(set) var loaded = false

    func load() async {
        volumes = Self.mountedVolumes()
        let events = (try? await AppEnvironment.shared.store?.activity(limit: 500)) ?? []
        let ops = SafetyLedger.entries(from: (try? await AppEnvironment.shared.store?.safetyLog(limit: 200)) ?? [])
        recent = Array(SafetyLedger.items(operations: ops, events: events).prefix(5))
        scans = Self.scanRows(from: events)
        attention = Self.attentionRows(
            fullDisk: SystemAuthorization.probeLive().grant(for: .fullDisk),
            brokenLoginItems: LaunchAgentInspector.userAgents().filter(\.broken).count,
            anyScan: events.contains { $0.kind == .scan })
        loaded = true
    }

    /// Only what needs a person. Everything fine → nothing listed, and the
    /// section disappears rather than saying "all good" in green.
    nonisolated static func attentionRows(fullDisk: SystemAuthorization.Grant,
                                          brokenLoginItems: Int, anyScan: Bool) -> [Attention] {
        var rows: [Attention] = []
        if fullDisk == .denied || fullDisk == .undetermined { rows.append(.fullDiskAccessMissing) }
        if brokenLoginItems > 0 { rows.append(.brokenLoginItems(brokenLoginItems)) }
        if !anyScan { rows.append(.neverScanned) }
        return rows
    }

    /// The scans a person can run, with when each last ran. A scan event's
    /// summary starts with the module's stable name, which is how the app
    /// wrote it; anything else counts as "never" rather than guessed.
    nonisolated static func scanRows(from events: [ActivityRecord]) -> [Scan] {
        let scannable: [ModuleID] = [.cleanup, .spaceLens, .duplicates, .applications]
        return scannable.map { module in
            let last = events
                .filter { $0.kind == .scan && $0.summary.hasPrefix(module.rawValue) }
                .map(\.date).max()
            return Scan(module: module, lastRun: last)
        }
    }

    private static func mountedVolumes() -> [Volume] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey,
                                      .volumeAvailableCapacityForImportantUsageKey, .volumeIsInternalKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                          options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  let total = v.volumeTotalCapacity, total > 0 else { return nil }
            return Volume(url: url, name: v.volumeName ?? url.lastPathComponent,
                          total: Int64(total),
                          free: v.volumeAvailableCapacityForImportantUsage ?? 0)
        }
        .sorted { $0.total > $1.total }
    }
}

struct DashboardView: View {
    @State private var model = OverviewViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                if !model.volumes.isEmpty { diskSection }
                if !model.attention.isEmpty { attentionSection }
                if !model.recent.isEmpty { recentSection }
                scanSection
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: MCSize.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(L("module.overview"))
        .task { await model.load() }
    }

    // MARK: Disk

    private var diskSection: some View {
        section(L("overview.disk")) {
            ForEach(model.volumes) { volume in
                HStack(alignment: .firstTextBaseline, spacing: MCSpacing.md) {
                    Text(volume.name).font(MCFont.rowTitle)
                        .frame(width: 160, alignment: .leading).lineLimit(1)
                    usageBar(volume.usedFraction)
                    Text(L("overview.disk_free", mcFormatBytes(volume.free), mcFormatBytes(volume.total)))
                        .font(MCFont.tabular).foregroundStyle(MCColor.textSecondary)
                        .frame(width: 190, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L("overview.disk_a11y", volume.name,
                                      mcFormatBytes(volume.used), mcFormatBytes(volume.total)))
            }
        }
    }

    /// One bar, two colours: used and free. Teal is data here, not a control.
    private func usageBar(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(MCColor.separator)
                Capsule().fill(MCColor.teal).frame(width: max(2, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    // MARK: Attention

    private var attentionSection: some View {
        section(L("overview.attention")) {
            ForEach(model.attention) { item in
                HStack(spacing: MCSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(MCTheme.warning).accessibilityHidden(true)
                    Text(attentionText(item)).font(MCFont.body)
                    Spacer(minLength: MCSpacing.md)
                    Button(attentionAction(item)) { act(on: item) }
                        .buttonStyle(.bordered)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private func attentionText(_ item: OverviewViewModel.Attention) -> String {
        switch item {
        case .fullDiskAccessMissing: L("overview.attention_fda")
        case let .brokenLoginItems(n): L(n == 1 ? "overview.attention_login_one" : "overview.attention_login_other", n)
        case .neverScanned: L("overview.attention_never")
        }
    }

    private func attentionAction(_ item: OverviewViewModel.Attention) -> String {
        switch item {
        case .fullDiskAccessMissing: L("overview.action_open_settings")
        case .brokenLoginItems: L("overview.action_review")
        case .neverScanned: L("overview.action_open_cleanup")
        }
    }

    private func act(on item: OverviewViewModel.Attention) {
        switch item {
        case .fullDiskAccessMissing:
            if let url = SystemAuthorization.fullDiskAccessSettingsURL { NSWorkspace.shared.open(url) }
        case .brokenLoginItems:
            NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.protection)
        case .neverScanned:
            NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.cleanup)
        }
    }

    // MARK: Recent

    private var recentSection: some View {
        section(L("overview.recent"), trailing: {
            Button(L("overview.see_record")) {
                NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.record)
            }
            .buttonStyle(.borderless)
        }) {
            ForEach(model.recent) { item in
                HStack(alignment: .firstTextBaseline, spacing: MCSpacing.sm) {
                    Text(recentTitle(item)).font(MCFont.body).lineLimit(1)
                    Spacer(minLength: MCSpacing.md)
                    Text(AppDateFormatting.string(item.date, style: .dayMonthYearWithTime))
                        .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func recentTitle(_ item: RecordItem) -> String {
        switch item {
        case let .operation(entry): RecordPhrasing.title(entry)
        case let .event(record): "\(RecordPhrasing.eventTitle(record)) — \(record.summary)"
        }
    }

    // MARK: Scan

    private var scanSection: some View {
        section(L("overview.scans")) {
            ForEach(model.scans) { scan in
                HStack(spacing: MCSpacing.sm) {
                    Image(systemName: scan.module.systemImage)
                        .foregroundStyle(MCColor.textSecondary).frame(width: 20)
                        .accessibilityHidden(true)
                    Text(scan.module.label).font(MCFont.rowTitle)
                    Text(scan.lastRun.map { L("overview.last_run", AppDateFormatting.string($0, style: .dayMonthYearWithTime)) }
                         ?? L("overview.never_run"))
                        .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    Spacer(minLength: MCSpacing.md)
                    Button(L("overview.open")) {
                        NotificationCenter.default.post(name: .mcNavigate, object: scan.module)
                    }
                    .buttonStyle(.bordered)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    // MARK: Section — a label, a hairline, rows. No enclosure.

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        section(title, trailing: { EmptyView() }, content: content)
    }

    private func section<Trailing: View, Content: View>(
        _ title: String, @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            HStack {
                Text(title).font(MCFont.groupHeader).foregroundStyle(MCColor.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                trailing()
            }
            Divider()
            VStack(alignment: .leading, spacing: MCSpacing.xs) { content() }
                .padding(.top, MCSpacing.xxs)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
