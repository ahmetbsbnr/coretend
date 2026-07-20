import SwiftUI
import DesignSystem
import Persistence

/// Cloud Cleanup — analyzes the *local* folders of cloud providers, showing how
/// much space files really occupy on this Mac vs their logical size.
/// Never triggers a download; never deletes (a synced deletion would propagate).
@MainActor
@Observable
final class CloudCleanupViewModel {
    struct Provider: Identifiable {
        let id: String
        let name: String
        let icon: String
        let root: URL
    }

    /// Local-vs-remote classification. `placeholder` comes from the real
    /// `ubiquitousItemDownloadingStatusKey` signal (not downloaded); `partial`
    /// is a byte-ratio fallback for folders that mix downloaded and
    /// not-downloaded children. There is no public API to detect Finder's
    /// "Keep Downloaded" pin state for arbitrary iCloud Drive items, so this
    /// module does not claim a pinned state it cannot verify.
    enum SyncState: String, Sendable {
        case local, partial, placeholder

        static func classify(logicalBytes: Int64, localBytes: Int64, isCloudPlaceholder: Bool) -> SyncState {
            if isCloudPlaceholder { return .placeholder }
            guard logicalBytes > 0 else { return .local }
            if localBytes >= logicalBytes { return .local }
            if localBytes < logicalBytes / 10 { return .placeholder }
            return .partial
        }
    }

    struct Entry: Identifiable {
        let id: String
        let name: String
        let isDirectory: Bool
        let logicalBytes: Int64
        let localBytes: Int64
        let isCloudPlaceholder: Bool
        var syncState: SyncState { SyncState.classify(logicalBytes: logicalBytes, localBytes: localBytes, isCloudPlaceholder: isCloudPlaceholder) }
        var isMostlyRemote: Bool { syncState != .local }
    }

    enum Phase: Equatable { case detecting, noProviders, ready, scanning, results }

    var phase: Phase = .detecting
    var providers: [Provider] = []
    var selectedProvider: Provider?
    var entries: [Entry] = []

    var totalLogical: Int64 { entries.reduce(0) { $0 + $1.logicalBytes } }
    var totalLocal: Int64 { entries.reduce(0) { $0 + $1.localBytes } }
    /// Real bytes this module could ever recover locally (i.e. what's
    /// actually on disk today). This module never downloads or deletes
    /// anything itself — this is informational, not an action total.
    var recoverableLocalBytes: Int64 { totalLocal }

    func detect() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default
        var found: [Provider] = []
        let candidates: [(String, String, URL)] = [
            ("icloud", "iCloud Drive", home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")),
            ("dropbox", "Dropbox", home.appendingPathComponent("Dropbox")),
            ("gdrive", "Google Drive", home.appendingPathComponent("Library/CloudStorage").appendingPathComponent("GoogleDrive")),
            ("onedrive", "OneDrive", home.appendingPathComponent("Library/CloudStorage").appendingPathComponent("OneDrive")),
        ]
        for (id, name, url) in candidates where fm.fileExists(atPath: url.path) {
            found.append(Provider(id: id, name: name, icon: "icloud", root: url))
        }
        // CloudStorage entries are provider-named dirs (e.g. "GoogleDrive-user@x").
        let cloudStorage = home.appendingPathComponent("Library/CloudStorage")
        if let entries = try? fm.contentsOfDirectory(at: cloudStorage, includingPropertiesForKeys: nil) {
            for entry in entries where !found.contains(where: { $0.root.path == entry.path }) {
                let name = entry.lastPathComponent
                if name.hasPrefix("GoogleDrive") { found.append(Provider(id: entry.path, name: "Google Drive", icon: "icloud", root: entry)) }
                else if name.hasPrefix("OneDrive") { found.append(Provider(id: entry.path, name: "OneDrive", icon: "icloud", root: entry)) }
                else if name.hasPrefix("Dropbox") { found.append(Provider(id: entry.path, name: "Dropbox", icon: "icloud", root: entry)) }
            }
        }
        providers = found
        phase = found.isEmpty ? .noProviders : .ready
    }

    func scan(_ provider: Provider) {
        selectedProvider = provider
        phase = .scanning
        entries = []
        let root = provider.root
        Task {
            let result = await Task.detached(priority: .utility) { () -> [Entry] in
                Self.measure(root: root)
            }.value
            entries = result
            phase = .results
            AppEnvironment.shared.record(ActivityRecord(
                kind: .scan, summary: "Cloud analysis: \(provider.name)",
                itemCount: result.count, bytes: result.reduce(0) { $0 + $1.localBytes }, dryRun: true))
        }
    }

    /// Synchronous walk (DirectoryEnumerator can't be iterated in async contexts).
    /// Read-only: only `resourceValues`/`contentsOfDirectory` are used, never
    /// `startDownloadingUbiquitousItem` — this never triggers a cloud download.
    nonisolated private static func measure(root: URL) -> [Entry] {
                let fm = FileManager.default
                let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey,
                                                  .isSymbolicLinkKey, .ubiquitousItemDownloadingStatusKey]
                guard let top = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: Array(keys),
                                                            options: [.skipsHiddenFiles]) else { return [] }
                var entries: [Entry] = []
                for item in top {
                    guard let values = try? item.resourceValues(forKeys: keys),
                          values.isSymbolicLink != true else { continue }
                    if values.isDirectory == true {
                        var logical: Int64 = 0
                        var local: Int64 = 0
                        var anyPlaceholder = false
                        if let enumerator = fm.enumerator(at: item, includingPropertiesForKeys: Array(keys)) {
                            for case let sub as URL in enumerator {
                                guard let v = try? sub.resourceValues(forKeys: keys), v.isDirectory != true else { continue }
                                logical += Int64(v.fileSize ?? 0)
                                local += Int64(v.totalFileAllocatedSize ?? 0)
                                if v.ubiquitousItemDownloadingStatus.map({ $0 != .current }) ?? false { anyPlaceholder = true }
                            }
                        }
                        entries.append(Entry(id: item.path, name: item.lastPathComponent,
                                             isDirectory: true, logicalBytes: logical, localBytes: local,
                                             isCloudPlaceholder: anyPlaceholder))
                    } else {
                        entries.append(Entry(id: item.path, name: item.lastPathComponent, isDirectory: false,
                                             logicalBytes: Int64(values.fileSize ?? 0),
                                             localBytes: Int64(values.totalFileAllocatedSize ?? 0),
                                             isCloudPlaceholder: values.ubiquitousItemDownloadingStatus.map { $0 != .current } ?? false))
                    }
                }
                return entries.sorted { $0.localBytes > $1.localBytes }
    }
}

struct CloudCleanupView: View {
    @State private var model = CloudCleanupViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .detecting:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .noProviders:
                VStack(spacing: 12) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("No cloud folders found").font(.title3.weight(.semibold))
                    Text("iCloud Drive, Dropbox, Google Drive and OneDrive local folders are detected automatically when present.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                providerPicker
            case .scanning:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Measuring local footprint…")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results:
                resultsView
            }
        }
        .navigationTitle("Cloud Cleanup")
        .onAppear { if model.phase == .detecting { model.detect() } }
    }

    private var providerPicker: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud").font(.system(size: 56)).foregroundStyle(MCTheme.accent)
            Text("Analyze cloud storage footprint").font(.title2.weight(.semibold))
            Text("Shows which synced files actually occupy disk space on this Mac.\nAnalysis only — deleting synced files would remove them on every device.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            ForEach(model.providers) { provider in
                Button {
                    model.scan(provider)
                } label: {
                    Label(provider.name, systemImage: provider.icon)
                        .frame(width: 220)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(model.selectedProvider?.name ?? "").font(.headline)
                    Text("\(mcFormatBytes(model.recoverableLocalBytes)) on this Mac of \(mcFormatBytes(model.totalLogical)) total — analysis only, nothing downloaded or deleted")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Back") { model.phase = .ready }
            }
            .padding()
            List(model.entries) { entry in
                HStack {
                    // Filled shape = real local bytes on disk; outline shape = online-only
                    // placeholder not present locally. Shape carries the meaning, not color alone.
                    Image(systemName: symbolName(for: entry))
                        .foregroundStyle(entry.syncState == .local ? MCTheme.accent : .secondary)
                        .accessibilityHidden(true)
                    Text(entry.name)
                    stateBadge(for: entry.syncState)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(mcFormatBytes(entry.localBytes)) local").monospacedDigit()
                        Text("\(mcFormatBytes(entry.logicalBytes)) total")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.id)])
                    } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Reveal \(entry.name) in Finder")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(entry.name), \(accessibilityStateText(entry.syncState)), \(mcFormatBytes(entry.localBytes)) local of \(mcFormatBytes(entry.logicalBytes)) total")
            }
            .listStyle(.inset)
        }
    }

    private func symbolName(for entry: CloudCleanupViewModel.Entry) -> String {
        let base = entry.isDirectory ? "folder" : "doc"
        return entry.syncState == .local ? "\(base).fill" : base
    }

    private func stateBadge(for state: CloudCleanupViewModel.SyncState) -> some View {
        Group {
            switch state {
            case .local: EmptyView()
            case .partial:
                badge("partially local", color: MCTheme.warning)
            case .placeholder:
                badge("online only", color: .secondary)
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private func accessibilityStateText(_ state: CloudCleanupViewModel.SyncState) -> String {
        switch state {
        case .local: return "fully local"
        case .partial: return "partially local"
        case .placeholder: return "online only, not downloaded"
        }
    }
}
