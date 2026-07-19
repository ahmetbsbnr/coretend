import SwiftUI
import ScanCore
import SafetyCore
import FileRules
import DesignSystem

@MainActor
@Observable
final class CleanupViewModel {
    enum Phase: Equatable {
        case idle, scanning, review, running, done(freed: Int64, dryRun: Bool), failed(String)
    }

    var phase: Phase = .idle
    var findings: [ScanFinding] = []
    var selectedIDs: Set<UUID> = []
    var scannedCount = 0
    var totalBytes: Int64 = 0
    var dryRun = true

    private var scanTask: Task<Void, Never>?

    var selectedBytes: Int64 {
        findings.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.logicalSize }
    }

    func startScan() {
        guard phase != .scanning else { return }
        phase = .scanning
        findings = []
        selectedIDs = []
        scannedCount = 0
        totalBytes = 0
        let engine = ScanEngine()
        scanTask = Task {
            for await event in engine.run(rules: UserCleanupRules.all) {
                switch event {
                case .started: break
                case let .progress(scanned, _):
                    scannedCount = scanned
                case let .finding(finding):
                    // ponytail: cap displayed findings at 5000 to bound memory; paginate later.
                    if findings.count < 5000 {
                        findings.append(finding)
                        if finding.preselected { selectedIDs.insert(finding.id) }
                    }
                    totalBytes += finding.logicalSize
                case .error: break
                case let .finished(scanned, bytes):
                    scannedCount = scanned
                    totalBytes = bytes
                    phase = .review
                case .cancelled:
                    phase = .idle
                }
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    func runCleanup() {
        guard phase == .review else { return }
        phase = .running
        let selected = findings.filter { selectedIDs.contains($0.id) }
        let isDryRun = dryRun
        Task {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let validator = PathValidator(allowedRoots: UserCleanupRules.allowedRoots(home: home))
            let center = SafetyCenter(validator: validator, dryRun: isDryRun)
            var approved: [ApprovedFileOperation] = []
            for finding in selected {
                if let op = try? await center.approve(
                    url: finding.url, logicalSize: finding.logicalSize,
                    ruleID: finding.ruleID, risk: finding.risk
                ) {
                    approved.append(op)
                }
            }
            let result = await center.execute(approved)
            let freed = result.executed.reduce(0) { $0 + $1.logicalSize }
            phase = .done(freed: freed, dryRun: result.wasDryRun)
        }
    }
}

struct CleanupView: View {
    @State private var model = CleanupViewModel()

    var body: some View {
        VStack(spacing: 16) {
            switch model.phase {
            case .idle:
                idleView
            case .scanning:
                scanningView
            case .review, .running:
                reviewView
            case let .done(freed, dryRun):
                doneView(freed: freed, dryRun: dryRun)
            case let .failed(message):
                Text("Cleanup failed: \(message)").foregroundStyle(MCTheme.danger)
            }
        }
        .padding(24)
        .navigationTitle("Cleanup")
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(MCTheme.accent)
            Text("Scan for safe-to-remove files").font(.title2.weight(.semibold))
            Text("Scans user caches, logs, crash reports and Xcode build data.\nNothing is deleted during a scan.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Start Scan") { model.startScan() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Scanned \(model.scannedCount) items — \(mcFormatBytes(model.totalBytes)) found")
                .monospacedDigit()
            Button("Cancel") { model.cancelScan() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reviewView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(model.findings.count) items — \(mcFormatBytes(model.selectedBytes)) selected")
                    .font(.headline)
                Spacer()
                Toggle("Dry run", isOn: $model.dryRun).toggleStyle(.switch)
                Button(model.dryRun ? "Simulate Cleanup" : "Move to Trash") {
                    model.runCleanup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.phase == .running || model.selectedIDs.isEmpty)
            }
            List(model.findings) { finding in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { model.selectedIDs.contains(finding.id) },
                        set: { on in
                            if on { model.selectedIDs.insert(finding.id) }
                            else { model.selectedIDs.remove(finding.id) }
                        }
                    ))
                    .labelsHidden()
                    VStack(alignment: .leading) {
                        Text(finding.url.lastPathComponent)
                        Text(finding.url.deletingLastPathComponent().path)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Text(mcFormatBytes(finding.logicalSize))
                        .monospacedDigit().foregroundStyle(.secondary)
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

    private func doneView(freed: Int64, dryRun: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(MCTheme.success)
            Text(dryRun
                 ? "Dry run: \(mcFormatBytes(freed)) would be moved to Trash"
                 : "\(mcFormatBytes(freed)) moved to Trash")
                .font(.title3.weight(.semibold))
            Button("Scan Again") { model.startScan() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
