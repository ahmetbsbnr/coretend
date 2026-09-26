import SwiftUI
import QuickLook
import UniformTypeIdentifiers
import ScanCore
import ProductContract
import AppShell
import Persistence

struct ExploreScanView: View {
    let french: Bool
    @State private var selectingFolder = false
    @State private var scanning = false
    @State private var results: [ScanResult] = []
    @State private var status: String?
    @State private var scanTask: Task<Void, Never>?
    @State private var activeScanID: UUID?
    @State private var query = ""
    @State private var sortMode = "largest"
    @State private var preset: ExplorePreset = .all
    @State private var presetEvaluationDate = Date.now
    @State private var previewURL: URL?
    @State private var selectedRoot: URL?
    @State private var previewScopeHeld = false
    @State private var previewScopedRoot: URL?
    @AppStorage("coretend.recentFiles.enabled") private var recentFilesEnabled = false
    @State private var favoritePaths: Set<String> = []

    private var visibleResults: [ScanResult] {
        let filtered = results.filter {
            (query.isEmpty || $0.url.lastPathComponent.localizedCaseInsensitiveContains(query) || $0.url.deletingLastPathComponent().path.localizedCaseInsensitiveContains(query))
                && preset.matches($0, evaluatedAt: presetEvaluationDate)
        }
        switch sortMode {
        case "oldest": return filtered.sorted { ($0.modifiedAt ?? .distantFuture) < ($1.modifiedAt ?? .distantFuture) }
        case "name": return filtered.sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
        default: return filtered.sorted {
            let left = allocated($0), right = allocated($1)
            switch (left, right) {
            case let (a?, b?): return a == b ? $0.url.path < $1.url.path : a > b
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return $0.url.path < $1.url.path
            }
        }
    }
    }

    private var treemapInputs: [TreemapInput] {
        visibleResults.compactMap { result in
            guard case .known(let bytes) = result.allocatedBytes, bytes > 0 else { return nil }
            return TreemapInput(id: result.url.path, bytes: bytes)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                selectingFolder = true
            } label: {
                Label(copy("scan.choose"), systemImage: "folder.badge.plus")
            }
            .disabled(scanning)
            .accessibilityHint(copy("scan.choose.hint"))

            if scanning {
                ProgressView(copy("scan.progress"))
                Button(copy("scan.cancel")) { cancelScan() }
            }
            if let status { Text(status).foregroundStyle(.secondary).textSelection(.enabled) }
            if !results.isEmpty {
                Text(copy("scan.count", count: results.count)).font(.headline)
                HStack {
                    TextField(copy("explore.search"), text: $query).textFieldStyle(.roundedBorder)
                    Picker(copy("explore.sort"), selection: $sortMode) {
                        Text(copy("explore.largest")).tag("largest")
                        Text(copy("explore.oldest")).tag("oldest")
                        Text(copy("explore.name")).tag("name")
                    }
                    .frame(width: 190)
                    Picker(french ? "Filtre" : "Filter", selection: $preset) {
                        Text(french ? "Tous" : "All files").tag(ExplorePreset.all)
                        Text(french ? "≥ 1 Gio local" : "≥ 1 GiB local").tag(ExplorePreset.largeLocal)
                        Text(french ? "Anciens · 365 jours" : "Older · 365 days").tag(ExplorePreset.olderThan365Days)
                    }
                    .frame(width: 190)
                    .onChange(of: preset) { _, _ in presetEvaluationDate = .now }
                }
                Text(presetDescription)
                    .font(.caption).foregroundStyle(.secondary)
                let knownCount = treemapInputs.count
                Text(french ? "Carte proportionnelle : \(knownCount) fichiers à taille locale connue; les inconnus sont exclus." : "Proportional map: \(knownCount) files with known local size; unknown items excluded.")
                    .font(.caption).foregroundStyle(.secondary)
                GeometryReader { proxy in
                    let tiles = TreemapLayout.tiles(for: treemapInputs, size: proxy.size)
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.accentColor.opacity(0.32 + Double(index % 4) * 0.12))
                                .overlay(alignment: .topLeading) {
                                    if tile.frame.width > 90 && tile.frame.height > 34 {
                                        Text(URL(fileURLWithPath: tile.id).lastPathComponent)
                                            .font(.caption2).lineLimit(1).padding(5)
                                    }
                                }
                                .frame(width: tile.frame.width, height: tile.frame.height)
                                .position(x: tile.frame.midX, y: tile.frame.midY)
                                .accessibilityLabel("\(URL(fileURLWithPath: tile.id).lastPathComponent), \(ByteCountFormatter.string(fromByteCount: tile.bytes, countStyle: .file))")
                        }
                    }
                }
                .frame(height: 230)
                .accessibilityElement(children: .contain)
                if visibleResults.isEmpty {
                    ContentUnavailableView(french ? "Aucun fichier ne correspond au filtre" : "No files match this filter", systemImage: "line.3.horizontal.decrease.circle")
                        .frame(minHeight: 260)
                } else {
                    List(visibleResults, id: \.url) { result in
                        HStack {
                            Image(systemName: "doc")
                            Text(result.url.lastPathComponent).lineLimit(1)
                            Spacer()
                            Text(size(result.allocatedBytes)).monospacedDigit().foregroundStyle(.secondary)
                            Button { Task { await toggleFavorite(result) } } label: {
                                Image(systemName: favoritePaths.contains(result.url.path) ? "star.fill" : "star")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(favoritePaths.contains(result.url.path)
                                ? (french ? "Retirer \(result.url.lastPathComponent) des favoris" : "Remove \(result.url.lastPathComponent) from favorites")
                                : (french ? "Ajouter \(result.url.lastPathComponent) aux favoris" : "Add \(result.url.lastPathComponent) to favorites"))
                            Button { previewURL = result.url } label: {
                                Label(copy("explore.preview"), systemImage: "eye")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(previewLabel(for: result.url))
                            .accessibilityHint(french ? "Ouvre l’aperçu Quick Look." : "Opens the Quick Look preview.")
                        }
                        .accessibilityElement(children: .contain)
                    }
                    .frame(minHeight: 260)
                }
                Text(french ? "Somme des octets locaux connus : \(ByteCountFormatter.string(fromByteCount: treemapInputs.reduce(0) { $0 + $1.bytes }, countStyle: .file)). Le nuage et les tailles inconnues ne sont pas estimés." : "Known local bytes total: \(ByteCountFormatter.string(fromByteCount: treemapInputs.reduce(0) { $0 + $1.bytes }, countStyle: .file)). Cloud-backed and unknown sizes are not estimated.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .fileImporter(isPresented: $selectingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { outcome in
            switch outcome {
            case .success(let urls):
                guard let url = urls.first else { return }
                beginScan(url)
            case .failure:
                status = copy("scan.failed")
            }
        }
        .onDisappear {
            scanTask?.cancel(); activeScanID = nil; scanning = false
            previewURL = nil
            releasePreviewScope()
        }
        .task { await loadFavorites() }
        .quickLookPreview($previewURL)
        .onChange(of: previewURL) { _, item in
            if item == nil { releasePreviewScope() }
            else if !previewScopeHeld, let selectedRoot {
                previewScopeHeld = selectedRoot.startAccessingSecurityScopedResource()
                if previewScopeHeld { previewScopedRoot = selectedRoot }
            }
        }
    }

    private func beginScan(_ root: URL) {
        scanTask?.cancel()
        previewURL = nil
        selectedRoot = root
        let scanID = UUID()
        activeScanID = scanID
        let acquiredScope = root.startAccessingSecurityScopedResource()
        results = []
        status = nil
        scanning = true
        scanTask = Task {
            var rootFailure: String?
            var partialFailure = false
            defer {
                if acquiredScope { root.stopAccessingSecurityScopedResource() }
                if activeScanID == scanID { scanning = false; activeScanID = nil }
            }
            do {
                let engine = LocalScanEngine()
                let exclusions = try await LocalStoreAccess.exclusions()
                let request = ScanRequest(roots: [ScanRoot(url: root, ruleID: .explore)], exclusions: exclusions)
                for try await event in engine.scan(request) {
                    guard !Task.isCancelled, activeScanID == scanID else { return }
                    switch event {
                    case .result(let result): results.append(result)
                    case .itemFailure(let path, let reason):
                        if path == root.path { rootFailure = reason } else { partialFailure = true }
                    case .finished:
                        if recentFilesEnabled {
                            let measured = results.suffix(SQLiteStore.maximumRecentFiles)
                            if let store = try? await LocalStoreAccess.open() {
                                let batch = measured.map { item in
                                    let logical: Int64? = { if case .known(let bytes) = item.logicalBytes { return bytes }; return nil }()
                                    let allocated: Int64? = { if case .known(let bytes) = item.allocatedBytes { return bytes }; return nil }()
                                    return RecentFileMeasurement(path: item.url.path, logicalBytes: logical, allocatedBytes: allocated)
                                }
                                try? await store.recordRecentFiles(batch)
                            }
                        }
                        if let rootFailure { status = ProductCopy.scanRootFailure(reason: rootFailure, french: french) }
                        else if partialFailure { status = copy("scan.partial") }
                        else { status = results.isEmpty ? copy("scan.empty") : nil }
                    case .progress: break
                    }
                }
            } catch is CancellationError {
                if activeScanID == scanID { status = copy("scan.cancelled") }
            } catch {
                if activeScanID == scanID { status = copy("scan.failed") }
            }
        }
    }

    private func cancelScan() {
        scanTask?.cancel()
        activeScanID = nil
        scanning = false
        status = copy("scan.cancelled")
    }

    private func releasePreviewScope() {
        if previewScopeHeld, let previewScopedRoot { previewScopedRoot.stopAccessingSecurityScopedResource() }
        previewScopeHeld = false
        previewScopedRoot = nil
    }

    @MainActor private func toggleFavorite(_ result: ScanResult) async {
        do {
            let store = try await LocalStoreAccess.open()
            let isFavorite = !favoritePaths.contains(result.url.path)
            try await store.setFavorite(path: result.url.path, isFavorite: isFavorite)
            if isFavorite { favoritePaths.insert(result.url.path) } else { favoritePaths.remove(result.url.path) }
        } catch { status = french ? "Favori non enregistré." : "Favorite was not saved." }
    }

    @MainActor private func loadFavorites() async {
        guard let store = try? await LocalStoreAccess.open(), let records = try? await store.savedFiles() else { return }
        favoritePaths = Set(records.filter(\.isFavorite).map(\.path))
    }

    private func size(_ measurement: ProductMeasurement<Int64>) -> String {
        switch measurement {
        case .known(let bytes): ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        case .unknown: copy("scan.unknownSize")
        }
    }

    private func allocated(_ result: ScanResult) -> Int64? {
        if case .known(let bytes) = result.allocatedBytes { return bytes }
        return nil
    }

    private func copy(_ key: String, count: Int? = nil) -> String {
        if key == "scan.count", let count { return french ? "\(count) fichiers mesurés" : "\(count) measured files" }
        return ProductCopy.value(for: key, french: french)
    }

    private func previewLabel(for url: URL) -> String {
        french ? "Aperçu de \(url.lastPathComponent)" : "Preview \(url.lastPathComponent)"
    }

    private var presetDescription: String {
        switch preset {
        case .all:
            return french ? "Aucun filtre de taille ou de date." : "No size or date filter."
        case .largeLocal:
            return french ? "Octets locaux alloués connus ≥ 1 Gio; tailles nuage/inconnues exclues." : "Known allocated local bytes ≥ 1 GiB; cloud/unknown sizes excluded."
        case .olderThan365Days:
            let cutoff = presetEvaluationDate.addingTimeInterval(-ExplorePreset.ageWindow)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
            let date = formatter.string(from: cutoff)
            return french ? "Date de modification au plus tard le \(date) (365 jours); dates inconnues exclues." : "Modification date on or before \(date) (365 days); unknown dates excluded."
        }
    }
}
