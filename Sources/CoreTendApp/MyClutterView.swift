// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import ScanCore
import SafetyCore
import DesignSystem
import Persistence
import QuickLookUI
import QuickLook

/// My Clutter — Large & Old Files. Read-only analysis: findings can be revealed
/// in Finder, never auto-deleted (user-content locations are out of the deletion
/// allowlist by design).
@MainActor
@Observable
final class MyClutterViewModel: CancellableScan {
    enum Phase: Equatable { case idle, scanning, results, empty }

    enum SortOption: String, CaseIterable, Identifiable {
        case size = "Size", age = "Age"
        var id: String { rawValue }
    }

    var phase: Phase = .idle
    var findings: [ScanFinding] = []
    var scannedCount = 0
    var minSizeMB: Int = 100
    var minAgeDays: Int = 30
    var sortOption: SortOption = .size
    var previewURL: URL?
    var searchText = ""
    var selectedVolumeID: String?
    var isScanPaused = false
    let volumeResolver: VolumeResolving
    let exclusionsController = ClutterExclusionsController()

    var scanTask: Task<Void, Never>?
    var pauseController: ScanPauseController?

    init(volumeResolver: VolumeResolving = SystemVolumeResolver()) {
        self.volumeResolver = volumeResolver
    }

    var totalBytes: Int64 { findings.reduce(0) { $0 + $1.logicalSize } }

    var availableVolumes: [VolumeInfo] {
        ClutterVolumeGrouping.availableVolumes(for: findings.map(\.url), resolver: volumeResolver)
    }

    /// Native sort over the same real findings — size (default, largest
    /// first) or age (oldest modification date first) — then narrowed by
    /// name search and the selected volume, if any.
    var sortedFindings: [ScanFinding] {
        let base: [ScanFinding]
        switch sortOption {
        case .size: base = findings.sorted { $0.logicalSize > $1.logicalSize }
        case .age:
            base = findings.sorted {
                ($0.modificationDate ?? .distantFuture) < ($1.modificationDate ?? .distantFuture)
            }
        }
        return base.filter {
            ClutterSearch.matches(fileName: $0.url.lastPathComponent, path: $0.url.path, query: searchText)
                && ClutterVolumeGrouping.matches($0.url, volumeID: selectedVolumeID, resolver: volumeResolver)
        }
    }

    func start() {
        guard phase != .scanning else { return }
        phase = .scanning
        findings = []
        scannedCount = 0
        isScanPaused = false
        let rule = ScanRule(
            id: "clutter.largeold",
            name: "Large & Old Files",
            category: "My Clutter",
            explanation: "Files larger than \(minSizeMB) MB not modified in \(minAgeDays)+ days.",
            minimumAgeDays: minAgeDays,
            risk: .high,
            preselect: false,
            minimumSizeBytes: Int64(minSizeMB) * 1_000_000
        ) { home in
            ["Downloads", "Documents", "Desktop", "Movies", "Music", "Pictures"].map {
                home.appendingPathComponent($0)
            }
        }
        let pauseController = ScanPauseController()
        self.pauseController = pauseController
        scanTask = Task {
            let engine = ScanEngine(configuration: ScanConfiguration(home: CaptureHarness.scanHome))
            for await event in engine.run(rules: [rule], pauseController: pauseController) {
                switch event {
                case let .progress(scanned, _): scannedCount = scanned
                case let .finding(finding):
                    if findings.count < 2000 {
                        // Keep list sorted largest-first as results stream in.
                        let index = findings.firstIndex { $0.logicalSize < finding.logicalSize } ?? findings.count
                        findings.insert(finding, at: index)
                    }
                case .finished:
                    isScanPaused = false
                    phase = findings.isEmpty ? .empty : .results
                    CaptureHarness.note(state: findings.isEmpty ? "empty" : "results")
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Large & Old scan: \(findings.count) files",
                        itemCount: findings.count, bytes: totalBytes))
                case .cancelled:
                    // Normally unreachable — see CancellableScan. Deliberately
                    // records nothing: a cancelled scan is a partial result and
                    // must not appear in Activity as a completed one.
                    isScanPaused = false
                    phase = findings.isEmpty ? .idle : .results
                default: break
                }
            }
            self.pauseController = nil
        }
    }

    func pause() {
        guard phase == .scanning, !isScanPaused else { return }
        isScanPaused = true
        Task { await pauseController?.pause() }
    }

    func resume() {
        guard phase == .scanning, isScanPaused else { return }
        isScanPaused = false
        Task { await pauseController?.resume() }
    }

    func cancel() {
        isScanPaused = false
        cancelScanning()
    }

    func resetPhaseAfterCancellation() {
        if phase == .scanning { phase = findings.isEmpty ? .idle : .results }
    }
}


struct LargeOldFilesView: ModuleSubScreen {
    static let parent = ModuleID.spaceLens
    static let labelKey = "clutter.tab.large_old"

    @State private var model = MyClutterViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .idle: idleView.onAppear { if CaptureHarness.autostartScan { model.start() } }
            case .scanning: scanningView
            case .empty: emptyView
            case .results: resultsView
            }
        }
    }

    private var idleView: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: MCSpacing.xl) {
                    VStack(spacing: MCSpacing.xs) {
                        Text(L("clutter.idle.title")).font(MCFont.pageTitle)
                            .multilineTextAlignment(.center)
                        Text(L("clutter.idle.subtitle"))
                            .font(MCFont.secondaryBody)
                            .multilineTextAlignment(.center).foregroundStyle(MCColor.textSecondary)
                            .lineLimit(3)
                    }
                    .mcAppear()

                    MCScanButton(L("clutter.analyze"), systemImage: "doc.on.doc") { model.start() }
                        .keyboardShortcut(.defaultAction)
                        .mcAppear(delay: 0.06)

                    VStack(alignment: .leading, spacing: MCSpacing.sm) {
                        HStack(spacing: MCSpacing.lg) {
                            LabeledContent(L("clutter.larger_than")) {
                                Picker("", selection: $model.minSizeMB) {
                                    Text(L("clutter.size.50mb")).tag(50)
                                    Text(L("clutter.size.100mb")).tag(100)
                                    Text(L("clutter.size.500mb")).tag(500)
                                    Text(L("clutter.size.1gb")).tag(1000)
                                }
                                .pickerStyle(.menu).labelsHidden().fixedSize()
                            }
                            LabeledContent(L("clutter.older_than")) {
                                Picker("", selection: $model.minAgeDays) {
                                    Text(L("clutter.age.30d")).tag(30)
                                    Text(L("clutter.age.90d")).tag(90)
                                    Text(L("clutter.age.180d")).tag(180)
                                    Text(L("clutter.age.1y")).tag(365)
                                }
                                .pickerStyle(.menu).labelsHidden().fixedSize()
                            }
                        }
                    }
                    .frame(maxWidth: 480)
                    .mcAppear(delay: 0.12)
                }
                .padding(MCSpacing.page)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
            }
        }
    }

    private var scanningView: some View {
        VStack(spacing: MCSpacing.md) {
            ProgressView()
            Text(L("clutter.scanning_progress", model.scannedCount, model.findings.count))
                .monospacedDigit()
            MCScanControls(
                identifierPrefix: "clutter",
                isPaused: model.isScanPaused,
                pauseHintKey: "clutter.pause_hint",
                resumeHintKey: "clutter.resume_hint",
                onPause: { model.pause() },
                onResume: { model.resume() },
                onCancel: { model.cancel() })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: MCSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: MCIconSize.emptyState)).foregroundStyle(MCTheme.success)
                .accessibilityHidden(true)
            Text(L("clutter.no_matches")).font(MCFont.actionLabel)
            Button(L("clutter.change_criteria")) { model.phase = .idle }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// One line per file: name, folder, when it was last touched, size. The
    /// sentence on top says how many and how much; sort and volume sit beside
    /// the search. Rows were three lines with the size in title type, which
    /// made a list of two hundred files a scroll of two hundred headlines.
    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: MCSpacing.sm) {
                Text(L("clutter.results.summary", model.sortedFindings.count, mcFormatBytes(model.totalBytes)))
                    .font(MCFont.body)
                Spacer()
                Picker(L("clutter.sort_by"), selection: $model.sortOption) {
                    ForEach(MyClutterViewModel.SortOption.allCases) { option in
                        Text(option == .size ? L("clutter.sort.size") : L("clutter.sort.age")).tag(option)
                    }
                }
                .pickerStyle(.menu).fixedSize()
                Button(L("clutter.new_analysis")) { model.phase = .idle }.buttonStyle(.bordered)
            }
            .padding(.horizontal, MCSpacing.page).padding(.vertical, MCSpacing.sm)
            Divider()
            HStack(spacing: MCSpacing.xs) {
                MCSearchField(text: $model.searchText, placeholder: L("clutter.search_placeholder"))
                if model.availableVolumes.count > 1 {
                    Picker(L("clutter.volume"), selection: $model.selectedVolumeID) {
                        Text(L("clutter.all_volumes")).tag(String?.none)
                        ForEach(model.availableVolumes) { volume in
                            Text(volume.id == VolumeInfo.unavailable.id ? L("clutter.volume_unavailable") : volume.name)
                                .tag(String?.some(volume.id))
                        }
                    }
                    .pickerStyle(.menu).labelsHidden().frame(width: 140)
                }
                Spacer(minLength: 0)
                ExclusionsMenu(controller: model.exclusionsController)
            }
            .padding(.horizontal, MCSpacing.sm).padding(.vertical, MCSpacing.xs)
            Divider()
            if model.sortedFindings.isEmpty {
                MCEmptyState(icon: "line.3.horizontal.decrease", title: L("clutter.search_no_results"), message: "")
            } else {
                List(model.sortedFindings) { finding in
                    HStack(spacing: MCSpacing.xs) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: finding.url.path))
                            .resizable().frame(width: 16, height: 16).accessibilityHidden(true)
                        Text(finding.url.lastPathComponent).lineLimit(1)
                        Text(PathDisplay.folder(of: finding.url))
                            .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: MCSpacing.xs)
                        if let date = finding.modificationDate {
                            Text(AppDateFormatting.string(date, style: .dayMonthYear))
                                .font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
                        }
                        Text(mcFormatBytes(finding.logicalSize)).font(MCFont.tabular)
                            .frame(width: 80, alignment: .trailing)
                        ExcludeButton(url: finding.url, controller: model.exclusionsController)
                    }
                    .fileRowActions(FileRowAction.inspection(for: finding.url) { model.previewURL = $0 })
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(finding.url.lastPathComponent), \(mcFormatBytes(finding.logicalSize))")
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 28)
                .quickLookPreview($model.previewURL)
                .scanCommands(
                    start: { model.start() },
                    pauseOrResume: { model.isScanPaused ? model.resume() : model.pause() },
                    cancel: { model.cancel() })
            }
        }
    }
}
