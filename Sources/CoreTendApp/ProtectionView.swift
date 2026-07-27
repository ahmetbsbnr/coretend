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

    private var quarantine: Quarantine? = try? Quarantine(directory: (try? Quarantine.defaultDirectory()) ?? FileManager.default.temporaryDirectory.appendingPathComponent("CoreTendQuarantine"))

    // MARK: Optional background watch (Step 3). Off by default each launch —
    // a background scanner should never silently turn itself on. Never
    // auto-quarantines: it only raises alerts for the user to review.
    var watchEnabled = false
    var watchAlerts: [ProtectionWatcher.Alert] = []
    private var watcher: ProtectionWatcher?
    private var producer: FSEventsProducer?
    private var watchTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

    /// Folders watched when protection watch is on: Downloads, /Applications,
    /// ~/Applications. Only those that exist are passed to FSEvents.
    private var watchPaths: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [home.appendingPathComponent("Downloads"),
                URL(fileURLWithPath: "/Applications"),
                home.appendingPathComponent("Applications")]
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func toggleWatch() {
        watchEnabled ? stopWatch() : startWatch()
    }

    private func startWatch() {
        guard scanner.isAvailable, watcher == nil else { return }
        let fpURL = (try? Quarantine.defaultDirectory())?
            .deletingLastPathComponent().appendingPathComponent("watch-fingerprints.json")
        let watcher = ProtectionWatcher(scanner: scanner, fingerprintURL: fpURL)
        let producer = FSEventsProducer()
        let stream = producer.start(paths: watchPaths)
        self.watcher = watcher
        self.producer = producer
        self.watchEnabled = true
        watchTask = Task { await watcher.consume(stream) }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self else { break }
                let current = await watcher.alerts
                await MainActor.run { self.watchAlerts = current }
            }
        }
    }

    private func stopWatch() {
        producer?.stop()
        Task { [watcher] in await watcher?.stop() }
        watchTask?.cancel(); pollTask?.cancel()
        watcher = nil; producer = nil
        watchTask = nil; pollTask = nil
        watchEnabled = false
    }

    func quarantineWatchAlert(_ alert: ProtectionWatcher.Alert) async {
        await quarantineFinding(MalwareFinding(path: alert.path, signature: alert.signature))
        watchAlerts.removeAll { $0.id == alert.id }
    }

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
            lastScanInfo = L("protection.scan_info", paths.map(\.lastPathComponent).joined(separator: ", "), String(format: "%.1f", result.duration), result.findings.count)
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
            statusMessage = L("protection.moved_to_quarantine", finding.path)
            await refreshQuarantine()
        } catch {
            statusMessage = L("protection.quarantine_failed", error.localizedDescription)
        }
    }

    func restore(_ item: Quarantine.Item) async {
        guard let quarantine else { return }
        do {
            try await quarantine.restore(item)
            AppEnvironment.shared.record(ActivityRecord(
                kind: .restore, summary: "Restored from quarantine: \(URL(fileURLWithPath: item.originalPath).lastPathComponent)",
                itemCount: 1, bytes: 0, dryRun: false))
        } catch {
            statusMessage = L("protection.restore_failed", error.localizedDescription)
        }
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
                .tabItem { Label(L("protection.tab.malware"), systemImage: "shield") }
            PrivacyCleanerView()
                .tabItem { Label(L("protection.tab.privacy"), systemImage: "hand.raised") }
        }
        .padding(8)
        .navigationTitle(L("sidebar.protect"))
    }
}

struct MalwareScanView: View {
    @State private var model = ProtectionViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.scanner.isAvailable {
                    availableContent
                    watchCard
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
        let mesh = MCMeshView(completeness: 0.25, style: .incomplete)
        return MCCard {
            HStack(alignment: .top, spacing: 16) {
                mesh.frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "shield.slash").font(.title2).foregroundStyle(MCTheme.warning)
                        Text(L("protection.unavailable.title")).font(.headline)
                    }
                    Text(L("protection.unavailable.body"))
                        .foregroundStyle(.secondary)
                    Text(L("protection.unavailable.howto"))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(L("protection.unavailable.note"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(mesh.accessibilityDescription)
        }
    }

    @ViewBuilder
    private var availableContent: some View {
        let meshStyle: MCMeshView.Style = model.phase == .scanning ? .scanning : (model.findings.isEmpty ? .ready : .alert)
        let mesh = MCMeshView(completeness: model.phase == .scanning ? 0.7 : 1.0, style: meshStyle)
        MCCard {
            HStack(alignment: .top, spacing: 16) {
                mesh.frame(width: 64, height: 64).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "shield").font(.title2).foregroundStyle(MCTheme.accent)
                        Text(L("protection.scan.title")).font(.headline)
                        Spacer()
                        if model.phase == .scanning { ProgressView().controlSize(.small) }
                    }
                    Text(L("protection.scan.subtitle"))
                        .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(L("protection.scan_downloads")) {
                        Task { await model.scan(paths: [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")]) }
                    }
                    Button(L("protection.scan_folder")) {
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
        }
        if model.phase == .results {
            if model.findings.isEmpty {
                MCCard {
                    HStack {
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(MCTheme.success)
                        Text(L("protection.no_threats")).font(.headline)
                        Spacer()
                    }
                }
            } else {
                MCCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("protection.findings")).font(.headline)
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
                                Button(L("protection.quarantine")) {
                                    Task { await model.quarantineFinding(finding) }
                                }
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: finding.path)])
                                } label: { Image(systemName: "magnifyingglass") }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(L("common.reveal_in_finder"))
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

    private var watchCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: model.watchEnabled ? "eye" : "eye.slash")
                        .foregroundStyle(model.watchEnabled ? MCTheme.accent : .secondary)
                    Text(L("protection.watch.title")).font(.headline)
                    Spacer()
                    Toggle("", isOn: Binding(get: { model.watchEnabled },
                                             set: { _ in model.toggleWatch() }))
                        .labelsHidden()
                        .accessibilityLabel(L("protection.watch.toggle"))
                }
                Text(L("protection.watch.subtitle"))
                    .font(.caption).foregroundStyle(.secondary)
                if model.watchEnabled {
                    if model.watchAlerts.isEmpty {
                        Text(L("protection.watch.alerts_none"))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(model.watchAlerts) { alert in
                            HStack {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundStyle(MCTheme.danger)
                                VStack(alignment: .leading) {
                                    Text(alert.signature).font(.callout.weight(.medium))
                                    Text(alert.path).font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                Button(L("protection.quarantine")) {
                                    Task { await model.quarantineWatchAlert(alert) }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var quarantineCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("protection.quarantine_section")).font(.headline)
                if model.quarantineItems.isEmpty {
                    Text(L("protection.quarantine_empty"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.quarantineItems) { item in
                    HStack {
                        Image(systemName: "archivebox").foregroundStyle(MCTheme.warning)
                        VStack(alignment: .leading) {
                            Text(item.signature).font(.callout.weight(.medium))
                            Text(L("protection.quarantine_was", item.originalPath)).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Button(L("protection.restore")) { Task { await model.restore(item) } }
                        Button(L("protection.delete_permanently"), role: .destructive) {
                            Task { await model.delete(item) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
