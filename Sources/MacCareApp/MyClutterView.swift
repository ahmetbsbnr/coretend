import SwiftUI
import ScanCore
import SafetyCore
import DesignSystem
import Persistence
import QuickLookUI

/// My Clutter — Large & Old Files. Read-only analysis: findings can be revealed
/// in Finder, never auto-deleted (user-content locations are out of the deletion
/// allowlist by design).
@MainActor
@Observable
final class MyClutterViewModel {
    enum Phase: Equatable { case idle, scanning, results, empty }

    var phase: Phase = .idle
    var findings: [ScanFinding] = []
    var scannedCount = 0
    var minSizeMB: Int = 100
    var minAgeDays: Int = 30

    private var scanTask: Task<Void, Never>?

    var totalBytes: Int64 { findings.reduce(0) { $0 + $1.logicalSize } }

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
                .tabItem { Label("Large & Old", systemImage: "doc") }
            DuplicatesView()
                .tabItem { Label("Duplicates", systemImage: "doc.on.doc") }
        }
        .padding(8)
        .navigationTitle("My Clutter")
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
                .font(.system(size: 56)).foregroundStyle(MCTheme.accent)
            Text("Find large, forgotten files").font(.title2.weight(.semibold))
            Text("Analyzes Downloads, Documents, Desktop and media folders.\nNothing is ever deleted automatically — you review and act in Finder.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Picker("Larger than", selection: $model.minSizeMB) {
                    Text("50 MB").tag(50)
                    Text("100 MB").tag(100)
                    Text("500 MB").tag(500)
                    Text("1 GB").tag(1000)
                }
                .frame(width: 180)
                Picker("Older than", selection: $model.minAgeDays) {
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("180 days").tag(180)
                    Text("1 year").tag(365)
                }
                .frame(width: 180)
            }
            Button("Analyze") { model.start() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Scanned \(model.scannedCount) items — \(model.findings.count) matches")
                .monospacedDigit()
            Button("Cancel") { model.cancel() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48)).foregroundStyle(MCTheme.success)
            Text("No matching files").font(.title3.weight(.semibold))
            Button("Change Criteria") { model.phase = .idle }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(model.findings.count) files — \(mcFormatBytes(model.totalBytes))")
                    .font(.headline)
                Spacer()
                Button("New Analysis") { model.phase = .idle }
            }
            .padding()
            List(model.findings) { finding in
                HStack {
                    Image(systemName: "doc")
                        .foregroundStyle(MCTheme.accentSecondary)
                    VStack(alignment: .leading) {
                        Text(finding.url.lastPathComponent)
                        HStack(spacing: 8) {
                            Text(finding.url.deletingLastPathComponent().path)
                                .lineLimit(1).truncationMode(.middle)
                            if let date = finding.modificationDate {
                                Text("modified \(date.formatted(date: .abbreviated, time: .omitted))")
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(mcFormatBytes(finding.logicalSize))
                        .monospacedDigit().font(.callout.weight(.medium))
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([finding.url])
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .help("Reveal in Finder")
                }
            }
            .listStyle(.inset)
        }
    }
}
