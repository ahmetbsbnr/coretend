import SwiftUI
import UniformTypeIdentifiers
import ScanCore
import ProductContract
import AppShell

struct ExploreScanView: View {
    let french: Bool
    @State private var selectingFolder = false
    @State private var scanning = false
    @State private var results: [ScanResult] = []
    @State private var status: String?
    @State private var scanTask: Task<Void, Never>?
    @State private var query = ""
    @State private var sortMode = "largest"

    private var visibleResults: [ScanResult] {
        let filtered = results.filter { query.isEmpty || $0.url.lastPathComponent.localizedCaseInsensitiveContains(query) || $0.url.deletingLastPathComponent().path.localizedCaseInsensitiveContains(query) }
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

            if scanning { ProgressView(copy("scan.progress")) }
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
                }
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
                List(visibleResults, id: \.url) { result in
                    HStack {
                        Image(systemName: "doc")
                        Text(result.url.lastPathComponent).lineLimit(1)
                        Spacer()
                        Text(size(result.allocatedBytes)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .frame(minHeight: 260)
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
        .onDisappear { scanTask?.cancel() }
    }

    private func beginScan(_ root: URL) {
        let acquiredScope = root.startAccessingSecurityScopedResource()
        results = []
        status = nil
        scanning = true
        scanTask = Task {
            defer {
                if acquiredScope { root.stopAccessingSecurityScopedResource() }
                scanning = false
            }
            do {
                let engine = LocalScanEngine()
                let exclusions = try await LocalStoreAccess.exclusions()
                let request = ScanRequest(roots: [ScanRoot(url: root, ruleID: .explore)], exclusions: exclusions)
                for try await event in engine.scan(request) {
                    if Task.isCancelled { break }
                    switch event {
                    case .result(let result): results.append(result)
                    case .itemFailure: status = copy("scan.partial")
                    case .finished: status = results.isEmpty ? copy("scan.empty") : nil
                    case .progress: break
                    }
                }
            } catch {
                status = copy("scan.failed")
            }
        }
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
}
