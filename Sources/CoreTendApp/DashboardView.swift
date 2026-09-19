// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import Persistence
import DesignSystem

/// Overview: the state of this Mac, what needs a person, what changed, and
/// what can be run next.
///
/// Composed after the design reference — header, a row of metrics, a storage
/// panel with a proportional bar, a dense recent list, and a context column at
/// large width. The figures are not the reference's. It showed "Storage
/// Reclaimable" and a five-way category split of a whole volume; neither is
/// something this app can measure, and printing them would be the defect this
/// product was rebuilt to remove. What each tile shows is a quantity macOS
/// reported or CoreTend recorded when it did the work.
@MainActor
@Observable
final class OverviewViewModel {
    struct Volume: Identifiable {
        let url: URL
        let name: String
        let isInternal: Bool
        let breakdown: OverviewFacts.VolumeBreakdown
        var id: String { url.path }
        var total: Int64 { breakdown.total }
        var free: Int64 { breakdown.free }
        var used: Int64 { breakdown.used }
        var usedFraction: Double { breakdown.usedFraction }
    }

    enum Attention: Identifiable, Equatable {
        case fullDiskAccessMissing
        case brokenLoginItems(Int)
        case neverScanned
        case scansAreStale(days: Int)
        var id: String {
            switch self {
            case .fullDiskAccessMissing: "fda"
            case .brokenLoginItems: "login"
            case .neverScanned: "never"
            case .scansAreStale: "stale"
            }
        }
    }

    private(set) var volumes: [Volume] = []
    private(set) var attention: [Attention] = []
    private(set) var recent: [RecordItem] = []
    private(set) var scans: [OverviewFacts.ScanResult] = []
    private(set) var recordSummary = SafetyLedger.Summary()
    private(set) var lastScanDate: Date?
    var selectedVolumeID: String?

    var selectedVolume: Volume? {
        volumes.first { $0.id == selectedVolumeID } ?? volumes.first
    }

    func scan(for module: ModuleID) -> OverviewFacts.ScanResult? {
        scans.first { $0.module == module }
    }

    func load() async {
        let events = (try? await AppEnvironment.shared.store?.activity(limit: 500)) ?? []
        scans = OverviewFacts.lastScans(from: events)
        lastScanDate = scans.map(\.date).max()
        let cleanupFound = scan(for: .cleanup)?.bytes
        volumes = Self.mountedVolumes(cleanupFound: cleanupFound)
        if selectedVolumeID == nil { selectedVolumeID = volumes.first?.id }

        let entries = SafetyLedger.entries(from: (try? await AppEnvironment.shared.store?.safetyLog(limit: 400)) ?? [])
        recordSummary = SafetyLedger.summary(of: entries)
        recent = Array(SafetyLedger.items(operations: entries, events: events).prefix(6))

        attention = Self.attentionRows(
            fullDisk: SystemAuthorization.probeLive().grant(for: .fullDisk),
            brokenLoginItems: LaunchAgentInspector.userAgents().filter(\.broken).count,
            lastScan: lastScanDate)
    }

    /// Only what needs a person. Everything fine → nothing listed, and the
    /// section disappears rather than saying "all good" in green.
    nonisolated static func attentionRows(fullDisk: SystemAuthorization.Grant,
                                          brokenLoginItems: Int,
                                          lastScan: Date?,
                                          now: Date = Date()) -> [Attention] {
        var rows: [Attention] = []
        if fullDisk == .denied || fullDisk == .undetermined { rows.append(.fullDiskAccessMissing) }
        if brokenLoginItems > 0 { rows.append(.brokenLoginItems(brokenLoginItems)) }
        guard let lastScan else { return rows + [.neverScanned] }
        // Midnight to midnight, which is what a person means by "N days ago".
        // Counting instant to instant loses a day whenever the clocks go back
        // inside the window: a scan thirty days old reported 29.
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: lastScan),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        if days >= 7 { rows.append(.scansAreStale(days: days)) }
        return rows
    }

    private static func mountedVolumes(cleanupFound: Int64?) -> [Volume] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey,
                                      .volumeAvailableCapacityForImportantUsageKey, .volumeIsInternalKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                          options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  let total = v.volumeTotalCapacity, total > 0 else { return nil }
            let isInternal = v.volumeIsInternal ?? false
            return Volume(url: url, name: v.volumeName ?? url.lastPathComponent,
                          isInternal: isInternal,
                          breakdown: .init(total: Int64(total),
                                           free: v.volumeAvailableCapacityForImportantUsage ?? 0,
                                           // The scan covered this Mac's home
                                           // folder, which is on the internal
                                           // volume. Drawing it on an external
                                           // disk would put a real number in
                                           // the wrong place.
                                           foundByLastScan: isInternal ? cleanupFound : nil))
        }
        .sorted { $0.total > $1.total }
    }
}

struct DashboardView: View {
    @State private var model = OverviewViewModel()

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                let wide = proxy.size.width >= 1150
                HStack(alignment: .top, spacing: MCSpacing.lg) {
                    VStack(alignment: .leading, spacing: MCSpacing.lg) {
                        header
                        metrics
                        storageSection
                        if !model.attention.isEmpty { attentionSection }
                        recentSection
                    }
                    .frame(maxWidth: wide ? .infinity : MCSize.readableWidth, alignment: .leading)
                    if wide, let volume = model.selectedVolume {
                        VolumeContextColumn(volume: volume, scans: model.scans)
                            .frame(width: 280)
                    }
                }
                .padding(MCSpacing.page)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle(L("module.overview"))
        .task { await model.load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("module.overview")).font(MCFont.heroTitle)
                Text(L("overview.subtitle")).font(MCFont.body)
                    .foregroundStyle(MCColor.textSecondary)
            }
            Spacer(minLength: MCSpacing.md)
            VStack(alignment: .trailing, spacing: 2) {
                Text(L("overview.last_scan")).font(MCFont.groupHeader)
                    .foregroundStyle(MCColor.textSecondary).textCase(.uppercase)
                Text(model.lastScanDate.map { AppDateFormatting.string($0, style: .dayMonthYearWithTime) }
                     ?? L("overview.never_run"))
                    .font(MCFont.rowTitle)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Metrics

    /// Four figures, each one a thing that was measured. The tiles navigate,
    /// so a number is also a way into the module that produced it.
    private var metrics: some View {
        let volume = model.selectedVolume
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: MCSpacing.sm) { metricTiles(volume) }
            VStack(spacing: MCSpacing.xs) { metricTiles(volume) }
        }
    }

    @ViewBuilder
    private func metricTiles(_ volume: OverviewViewModel.Volume?) -> some View {
        MetricTile(icon: "internaldrive",
                   label: L("overview.metric_free"),
                   value: volume.map { mcFormatBytes($0.free) },
                   detail: volume.map { L("overview.metric_free_detail", mcFormatBytes($0.total)) } ?? "",
                   destination: nil)
        MetricTile(icon: ModuleID.cleanup.systemImage,
                   label: L("overview.metric_cleanup"),
                   value: model.scan(for: .cleanup).map { mcFormatBytes($0.bytes) },
                   detail: scanDetail(.cleanup),
                   destination: .cleanup)
        MetricTile(icon: ModuleID.duplicates.systemImage,
                   label: L("overview.metric_duplicates"),
                   value: model.scan(for: .duplicates).map { mcFormatBytes($0.bytes) },
                   detail: scanDetail(.duplicates),
                   destination: .duplicates)
        MetricTile(icon: ModuleID.record.systemImage,
                   label: L("overview.metric_record"),
                   value: mcFormatBytes(model.recordSummary.movedBytes),
                   detail: L("overview.metric_record_detail", model.recordSummary.movedItems),
                   destination: .record)
    }

    /// "at the last scan, 3 days ago" — never a bare number, because the
    /// figure is a finding from a moment, not a current state.
    private func scanDetail(_ module: ModuleID) -> String {
        guard let scan = model.scan(for: module) else { return L("overview.never_run") }
        return L("overview.metric_found_detail", scan.itemCount,
                 AppDateFormatting.string(scan.date, style: .dayMonthYear))
    }

    // MARK: Storage

    private var storageSection: some View {
        MCPanel(title: L("overview.disk"), subtitle: L("overview.disk_subtitle")) {
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                ForEach(model.volumes) { volume in
                    VolumeRow(volume: volume,
                              isSelected: volume.id == model.selectedVolume?.id,
                              isSelectable: model.volumes.count > 1,
                              cleanupScanDate: model.scan(for: .cleanup)?.date) {
                        model.selectedVolumeID = volume.id
                    }
                }
            }
        }
    }

    // MARK: Attention

    private var attentionSection: some View {
        MCPanel(title: L("overview.attention"), subtitle: nil) {
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
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
    }

    private func attentionText(_ item: OverviewViewModel.Attention) -> String {
        switch item {
        case .fullDiskAccessMissing: L("overview.attention_fda")
        case let .brokenLoginItems(n): L(n == 1 ? "overview.attention_login_one" : "overview.attention_login_other", n)
        case .neverScanned: L("overview.attention_never")
        case let .scansAreStale(days): L("overview.attention_stale", days)
        }
    }

    private func attentionAction(_ item: OverviewViewModel.Attention) -> String {
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

    // MARK: Recent

    private var recentSection: some View {
        MCPanel(title: L("overview.recent"), subtitle: nil, trailing: {
            Button(L("overview.see_record")) {
                NotificationCenter.default.post(name: .mcNavigate, object: ModuleID.record)
            }
            .buttonStyle(.borderless)
        }) {
            if model.recent.isEmpty {
                Text(L("record.empty_message")).font(MCFont.caption)
                    .foregroundStyle(MCColor.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.recent) { item in
                        RecentRow(item: item)
                        if item.id != model.recent.last?.id { Divider() }
                    }
                }
            }
        }
    }
}
