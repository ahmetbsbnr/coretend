// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import SystemMetrics
import DesignSystem

@MainActor
@Observable
final class APFSIntelligenceViewModel {
    private(set) var volume: APFSVolumeInfo?
    private(set) var filesAnalyzed: APFSFilesAnalyzed?

    func load() async {
        volume = APFSIntelligenceService.volumeInfo()
        filesAnalyzed = await APFSIntelligenceService.filesAnalyzed(store: AppEnvironment.shared.store)
    }
}

struct APFSIntelligenceView: View {
    @State private var model = APFSIntelligenceViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                if let volume = model.volume {
                    volumeCard(volume)
                    if !volume.isAPFS {
                        notAPFSNotice(volume)
                    }
                    filesAnalyzedCard
                    storageSemanticsSection
                    snapshotsSection
                    measurementLimitationsSection(volume)
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(L("apfs.title"))
        .accessibilityIdentifier("apfs.root")
        .task { await model.load() }
    }

    // MARK: - Volume

    private func volumeCard(_ volume: APFSVolumeInfo) -> some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                Text(volume.name).font(MCFont.pageTitle)
                metricRow(L("apfs.capacity"), metric: volume.totalCapacity)
                metricRow(L("apfs.available"), metric: volume.availableCapacity)
                metricRow(L("apfs.available_important_usage"), metric: volume.availableCapacityForImportantUsage)
                metricRow(L("apfs.available_opportunistic_usage"), metric: volume.availableCapacityForOpportunisticUsage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    private func notAPFSNotice(_ volume: APFSVolumeInfo) -> some View {
        Label(L("apfs.not_apfs", volume.filesystemTypeRaw), systemImage: "info.circle")
            .font(MCFont.secondaryBody)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("apfs.not_apfs_notice")
    }

    private func metricRow(_ label: String, metric: APFSMetric<Int64>) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: MCSpacing.sm)
            switch metric {
            case let .measured(bytes):
                Text(mcFormatBytes(bytes)).monospacedDigit()
            case .unavailable:
                Text(L("apfs.unavailable")).foregroundStyle(.tertiary).italic()
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Files analyzed (from the last Cleanup scan already in Timeline)

    private var filesAnalyzedCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                MCSectionHeader(L("apfs.files_analyzed"))
                if let analyzed = model.filesAnalyzed {
                    HStack {
                        Text(L("apfs.logical")).foregroundStyle(.secondary)
                        Spacer(minLength: MCSpacing.sm)
                        Text(mcFormatBytes(analyzed.logicalBytes)).monospacedDigit()
                    }
                    HStack {
                        Text(L("apfs.physical")).foregroundStyle(.secondary)
                        Spacer(minLength: MCSpacing.sm)
                        if let physical = analyzed.physicalBytes {
                            Text(mcFormatBytes(physical)).monospacedDigit()
                        } else {
                            Text(L("apfs.unavailable")).foregroundStyle(.tertiary).italic()
                        }
                    }
                    Text(L("apfs.files_analyzed.as_of", analyzed.scanDate.formatted(date: .abbreviated, time: .shortened)))
                        .font(MCFont.caption).foregroundStyle(.tertiary)
                } else {
                    Text(L("apfs.files_analyzed.no_scan"))
                        .font(MCFont.secondaryBody).foregroundStyle(.secondary)
                    Button(L("apfs.files_analyzed.run_cleanup")) { navigate(.cleanup) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("apfs.run_cleanup")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Storage semantics (concept explainers — informational only)

    private var storageSemanticsSection: some View {
        VStack(alignment: .leading, spacing: MCSpacing.sm) {
            MCSectionHeader(L("apfs.semantics.title"))
            conceptCard(title: L("apfs.semantics.logical_physical.title"),
                       body: L("apfs.semantics.logical_physical.body"))
            conceptCard(title: L("apfs.semantics.available.title"), body: L("apfs.semantics.available.body"))
            conceptCard(title: L("apfs.semantics.sharing.title"), body: L("apfs.semantics.sharing.body"))
        }
    }

    private func conceptCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(MCFont.cardTitle)
            Text(body).font(MCFont.secondaryBody).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Snapshots (concept only — no listing in this version)

    private var snapshotsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            MCSectionHeader(L("apfs.snapshots.title"))
            Text(L("apfs.snapshots.concept")).font(MCFont.secondaryBody).foregroundStyle(.secondary)
            Text(L("apfs.snapshots.not_listed")).font(MCFont.caption).foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("apfs.snapshots")
    }

    // MARK: - Measurement limitations

    private func measurementLimitationsSection(_ volume: APFSVolumeInfo) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.xxs) {
            MCSectionHeader(L("apfs.limitations.title"))
            if case let .unavailable(reason) = volume.totalCapacity {
                limitationRow(L("apfs.capacity"), reason: reason)
            }
            if case let .unavailable(reason) = volume.availableCapacity {
                limitationRow(L("apfs.available"), reason: reason)
            }
            if model.filesAnalyzed?.physicalBytes == nil {
                limitationRow(L("apfs.physical"),
                              reason: model.filesAnalyzed == nil
                                ? L("apfs.limitations.no_scan_reason") : L("apfs.limitations.partial_reason"))
            }
            limitationRow(L("apfs.limitations.clones_label"), reason: L("apfs.limitations.clones_reason"))
            limitationRow(L("apfs.limitations.snapshot_size_label"), reason: L("apfs.limitations.snapshot_size_reason"))
        }
    }

    private func limitationRow(_ label: String, reason: String) -> some View {
        HStack(alignment: .top, spacing: MCSpacing.xs) {
            Image(systemName: "info.circle").foregroundStyle(.secondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(MCFont.secondaryBody)
                Text(reason).font(MCFont.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func navigate(_ module: ModuleID) {
        NotificationCenter.default.post(name: .mcNavigate, object: module)
    }
}
