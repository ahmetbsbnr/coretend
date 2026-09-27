import DesignSystem
import SwiftUI
import Darwin
import QuickLook
import UniformTypeIdentifiers
import ScanCore
import ProductContract
import AppShell
import SafetyCore
import Domain
import Persistence

struct ExploreScanView: View {
    let french: Bool
    @Binding var recentFilesEnabled: Bool
    @State private var selectingFolder = false
    @State private var scanning = false
    @State private var scanCompletedFiles = 0
    @State private var results: [ScanResult] = []
    @State private var status: String?
    @State private var scanTask: Task<Void, Never>?
    @State private var activeScanID: UUID?
    @State private var query = ""
    @State private var sortMode = "largest"
    @State private var preset: ExplorePreset = .all
    @State private var category: ExploreFileCategory = .all
    @State private var presetEvaluationDate = Date.now
    @State private var previewURL: URL?
    @State private var selectedRoot: URL?
    @State private var selectedRootIdentity: FileIdentity?
    @State private var selectedExploreFiles: Set<URL> = []
    @State private var actionReview: ActionReview?
    @State private var actionDialogPresented = false
    @State private var actionService: FileActionService?
    @State private var actionBusy = false
    @State private var actionScopeHeld = false
    @State private var actionScopedRoot: URL?
    @State private var viewVisible = false
    @State private var previewScopeHeld = false
    @State private var previewScopedRoot: URL?
    @State private var favoritePaths: Set<String> = []

    private var visibleResults: [ScanResult] {
        let filtered = results.filter {
            (query.isEmpty || $0.url.lastPathComponent.localizedCaseInsensitiveContains(query) || $0.url.deletingLastPathComponent().path.localizedCaseInsensitiveContains(query))
                && category.matches($0.url)
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
            let identity = result.allocationIdentity.map { "\($0.device):\($0.inode)" }
            return TreemapInput(id: result.url.path, bytes: bytes, allocationIdentity: identity)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button {
                selectingFolder = true
            } label: {
                Label(copy("scan.choose"), systemImage: "folder.badge.plus")
            }
            .disabled(scanning || actionBusy || actionReview != nil)
            .accessibilityHint(copy("scan.choose.hint"))

            if let selectedRoot {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(french ? "Périmètre mesuré" : "Measured scope").font(.caption.weight(.semibold))
                        Text(selectedRoot.path).font(.caption.monospaced()).textSelection(.enabled)
                    }
                } icon: {
                    Image(systemName: "folder.fill").foregroundStyle(Palette.accent.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
            }

            if scanning {
                HStack(spacing: 14) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy("scan.progress")).font(.headline)
                        Text(ProductCopy.scanProgress(completedFiles: scanCompletedFiles, french: french))
                            .font(.caption).foregroundStyle(Palette.secondaryInk.color)
                    }
                    Spacer()
                    Button(copy("scan.cancel")) { cancelScan() }
                }
                .padding(14)
                .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
                .motion(.gentle, value: scanning)
            }
            if let status {
                Label(status, systemImage: "info.circle")
                    .font(.callout).foregroundStyle(Palette.secondaryInk.color).textSelection(.enabled)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 10))
            }
            if !results.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(copy("scan.count", count: results.count)).font(.title3.weight(.semibold))
                    Spacer()
                    Text(french ? "Résultats de ce dossier" : "Results from this folder")
                        .font(.caption).foregroundStyle(Palette.secondaryInk.color)
                }
                HStack {
                    TextField(copy("explore.search"), text: $query).textFieldStyle(.roundedBorder)
                    Picker(copy("explore.sort"), selection: $sortMode) {
                        Text(copy("explore.largest")).tag("largest")
                        Text(copy("explore.oldest")).tag("oldest")
                        Text(copy("explore.name")).tag("name")
                    }
                    .frame(width: 190)
                }
                HStack {
                    Picker(french ? "Catégorie" : "Category", selection: $category) {
                        ForEach(ExploreFileCategory.allCases, id: \.self) { value in
                            Text(categoryName(value)).tag(value)
                        }
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
                VStack(alignment: .leading, spacing: 5) {
                    Label(categoryDescription, systemImage: "tag")
                    Label(presetDescription, systemImage: "line.3.horizontal.decrease")
                }
                .font(.caption).foregroundStyle(Palette.secondaryInk.color)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 10))
                let knownCount = treemapInputs.count
                Text(french ? "Carte proportionnelle : \(knownCount) allocations distinctes connues; inconnues exclues." : "Proportional map: \(knownCount) distinct known allocations; unknown items excluded.")
                    .font(.caption).foregroundStyle(.secondary)
                GeometryReader { proxy in
                    let tiles = TreemapLayout.tiles(for: treemapInputs, size: proxy.size)
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                            RoundedRectangle(cornerRadius: 5)
                    .fill(Palette.accent.color.opacity(0.14 + Double(index % 4) * 0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5).stroke(Palette.separator.color, lineWidth: 0.5)
                    }
                                .overlay(alignment: .topLeading) {
                                    if tile.frame.width > 90 && tile.frame.height > 34 {
                                        Text(URL(fileURLWithPath: tile.id).lastPathComponent)
                                            .font(.caption2).lineLimit(1).padding(5)
                                    }
                                }
                                .frame(width: tile.frame.width, height: tile.frame.height)
                                .position(x: tile.frame.midX, y: tile.frame.midY)
                                .transition(.opacity)
                                .accessibilityLabel("\(URL(fileURLWithPath: tile.id).lastPathComponent), \(ByteCountFormatter.string(fromByteCount: tile.bytes, countStyle: .file))")
                        }
                    }
                }
                .frame(minHeight: 150, idealHeight: 230, maxHeight: 280)
                .padding(8)
                .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 12))
                .motion(.gentle, value: treemapInputs.count)
                .accessibilityElement(children: .contain)
                if visibleResults.isEmpty {
                    ContentUnavailableView(french ? "Aucun fichier ne correspond au filtre" : "No files match this filter", systemImage: "line.3.horizontal.decrease.circle")
                        .frame(minHeight: 260)
                } else {
                    List(visibleResults, id: \.url) { result in
                        HStack {
                            Toggle(isOn: Binding(get: { selectedExploreFiles.contains(result.url) }, set: { enabled in
                                guard isSelectableExploreResult(result) else { return }
                                if enabled { selectedExploreFiles.insert(result.url) }
                                else { selectedExploreFiles.remove(result.url) }
                            })) { EmptyView() }
                                .labelsHidden()
                                .accessibilityLabel(copy("explore.delete.select"))
                                .disabled(!isSelectableExploreResult(result) || scanning || actionBusy || actionReview != nil)
                            Image(systemName: "doc")
                                .foregroundStyle(Palette.accent.color)
                            Text(result.url.lastPathComponent).lineLimit(1)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(french ? "Allouée localement : \(size(result.allocatedBytes))" : "Allocated locally: \(size(result.allocatedBytes))")
                                Text(french ? "Taille logique : \(size(result.logicalBytes))" : "Logical size: \(size(result.logicalBytes))")
                                Text(french ? "Modifié : \(modified(result))" : "Modified: \(modified(result))")
                            }
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(ProductCopy.scanResultAccessibilitySummary(
                                name: result.url.lastPathComponent,
                                source: french ? "Explorer" : "Explore",
                                state: french ? "Résultat mesuré" : "Measured result",
                                allocated: size(result.allocatedBytes), logical: size(result.logicalBytes),
                                modified: modified(result), french: french
                            ))
                            Button { Task { await toggleFavorite(result) } } label: {
                                Image(systemName: favoritePaths.contains(result.url.path) ? "star.fill" : "star")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(favoritePaths.contains(result.url.path)
                                ? (french ? "Retirer \(result.url.lastPathComponent) des favoris" : "Remove \(result.url.lastPathComponent) from favorites")
                                : (french ? "Ajouter \(result.url.lastPathComponent) aux favoris" : "Add \(result.url.lastPathComponent) to favorites"))
                            Button { showPreview(result.url) } label: {
                                Label(copy("explore.preview"), systemImage: "eye")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(previewLabel(for: result.url))
                            .accessibilityHint(french ? "Ouvre l’aperçu Quick Look." : "Opens the Quick Look preview.")
                        }
                        .accessibilityElement(children: .contain)
                    }
                    .frame(minHeight: 260)
                    Button { Task { await prepareDeleteReview() } } label: {
                        Label(copy("explore.delete.review"), systemImage: "trash")
                    }
                    .disabled(selectedExploreFiles.isEmpty || scanning || actionBusy || actionReview != nil)
                    .accessibilityHint(french ? "Aucun élément n’est déplacé avant confirmation." : "No item moves before confirmation.")
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
            viewVisible = false
            scanTask?.cancel(); activeScanID = nil; scanning = false
            previewURL = nil
            releasePreviewScope()
            if actionReview != nil { cancelDeleteAction() }
        }
        .onAppear { viewVisible = true }
        .task { await loadFavorites() }
        .quickLookPreview($previewURL)
        .onChange(of: previewURL) { _, item in
            if item == nil { releasePreviewScope() }
        }
        .confirmationDialog(copy("spacelens.delete.title"), isPresented: $actionDialogPresented, titleVisibility: .visible) {
            Button(copy("spacelens.delete.confirm"), role: .destructive) { beginDeleteExecution() }
            Button(copy("common.cancel"), role: .cancel) {}
        } message: {
            Text(deleteReviewMessage)
        }
        .onChange(of: actionDialogPresented) { _, presented in
            if !presented && actionReview != nil { cancelDeleteAction() }
        }
    }

    private func beginScan(_ root: URL) {
        scanTask?.cancel()
        previewURL = nil
        selectedRoot = root
        let scanID = UUID()
        activeScanID = scanID
        let acquiredScope = root.startAccessingSecurityScopedResource()
        selectedRootIdentity = try? FileIdentity(url: root)
        results = []
        selectedExploreFiles = []
        scanCompletedFiles = 0
        status = nil
        scanning = true
        actionReview = nil
        actionService = nil
        scanTask = Task {
            var rootFailure: String?
            var partialFailures = Set<String>()
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
                        if path == root.path { rootFailure = reason } else { partialFailures.insert(reason) }
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
                        else if !partialFailures.isEmpty { status = ProductCopy.scanPartialFailure(reasons: partialFailures, french: french) }
                        else { status = results.isEmpty ? copy("scan.empty") : nil }
                    case .progress(let completed): scanCompletedFiles = completed
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
        scanCompletedFiles = 0
        status = copy("scan.cancelled")
    }

    @MainActor private func prepareDeleteReview() async {
        guard let root = selectedRoot, let rootIdentity = selectedRootIdentity,
              !selectedExploreFiles.isEmpty, !scanning, !actionBusy, actionReview == nil else { return }
        actionBusy = true
        actionScopeHeld = root.startAccessingSecurityScopedResource()
        actionScopedRoot = root
        defer {
            actionBusy = false
            if actionReview == nil { releaseDeleteScope() }
        }

        let chosen = results.filter { selectedExploreFiles.contains($0.url) && isSelectableExploreResult($0) }
        guard !chosen.isEmpty, chosen.count == selectedExploreFiles.count,
              (try? FileIdentity(url: root)) == rootIdentity,
              chosen.allSatisfy({ isRegularFileInsideSelectedRoot($0.url, root: root) }) else {
            status = french ? "La sélection a changé; aucune action proposée." : "The selection changed; no action was proposed."
            return
        }

        do {
            let store = try await LocalStoreAccess.open()
            guard viewVisible else { return }
            let rule = ScanRule.explore.rawValue
            let allowed = Set([rule])
            let executor = SafeActionExecutor(allowedRoots: [root], allowedRules: allowed, trash: MacOSTrashClient(),
                                              expectedRootIdentities: [root: rootIdentity])
            let service = FileActionService(validator: .init(), executor: executor, store: store,
                                            allowedRoots: [root], allowedRuleIDs: allowed)
            let selections = chosen.map { FileActionSelection(url: $0.url, ruleID: rule) }
            let review = try service.prepareReview(selections)
            guard await service.recordProposal(review) else {
                status = copy("spacelens.delete.blocked")
                return
            }
            guard viewVisible else {
                _ = await service.recordCancellation(review)
                return
            }
            actionReview = review
            actionService = service
            actionDialogPresented = true
        } catch {
            status = french ? "Impossible d’examiner la sélection; aucun fichier déplacé." : "Review failed; no files moved."
        }
    }

    private func beginDeleteExecution() {
        guard let review = actionReview, let service = actionService else { return }
        actionBusy = true
        actionDialogPresented = false
        actionReview = nil
        actionService = nil
        Task { await executeDeleteAction(review, service) }
    }

    @MainActor private func executeDeleteAction(_ review: ActionReview, _ service: FileActionService) async {
        defer { actionBusy = false; releaseDeleteScope() }
        do {
            let batch = try service.confirm(review, accepted: true)
            let report = await service.execute(batch)
            let movedURLs = Set(report.items.compactMap { item -> URL? in
                if case .movedToTrash = item.outcome { return item.targetURL }
                return nil
            })
            results.removeAll { movedURLs.contains($0.url) }
            selectedExploreFiles.subtract(movedURLs)
            let moved = report.movedCount
            let failed = report.items.count - moved
            if failed == 0 {
                status = countedActionCopy(moved, key: "spacelens.delete.success")
            } else if moved == 0 {
                status = countedActionCopy(failed, key: "spacelens.delete.failed")
            } else {
                status = "\(countedActionCopy(moved, key: "spacelens.delete.success")); \(countedActionCopy(failed, key: "spacelens.delete.partial"))"
            }
        } catch {
            status = french ? "Action refusée; aucun fichier déplacé." : "Action refused; no files moved."
        }
    }

    private func cancelDeleteAction() {
        guard let review = actionReview, let service = actionService else { return }
        actionBusy = true
        actionDialogPresented = false
        actionReview = nil
        actionService = nil
        Task { @MainActor in
            let recorded = await service.recordCancellation(review)
            status = copy(recorded ? "spacelens.delete.cancelled" : "spacelens.delete.cancelled.unrecorded")
            releaseDeleteScope()
            actionBusy = false
        }
    }

    private var deleteReviewMessage: String {
        let items = actionReview?.items ?? []
        let paths = items.prefix(10).map { "\($0.url.lastPathComponent)\n\($0.url.path)" }.joined(separator: "\n\n")
        let remaining = max(0, items.count - 10)
        let suffix = remaining > 0 ? (french ? "\n\n… et \(remaining) autres" : "\n\n… and \(remaining) more") : ""
        return "\(paths)\(suffix)\n\n\(french ? "Seuls les fichiers sélectionnés seront déplacés vers la Corbeille." : "Only the selected files will be moved to Trash.")"
    }

    private func isSelectableExploreResult(_ result: ScanResult) -> Bool {
        guard result.ruleID == .explore, let root = selectedRoot else { return false }
        let rootPath = root.standardizedFileURL.path
        let candidate = result.url.standardizedFileURL.path
        return candidate != rootPath && candidate.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }

    private func isRegularFileInsideSelectedRoot(_ url: URL, root: URL) -> Bool {
        var rootInfo = stat()
        guard lstat(root.path, &rootInfo) == 0, (rootInfo.st_mode & S_IFMT) == S_IFDIR else { return false }
        var fileInfo = stat()
        guard lstat(url.path, &fileInfo) == 0, (fileInfo.st_mode & S_IFMT) == S_IFREG else { return false }
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let candidatePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        return candidatePath != rootPath && candidatePath.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }

    private func releaseDeleteScope() {
        if actionScopeHeld, let actionScopedRoot { actionScopedRoot.stopAccessingSecurityScopedResource() }
        actionScopeHeld = false
        actionScopedRoot = nil
    }

    private func releasePreviewScope() {
        if previewScopeHeld, let previewScopedRoot { previewScopedRoot.stopAccessingSecurityScopedResource() }
        previewScopeHeld = false
        previewScopedRoot = nil
    }

    private func showPreview(_ url: URL) {
        guard let selectedRoot else {
            status = copy("preview.unavailable")
            return
        }
        if previewScopeHeld, previewScopedRoot != selectedRoot { releasePreviewScope() }
        let alreadyScopedToRoot = previewScopeHeld && previewScopedRoot == selectedRoot
        let acquiredScope = alreadyScopedToRoot ? false : selectedRoot.startAccessingSecurityScopedResource()
        guard QuickLookCandidate.isAllowed(url, within: selectedRoot) else {
            if acquiredScope { selectedRoot.stopAccessingSecurityScopedResource() }
            status = copy("preview.unavailable")
            return
        }
        if acquiredScope {
            previewScopeHeld = true
            previewScopedRoot = selectedRoot
        }
        previewURL = url
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

    private func modified(_ result: ScanResult) -> String {
        guard let date = result.modifiedAt else { return copy("metrics.unknown") }
        return date.formatted(.dateTime.year().month().day().hour().minute().locale(Locale(identifier: french ? "fr_FR" : "en_US")))
    }

    private func allocated(_ result: ScanResult) -> Int64? {
        if case .known(let bytes) = result.allocatedBytes { return bytes }
        return nil
    }

    private func copy(_ key: String, count: Int? = nil) -> String {
        if key == "scan.count", let count { return french ? "\(count) fichiers mesurés" : "\(count) measured files" }
        return ProductCopy.value(for: key, french: french)
    }

    private func countedActionCopy(_ count: Int, key: String) -> String {
        let form = count == 1 ? "one" : "many"
        return "\(count) \(copy("\(key).\(form)"))"
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

    private func categoryName(_ value: ExploreFileCategory) -> String {
        switch value {
        case .all: french ? "Toutes les catégories" : "All categories"
        case .images: french ? "Images" : "Images"
        case .videos: french ? "Vidéos" : "Videos"
        case .audio: french ? "Audio" : "Audio"
        case .documents: french ? "Documents" : "Documents"
        case .archives: french ? "Archives" : "Archives"
        case .other: french ? "Autres extensions" : "Other extensions"
        }
    }

    private var categoryDescription: String {
        guard category != .all else {
            return french ? "Aucun filtre de type; fichiers avec ou sans extension inclus." : "No file-type filter; files with or without extensions are included."
        }
        guard category != .other else {
            return french
                ? "Extensions hors Images, Vidéos, Audio, Documents et Archives; fichiers sans extension inclus."
                : "Extensions outside Images, Videos, Audio, Documents, and Archives; files without an extension included."
        }
        let extensions = category.fileExtensions.map { ".\($0)" }.joined(separator: ", ")
        return french ? "Extensions incluses : \(extensions)." : "Included extensions: \(extensions)."
    }
}
