import SwiftUI
import MalwareEngine
import DesignSystem
import Persistence
import UniformTypeIdentifiers

@MainActor
@Observable
final class ProtectionViewModel {
    enum Phase: Equatable { case idle, scanning, results, failed(String) }

    var phase: Phase = .idle
    var scanner = ClamAVScanner()
    var findings: [MalwareFinding] = []
    var lastScanInfo: String?
    var quarantineItems: [Quarantine.Item] = []
    var statusMessage: String?

    private var quarantine: Quarantine? = try? Quarantine(directory: (try? Quarantine.defaultDirectory()) ?? FileManager.default.temporaryDirectory.appendingPathComponent("MacCareQuarantine"))

    func refreshQuarantine() async {
        guard let quarantine else { return }
        quarantineItems = await quarantine.items()
    }

    func scan(paths: [URL]) async {
        guard scanner.isAvailable else { return }
        phase = .scanning
        findings = []
        statusMessage = nil
        do {
            let result = try await scanner.scan(paths: paths)
            findings = result.findings
            lastScanInfo = "Scanned \(paths.map(\.lastPathComponent).joined(separator: ", ")) in \(String(format: "%.1f", result.duration))s — \(result.findings.count) threats"
            phase = .results
            AppEnvironment.shared.record(ActivityRecord(
                kind: result.findings.isEmpty ? .scan : .error,
                summary: "Malware scan: \(result.findings.count) findings",
                itemCount: result.findings.count, bytes: 0, dryRun: false))
        } catch {
            phase = .failed("Scan failed: \(error)")
        }
    }

    func quarantineFinding(_ finding: MalwareFinding) async {
        guard let quarantine else { return }
        do {
            _ = try await quarantine.quarantine(fileAt: URL(fileURLWithPath: finding.path),
                                                signature: finding.signature)
            findings.removeAll { $0.id == finding.id }
            statusMessage = "Moved to quarantine: \(finding.path)"
            await refreshQuarantine()
        } catch {
            statusMessage = "Quarantine failed: \(error.localizedDescription)"
        }
    }

    func restore(_ item: Quarantine.Item) async {
        guard let quarantine else { return }
        try? await quarantine.restore(item)
        await refreshQuarantine()
    }

    func delete(_ item: Quarantine.Item) async {
        guard let quarantine else { return }
        try? await quarantine.delete(item)
        await refreshQuarantine()
    }
}

struct ProtectionView: View {
    var body: some View {
        TabView {
            MalwareScanView()
                .tabItem { Label("Malware", systemImage: "shield") }
            PrivacyCleanerView()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .padding(8)
        .navigationTitle("Protection")
    }
}

struct MalwareScanView: View {
    @State private var model = ProtectionViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.scanner.isAvailable {
                    availableContent
                } else {
                    unavailableCard
                }
                quarantineCard
            }
            .padding(24)
        }
        .task { await model.refreshQuarantine() }
    }

    private var unavailableCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shield.slash").font(.title2).foregroundStyle(MCTheme.warning)
                    Text("Malware engine not installed").font(.headline)
                }
                Text("MacCare Local uses the open-source ClamAV engine for local malware scanning. It is not installed on this Mac, so scanning is unavailable — this module will not pretend otherwise.")
                    .foregroundStyle(.secondary)
                Text("To enable it: install ClamAV (for example `brew install clamav`), run `freshclam` once to download signatures, then reopen this screen.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Note: this scanner is a local signature check, not a commercial antivirus or real-time protection.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var availableContent: some View {
        MCCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "shield").font(.title2).foregroundStyle(MCTheme.accent)
                    Text("Local malware scan (ClamAV)").font(.headline)
                    Spacer()
                    if model.phase == .scanning { ProgressView().controlSize(.small) }
                }
                Text("Signature-based scan. Not a commercial antivirus; no real-time protection.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Scan Downloads") {
                        Task { await model.scan(paths: [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")]) }
                    }
                    Button("Scan Folder…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = true
                        if panel.runModal() == .OK, let url = panel.url {
                            Task { await model.scan(paths: [url]) }
                        }
                    }
                }
                .disabled(model.phase == .scanning)
                if let info = model.lastScanInfo {
                    Text(info).font(.caption).foregroundStyle(.secondary)
                }
                if case let .failed(message) = model.phase {
                    Text(message).font(.caption).foregroundStyle(MCTheme.danger)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if model.phase == .results {
            if model.findings.isEmpty {
                MCCard {
                    HStack {
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(MCTheme.success)
                        Text("No threats found").font(.headline)
                        Spacer()
                    }
                }
            } else {
                MCCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Findings").font(.headline)
                        ForEach(model.findings) { finding in
                            HStack {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundStyle(MCTheme.danger)
                                VStack(alignment: .leading) {
                                    Text(finding.signature).font(.callout.weight(.medium))
                                    Text(finding.path).font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                Button("Quarantine") {
                                    Task { await model.quarantineFinding(finding) }
                                }
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: finding.path)])
                                } label: { Image(systemName: "magnifyingglass") }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        if let message = model.statusMessage {
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var quarantineCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quarantine").font(.headline)
                if model.quarantineItems.isEmpty {
                    Text("Empty. Quarantined files are stored locally, stripped of execute permission, and can be restored or permanently deleted.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.quarantineItems) { item in
                    HStack {
                        Image(systemName: "archivebox").foregroundStyle(MCTheme.warning)
                        VStack(alignment: .leading) {
                            Text(item.signature).font(.callout.weight(.medium))
                            Text("was: \(item.originalPath)").font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Button("Restore") { Task { await model.restore(item) } }
                        Button("Delete Permanently", role: .destructive) {
                            Task { await model.delete(item) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
