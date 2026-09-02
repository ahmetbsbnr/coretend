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
final class MyClutterViewModel {
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

    private var scanTask: Task<Void, Never>?
    private var pauseController: ScanPauseController?

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
            let engine = ScanEngine()
            for await event in engine.run(rules: [rule], pauseController: pauseController) {
                switch event {
                case let .progress(scanned, _): scannedCount = scanned
                case let .finding(finding):
                    if findings.count < 2000 {
                        // Keep list sorted largest-first as results stream in.
                        let index = findings.firstIndex { $0.logicalSize < finding.logicalSize } ?? findings.count
                        findings.insert(finding, at: index)
                    }
                case .finished, .cancelled:
                    isScanPaused = false
                    phase = findings.isEmpty ? .empty : .results
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Large & Old scan: \(findings.count) files",
                        itemCount: findings.count, bytes: totalBytes))
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
        scanTask?.cancel()
        Task { await pauseController?.resume() }
    }
}

struct MyClutterView: View {
    @State private var tab = 0

    // Plain segmented sub-nav pinned via .safeAreaInset, not a TabView: a
    // TabView as a NavigationSplitView detail can blank the split view's
    // sidebar on macOS. Duplicates is a first-class tool in the Storage group
    // and is not re-exposed here — this hub covers what nothing else does:
    // large/old files and visually-similar images.
    var body: some View {
        Group {
            if tab == 0 { LargeOldFilesView() } else { SimilarImagesView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text(L("clutter.tab.large_old")).tag(0)
                    Text(L("clutter.tab.similar_images")).tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
                .padding(.vertical, MCSpacing.sm)
                Divider()
            }
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .navigationTitle(L("clutter.title"))
    }
}

struct LargeOldFilesView: View {
    @State private var model = MyClutterViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .idle: idleView
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
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .mcAppear()

                    MCScanButton(L("clutter.analyze"), systemImage: "doc.on.doc") { model.start() }
                        .keyboardShortcut(.defaultAction)
                        .mcAppear(delay: 0.06)

                    MCCard {
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
            HStack {
                if model.isScanPaused {
                    Button(L("common.resume")) { model.resume() }
                        .keyboardShortcut("r", modifiers: [])
                        .accessibilityHint(L("clutter.resume_hint"))
                } else {
                    Button(L("common.pause")) { model.pause() }
                        .keyboardShortcut("p", modifiers: [])
                        .accessibilityHint(L("clutter.pause_hint"))
                }
                Button(L("common.cancel")) { model.cancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: MCSpacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: MCIconSize.emptyState)).foregroundStyle(MCTheme.success)
                .accessibilityHidden(true)
            Text(L("clutter.no_matches")).font(.title3.weight(.semibold))
            Button(L("clutter.change_criteria")) { model.phase = .idle }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("clutter.results.summary", model.sortedFindings.count, mcFormatBytes(model.totalBytes)))
                    .font(MCFont.cardTitle)
                Spacer()
                Picker(L("clutter.sort_by"), selection: $model.sortOption) {
                    ForEach(MyClutterViewModel.SortOption.allCases) { option in
                        Text(option == .size ? L("clutter.sort.size") : L("clutter.sort.age")).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                Button(L("clutter.new_analysis")) { model.phase = .idle }
            }
            .padding()
            HStack {
                MCSearchField(text: $model.searchText, placeholder: L("clutter.search_placeholder"))
                if model.availableVolumes.count > 1 {
                    Picker(L("clutter.volume"), selection: $model.selectedVolumeID) {
                        Text(L("clutter.all_volumes")).tag(String?.none)
                        ForEach(model.availableVolumes) { volume in
                            Text(volume.id == VolumeInfo.unavailable.id ? L("clutter.volume_unavailable") : volume.name)
                                .tag(String?.some(volume.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }
                Spacer()
                ExclusionsMenu(controller: model.exclusionsController)
            }
            .padding(.horizontal).padding(.bottom, MCSpacing.xs)
            if model.sortedFindings.isEmpty {
                Spacer()
                Text(L("clutter.search_no_results"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
            List(model.sortedFindings) { finding in
                HStack {
                    Image(systemName: "doc")
                        .foregroundStyle(MCTheme.accentSecondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(finding.url.lastPathComponent)
                        HStack(spacing: MCSpacing.xs) {
                            Text(finding.url.deletingLastPathComponent().path)
                                .lineLimit(1).truncationMode(.middle)
                            if let date = finding.modificationDate {
                                Text(L("clutter.modified", date.formatted(date: .abbreviated, time: .omitted)))
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Large, legible metric number — this screen is
                    // primarily a data table, size is the number that matters.
                    Text(mcFormatBytes(finding.logicalSize))
                        .monospacedDigit().font(.title3.weight(.semibold))
                        .accessibilityHidden(true) // folded into the row's combined label below
                    Button {
                        model.previewURL = finding.url
                    } label: {
                        Image(systemName: "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(L("clutter.quick_look"))
                    .accessibilityLabel(L("clutter.quick_look"))
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([finding.url])
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .help(L("common.reveal_in_finder"))
                    .accessibilityLabel(L("common.reveal_in_finder"))
                    ExcludeButton(url: finding.url, controller: model.exclusionsController)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(finding.url.lastPathComponent), \(mcFormatBytes(finding.logicalSize))")
            }
            .listStyle(.inset)
            .quickLookPreview($model.previewURL)
        }
    }
}
