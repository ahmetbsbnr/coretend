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

    private var scanTask: Task<Void, Never>?

    var totalBytes: Int64 { findings.reduce(0) { $0 + $1.logicalSize } }

    /// Native sort over the same real findings — size (default, largest
    /// first) or age (oldest modification date first).
    var sortedFindings: [ScanFinding] {
        switch sortOption {
        case .size: return findings.sorted { $0.logicalSize > $1.logicalSize }
        case .age:
            return findings.sorted {
                ($0.modificationDate ?? .distantFuture) < ($1.modificationDate ?? .distantFuture)
            }
        }
    }

    func start() {
        guard phase != .scanning else { return }
        phase = .scanning
        findings = []
        scannedCount = 0
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
        scanTask = Task {
            let engine = ScanEngine()
            for await event in engine.run(rules: [rule]) {
                switch event {
                case let .progress(scanned, _): scannedCount = scanned
                case let .finding(finding):
                    if findings.count < 2000 {
                        // Keep list sorted largest-first as results stream in.
                        let index = findings.firstIndex { $0.logicalSize < finding.logicalSize } ?? findings.count
                        findings.insert(finding, at: index)
                    }
                case .finished, .cancelled:
                    phase = findings.isEmpty ? .empty : .results
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Large & Old scan: \(findings.count) files",
                        itemCount: findings.count, bytes: totalBytes, dryRun: true))
                default: break
                }
            }
        }
    }

    func cancel() { scanTask?.cancel() }
}

struct MyClutterView: View {
    var body: some View {
        TabView {
            LargeOldFilesView()
                .tabItem { Label(L("clutter.tab.large_old"), systemImage: "doc") }
            DuplicatesView()
                .tabItem { Label(L("clutter.tab.duplicates"), systemImage: "doc.on.doc") }
            SimilarImagesView()
                .tabItem { Label(L("clutter.tab.similar_images"), systemImage: "photo.on.rectangle.angled") }
        }
        .padding(8)
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
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: MCIconSize.emptyStateProminent)).foregroundStyle(MCTheme.accent)
                .accessibilityHidden(true)
            Text(L("clutter.idle.title")).font(.title2.weight(.semibold))
            Text(L("clutter.idle.subtitle"))
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Picker(L("clutter.larger_than"), selection: $model.minSizeMB) {
                    Text(L("clutter.size.50mb")).tag(50)
                    Text(L("clutter.size.100mb")).tag(100)
                    Text(L("clutter.size.500mb")).tag(500)
                    Text(L("clutter.size.1gb")).tag(1000)
                }
                .frame(width: 180)
                Picker(L("clutter.older_than"), selection: $model.minAgeDays) {
                    Text(L("clutter.age.30d")).tag(30)
                    Text(L("clutter.age.90d")).tag(90)
                    Text(L("clutter.age.180d")).tag(180)
                    Text(L("clutter.age.1y")).tag(365)
                }
                .frame(width: 180)
            }
            Button(L("clutter.analyze")) { model.start() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(L("clutter.scanning_progress", model.scannedCount, model.findings.count))
                .monospacedDigit()
            Button(L("common.cancel")) { model.cancel() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
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
                Text(L("clutter.results.summary", model.findings.count, mcFormatBytes(model.totalBytes)))
                    .font(.headline)
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
            List(model.sortedFindings) { finding in
                HStack {
                    Image(systemName: "doc")
                        .foregroundStyle(MCTheme.accentSecondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(finding.url.lastPathComponent)
                        HStack(spacing: 8) {
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
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(finding.url.lastPathComponent), \(mcFormatBytes(finding.logicalSize))")
            }
            .listStyle(.inset)
            .quickLookPreview($model.previewURL)
        }
    }
}
