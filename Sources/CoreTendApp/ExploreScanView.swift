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

/// Explore, "les parcelles": a chosen folder surveyed file by file while its roots follow the real
/// progress, then the files as plots in proportion (they appear largest first), a list to sort,
/// filter, preview and mark as favorite, and a reviewed move to the macOS Trash where each moved
/// file falls as a leaf and each file that stays says why.
struct ExploreScanView: View {
    let french: Bool
    @Binding var recentFilesEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectingFolder = false
    @State private var scanning = false
    @State private var scanCompletedFiles = 0
    @State private var rootsPhase: ScanRootsPhase?
    @State private var results: [ScanResult] = []
    @State private var notice: PageNotice?
    @State private var scanFoundNothing = false
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
    @State private var moving = false
    @State private var actionScopeHeld = false
    @State private var actionScopedRoot: URL?
    @State private var viewVisible = false
    @State private var previewScopeHeld = false
    @State private var previewScopedRoot: URL?
    @State private var favoritePaths: Set<String> = []
    /// Files that stayed where they were after a move, with the copy key saying why.
    @State private var failures: [URL: String] = [:]
    @State private var flight = LeafFlight()
    /// The plot the reader pointed at on the map; its row is brought into view and outlined.
    @State private var focusedPath: String?
    /// The folder the map shows, from the chosen folder down; nil means the chosen folder.
    @State private var mapFolder: URL?
    /// Changes once per finished scan, so the plots appear (largest first) once per scan.
    @State private var mapSeed = UUID()
    @State private var scrollTarget: String?
    @State private var hoveredTile: String?

    private var locked: Bool { scanning || actionBusy || actionReview != nil }

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

    /// The plots of the folder the map shows: files there, and each subfolder as one plot.
    private var folderPlots: [FolderPlots.Plot] {
        guard let base = (mapFolder ?? selectedRoot)?.standardizedFileURL.path else { return [] }
        return FolderPlots.plots(files: visibleResults.map { ($0.url.standardizedFileURL.path, allocated($0)) }, under: base)
    }

    private var treemapInputs: [TreemapInput] {
        folderPlots.filter { $0.bytes > 0 }.map { TreemapInput(id: $0.path, bytes: $0.bytes, allocationIdentity: nil) }
    }

    private func isFolderPlot(_ path: String) -> Bool { folderPlots.first { $0.path == path }?.isFolder ?? false }

    var body: some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation(reduceMotion ? nil : MotionCurve.sap.animation(duration: MotionToken.grow.duration)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    scrollTarget = nil
                }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let selectedRoot {
                scope(selectedRoot)
            } else {
                SerreParcel {
                    SerreEmptyState(title: copy("explore.initial.title"), message: copy("explore.initial.message")) {
                        Button { selectingFolder = true } label: {
                            Label { Text(copy("explore.choose")) } icon: { SerreIcon(.explore, size: 15) }
                        }
                        .buttonStyle(.serre(.primary))
                        .accessibilityHint(copy("scan.choose.hint"))
                        .padding(.top, 6)
                    }
                }
            }
            if let notice, !notice.nearActions { banner(notice) }
            if let rootsPhase { roots(rootsPhase).id("explore.roots") }
            if scanFoundNothing {
                SerreEmptyState(title: copy("scan.empty"), message: copy("cleanup.none.help"))
            }
            // The files appear once the survey is done, largest plots first.
            if !scanning, !results.isEmpty || flight.landed > 0 {
                filters
                map
                list
                if let notice, notice.nearActions { banner(notice) }
                Text(french ? "Somme des octets locaux connus : \(ProductFormat.bytes(treemapInputs.reduce(0) { $0 + $1.bytes }, french: true)). Le nuage et les tailles inconnues ne sont pas estimés."
                            : "Known local bytes total: \(ProductFormat.bytes(treemapInputs.reduce(0) { $0 + $1.bytes }, french: false)). Cloud-backed and unknown sizes are not estimated.")
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
            }
        }
        .leafFlightLayer(flight)
        // The page's plant bends while the roots read and blooms when they are done.
        .preference(key: PlantActivityKey.self, value: rootsPhase == .reading ? .growing : (rootsPhase == .finished ? .blooming : .resting))
        .motion(.standard, value: notice)
        .motion(.standard, value: rootsPhase)
        .fileImporter(isPresented: $selectingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { outcome in
            switch outcome {
            case .success(let urls):
                guard let url = urls.first else { return }
                beginScan(url)
            case .failure:
                notice = PageNotice(kind: .error, title: copy("scan.failed"), recovery: .chooseAgain)
            }
        }
        // Fixture-only (captures): open the folder given by the environment, as if chosen.
        .task { if selectedRoot == nil, let root = CoreTendPreferences().fixtureScanRoot { beginScan(root) } }
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
                // Return cancels: a move to the Trash is only ever a deliberate click.
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(deleteReviewMessage)
        }
        .onChange(of: actionDialogPresented) { _, presented in
            if !presented && actionReview != nil { cancelDeleteAction() }
        }
    }

    // MARK: - Sections

    private func scope(_ root: URL) -> some View {
        SerreParcel {
            HStack(alignment: .center, spacing: 12) {
                SerreIcon(.explore, size: 18).foregroundStyle(Palette.accent.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(copy("explore.scope")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                    Text(SandboxAccess.displayPath(root)).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                        .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 8)
                Button(copy("explore.chooseOther")) { selectingFolder = true }
                    .buttonStyle(.serre(.secondary))
                    .disabled(locked)
                    .accessibilityHint(copy("scan.choose.hint"))
            }
        }
    }

    private func roots(_ phase: ScanRootsPhase) -> some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 12) {
                ScanRoots(completed: scanCompletedFiles,
                          count: ProductFormat.count(scanCompletedFiles, french: french),
                          caption: ProductFormat.filesExamined(scanCompletedFiles, french: french) + "\n"
                              + copy(phase == .finished ? "scan.finished" : "scan.reading"),
                          phase: phase)
                if phase == .reading {
                    Button(copy("scan.cancel")) { cancelScan() }
                        .buttonStyle(.serre(.secondary))
                }
            }
        }
        .transition(.opacity)
    }

    private func banner(_ notice: PageNotice) -> some View {
        PageNoticeBanner(notice: notice, french: french, disabled: locked, chooseAgain: { selectingFolder = true },
                         retryScan: selectedRoot.map { root in { beginScan(root) } })
    }

    private var filters: some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(copy("explore.filters")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                    Spacer()
                    Text(french ? "\(ProductFormat.items(visibleResults.count, french: true)) sur \(ProductFormat.count(results.count, french: true))"
                                : "\(ProductFormat.items(visibleResults.count, french: false)) of \(ProductFormat.count(results.count, french: false))")
                        .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                        .contentTransition(.numericText(value: Double(visibleResults.count)))
                }
                HStack(spacing: 10) {
                    SerreIcon(.search, size: 15).foregroundStyle(Palette.accent.color).accessibilityHidden(true)
                    TextField(copy("explore.search"), text: $query)
                        .textFieldStyle(.plain).font(CoreTendTypography.body)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Palette.raisedSurface.color, in: LeafCorner.control.shape)
                .overlay(LeafCorner.control.shape.strokeBorder(query.isEmpty ? Palette.strongSeparator.color : Palette.accent.color, lineWidth: 1))
                HStack(spacing: 12) {
                    Picker(copy("explore.sort"), selection: $sortMode) {
                        Text(copy("explore.largest")).tag("largest")
                        Text(copy("explore.oldest")).tag("oldest")
                        Text(copy("explore.name")).tag("name")
                    }
                    Picker(french ? "Catégorie" : "Category", selection: $category) {
                        ForEach(ExploreFileCategory.allCases, id: \.self) { value in
                            Text(categoryName(value)).tag(value)
                        }
                    }
                    Picker(french ? "Filtre" : "Filter", selection: $preset) {
                        Text(french ? "Tous" : "All files").tag(ExplorePreset.all)
                        Text(french ? "≥ 1 Gio local" : "≥ 1 GiB local").tag(ExplorePreset.largeLocal)
                        Text(french ? "Anciens · 365 jours" : "Older · 365 days").tag(ExplorePreset.olderThan365Days)
                    }
                    .onChange(of: preset) { _, _ in presetEvaluationDate = .now }
                }
                .pickerStyle(.menu)
                .font(CoreTendTypography.secondary)
                .tint(Palette.accent.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(categoryDescription)
                    Text(presetDescription)
                }
                .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(locked)
    }

    /// The files as plots in proportion to their known local size. They appear largest first,
    /// once per scan; pointing at one names it, choosing one brings its row into view.
    private var map: some View {
        VStack(alignment: .leading, spacing: 8) {
            breadcrumb
            HStack(alignment: .firstTextBaseline) {
                Text(copy("explore.map")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                Spacer()
                Text(hoveredLabel ?? (french ? "\(treemapInputs.count) allocations connues" : "\(treemapInputs.count) known allocations"))
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .lineLimit(1).truncationMode(.middle)
            }
            GeometryReader { proxy in
                let tiles = TreemapLayout.tiles(for: treemapInputs, size: proxy.size)
                let order = Dictionary(uniqueKeysWithValues: tiles.sorted { $0.bytes > $1.bytes }.enumerated().map { ($1.id, $0) })
                ZStack(alignment: .topLeading) {
                    ForEach(tiles) { tile in
                        plot(tile, rank: order[tile.id] ?? 0)
                    }
                }
                .id(mapSeed)
            }
            .frame(height: 240)
            .padding(8)
            .background(Palette.deep.color, in: LeafCorner.parcel.shape)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(copy("explore.map"))
            Text(copy("explore.map.help")).font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
        }
    }

    /// Where the map stands, from the chosen folder down; each step takes you back up.
    private var breadcrumb: some View {
        let root = selectedRoot?.standardizedFileURL
        let current = (mapFolder ?? root)?.standardizedFileURL
        var steps: [URL] = []
        if let root, let current {
            var cursor = current
            while cursor.path.count >= root.path.count {
                steps.insert(cursor, at: 0)
                if cursor.path == root.path { break }
                cursor = cursor.deletingLastPathComponent()
            }
        }
        return HStack(spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.element.path) { index, step in
                if index > 0 { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Palette.tertiaryInk.color) }
                Button(step.lastPathComponent) { enter(step.path == root?.path ? nil : step) }
                    .buttonStyle(.serre(.icon))
                    .disabled(index == steps.count - 1)
            }
            Spacer()
        }
    }

    private func enter(_ folder: URL?) {
        withAnimation(reduceMotion ? nil : MotionCurve.sap.animation(duration: MotionToken.grow.duration)) {
            mapFolder = folder
            focusedPath = nil
            mapSeed = UUID()
        }
    }

    private var hoveredLabel: String? {
        guard let hoveredTile, let input = treemapInputs.first(where: { $0.id == hoveredTile }) else { return nil }
        return "\(URL(fileURLWithPath: hoveredTile).lastPathComponent) · \(ProductFormat.bytes(input.bytes, french: french))"
    }

    private func plot(_ tile: TreemapTile, rank: Int) -> some View {
        let radius = min(10, min(tile.frame.width, tile.frame.height) / 3)
        let shape = UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: radius / 3,
                                           bottomTrailingRadius: radius, topTrailingRadius: radius / 3, style: .continuous)
        let hovered = hoveredTile == tile.id
        let focused = focusedPath == tile.id
        // Larger plots are greener; the eye reads the biggest first.
        let strength = max(0.18, 0.62 - Double(min(rank, 12)) * 0.035)
        let folder = isFolderPlot(tile.id)
        return Button {
            if folder { enter(URL(fileURLWithPath: tile.id, isDirectory: true)) } else {
                focusedPath = tile.id
                scrollTarget = "explore.list"
            }
        } label: {
            shape
                .fill(Palette.accent.color.opacity(hovered || focused ? strength + 0.2 : strength))
                .overlay(shape.strokeBorder(focused ? Palette.ink.color : Palette.deep.color.opacity(0.6), lineWidth: focused ? 2 : 1))
                .overlay(alignment: .topLeading) {
                    if tile.frame.width > 90 && tile.frame.height > 38 {
                        VStack(alignment: .leading, spacing: 1) {
                            Text((folder ? "▸ " : "") + URL(fileURLWithPath: tile.id).lastPathComponent).font(CoreTendTypography.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(ProductFormat.bytes(tile.bytes, french: french)).font(CoreTendTypography.caption)
                        }
                        .foregroundStyle(Palette.ink.color)
                        .padding(6)
                    }
                }
        }
        .buttonStyle(PlotButtonStyle())
        .frame(width: max(tile.frame.width - 2, 1), height: max(tile.frame.height - 2, 1))
        // Hover and click stay inside the plot: `position` below would stretch them over the map.
        .onHover { inside in hoveredTile = inside ? tile.id : (hoveredTile == tile.id ? nil : hoveredTile) }
        .accessibilityLabel("\(URL(fileURLWithPath: tile.id).lastPathComponent), \(ProductFormat.bytes(tile.bytes, french: french))")
        .accessibilityHint(folder ? (french ? "Entre dans ce dossier." : "Opens this folder.") : (french ? "Montre ce fichier dans la liste." : "Shows this file in the list."))
        .serreRise(rank)
        .position(x: tile.frame.midX, y: tile.frame.midY)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear.frame(height: 0).id("explore.list")
            HStack(alignment: .firstTextBaseline) {
                Text(copy("explore.results")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                Spacer()
                Text(french ? "Aucune sélection automatique" : "Nothing selected automatically")
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                Button(copy("cleanup.selectNone")) { selectedExploreFiles = [] }
                    .buttonStyle(.serre(.icon)).disabled(locked || selectedExploreFiles.isEmpty)
                    .opacity(selectedExploreFiles.isEmpty ? 0 : 1)
            }
            if visibleResults.isEmpty {
                SerreEmptyState(title: copy("explore.filterEmpty"), message: copy("explore.filterEmpty.help"))
            } else {
                ScrollViewReader { rows in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(visibleResults, id: \.url) { row($0).id("explore.row.\($0.url.path)") }
                        }
                        .padding(8)
                    }
                    .onChange(of: focusedPath) { _, path in
                        guard let path else { return }
                        withAnimation(reduceMotion ? nil : MotionCurve.sap.animation(duration: MotionToken.standard.duration)) {
                            rows.scrollTo("explore.row.\(path)", anchor: .center)
                        }
                    }
                }
                .frame(height: min(CGFloat(visibleResults.count) * 52 + 16, 380))
                .background(Palette.surface.color, in: LeafCorner.parcel.shape)
                .overlay(LeafCorner.parcel.shape.strokeBorder(Palette.separator.color, lineWidth: 1))
                .leafFlightAnchor("list")
            }
            HStack(spacing: 14) {
                TrashIndicator(landed: flight.landed, moving: moving, french: french)
                Spacer()
                Button { Task { await prepareDeleteReview() } } label: {
                    Text(french ? "Examiner \(ProductFormat.items(selectedExploreFiles.count, french: true))"
                                : "Review \(ProductFormat.items(selectedExploreFiles.count, french: false))")
                }
                .buttonStyle(.serre(.primary))
                .disabled(selectedExploreFiles.isEmpty || locked)
                .accessibilityHint(french ? "Aucun élément n’est déplacé avant confirmation." : "No item moves before confirmation.")
            }
        }
    }

    private func row(_ result: ScanResult) -> some View {
        let selectable = isSelectableExploreResult(result)
        let selected = selectedExploreFiles.contains(result.url)
        let failure = failures[result.url]
        let favorite = favoritePaths.contains(result.url.path)
        return HStack(spacing: 8) {
            Button {
                guard selectable, !locked else { return }
                if selected { selectedExploreFiles.remove(result.url) } else { selectedExploreFiles.insert(result.url) }
            } label: {
                rowLabel(result, selectable: selectable, selected: selected, failure: failure)
            }
            .buttonStyle(.serre(.row(selected: selected)))
            .disabled(locked || !selectable)
            .accessibilityLabel(ProductCopy.scanResultAccessibilitySummary(
                name: result.url.lastPathComponent,
                source: french ? "Explorer" : "Explore",
                state: french ? "Résultat mesuré" : "Measured result",
                allocated: size(result.allocatedBytes), logical: size(result.logicalBytes),
                modified: modified(result), french: french
            ))
            .accessibilityValue(failure.map { copy($0) } ?? "")
            .accessibilityAddTraits(selected ? .isSelected : [])
            rowTools(result, favorite: favorite)
        }
        .overlay {
            if failure != nil { LeafCorner.control.shape.strokeBorder(Palette.danger.color, lineWidth: 1) }
            else if focusedPath == result.url.path { LeafCorner.control.shape.strokeBorder(Palette.accent.color, lineWidth: 1.5) }
        }
        .leafFlightRow(result.url)
        .transition(reduceMotion ? .identity : .asymmetric(insertion: .identity, removal: .opacity.combined(with: .scale(scale: 0.6, anchor: .leading))))
    }

    private func rowLabel(_ result: ScanResult, selectable: Bool, selected: Bool, failure: String?) -> some View {
        HStack(spacing: 12) {
            SerreCheck(isOn: selected).opacity(selectable ? 1 : 0.35)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.url.lastPathComponent).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                    .lineLimit(1).truncationMode(.middle)
                Text(relativeFolder(result.url) + " · " + (french ? "modifié \(modified(result))" : "modified \(modified(result))"))
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .lineLimit(1).truncationMode(.middle)
                if let failure {
                    Text(copy(failure)).font(CoreTendTypography.caption).foregroundStyle(Palette.danger.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(size(result.allocatedBytes)).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                Text(french ? "logique \(size(result.logicalBytes))" : "logical \(size(result.logicalBytes))")
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
            }
            .monospacedDigit()
        }
    }

    private func rowTools(_ result: ScanResult, favorite: Bool) -> some View {
        HStack(spacing: 8) {
            Button { Task { await toggleFavorite(result) } } label: {
                Image(systemName: favorite ? "star.fill" : "star")
                    .foregroundStyle(favorite ? Palette.caution.color : Palette.secondaryInk.color)
            }
            .buttonStyle(.serre(.icon))
            .help(copy(favorite ? "explore.favorite.remove" : "explore.favorite.add"))
            .accessibilityLabel(favorite
                ? (french ? "Retirer \(result.url.lastPathComponent) des favoris" : "Remove \(result.url.lastPathComponent) from favorites")
                : (french ? "Ajouter \(result.url.lastPathComponent) aux favoris" : "Add \(result.url.lastPathComponent) to favorites"))
            Button { showPreview(result.url) } label: {
                Image(systemName: "eye").foregroundStyle(Palette.secondaryInk.color)
            }
            .buttonStyle(.serre(.icon))
            .help(copy("explore.preview"))
            .accessibilityLabel(previewLabel(for: result.url))
            .accessibilityHint(french ? "Ouvre l’aperçu Quick Look." : "Opens the Quick Look preview.")
        }
    }

    private func relativeFolder(_ url: URL) -> String {
        guard let root = selectedRoot else { return url.deletingLastPathComponent().path }
        let folder = url.deletingLastPathComponent().standardizedFileURL.path
        let base = root.standardizedFileURL.path
        guard folder.hasPrefix(base) else { return folder }
        let rest = folder.dropFirst(base.count).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return rest.isEmpty ? root.lastPathComponent : root.lastPathComponent + "/" + rest
    }

    // MARK: - Scanning

    private func beginScan(_ root: URL) {
        scanTask?.cancel()
        previewURL = nil
        selectedRoot = root
        mapFolder = nil
        let scanID = UUID()
        activeScanID = scanID
        let acquiredScope = root.startAccessingSecurityScopedResource()
        selectedRootIdentity = try? FileIdentity(url: root)
        results = []
        selectedExploreFiles = []
        failures = [:]
        flight.landed = 0
        focusedPath = nil
        scanCompletedFiles = 0
        notice = nil
        scanFoundNothing = false
        scanning = true
        rootsPhase = .reading
        scrollTarget = "explore.roots"
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
                        if let rootFailure {
                            rootsPhase = nil
                            notice = PageNotice(kind: .denied, title: ProductCopy.scanRootFailure(reason: rootFailure, french: french),
                                                recovery: .chooseAgain)
                        } else {
                            rootsPhase = .finished
                            // Bring the finished roots and the plots under them into view.
                            // A fresh request on the next turn: a quick scan can end in the same update as the one
                            // that scrolled at its start, and an unchanged value would not scroll again.
                            scrollTarget = nil
                            Task { @MainActor in scrollTarget = "explore.roots" }
                            mapSeed = UUID()
                            if !partialFailures.isEmpty {
                                notice = PageNotice(kind: .partial, title: copy("scan.partial"),
                                                    message: ProductCopy.scanPartialFailure(reasons: partialFailures, french: french))
                            }
                            scanFoundNothing = results.isEmpty && partialFailures.isEmpty
                        }
                    case .progress(let completed): scanCompletedFiles = completed
                    }
                }
            } catch is CancellationError {
                if activeScanID == scanID { notice = PageNotice(kind: .note, title: copy("scan.cancelled")) }
            } catch {
                if activeScanID == scanID {
                    rootsPhase = nil
                    notice = PageNotice(kind: .error, title: copy("scan.failed"), recovery: .retryScan)
                }
            }
        }
    }

    private func cancelScan() {
        scanTask?.cancel()
        activeScanID = nil
        scanning = false
        results = []
        notice = PageNotice(kind: .note, title: copy("scan.cancelled"))
        // The roots withdraw, then their parcel goes.
        rootsPhase = .retracted
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 450))
            if rootsPhase == .retracted { rootsPhase = nil; scanCompletedFiles = 0 }
        }
    }

    // MARK: - Review and move

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
            notice = PageNotice(kind: .error, title: french ? "La sélection a changé; aucune action proposée." : "The selection changed; no action was proposed.", nearActions: true)
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
                notice = PageNotice(kind: .error, title: copy("spacelens.delete.blocked"), nearActions: true)
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
            notice = PageNotice(kind: .error, title: french ? "Impossible d’examiner la sélection; aucun fichier déplacé." : "Review failed; no files moved.", nearActions: true)
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
        moving = true
        defer { moving = false; actionBusy = false; releaseDeleteScope() }
        let batch: ConfirmedActionBatch
        do { batch = try service.confirm(review, accepted: true) } catch {
            notice = PageNotice(kind: .error, title: french ? "Action refusée; aucun fichier déplacé." : "Action refused; no files moved.", nearActions: true)
            return
        }
        failures = [:]; flight.landed = 0; notice = nil
        // Each item arrives when its outcome is final, so a leaf falls only for a file that moved.
        let report = await executeShowingEachItem(service, batch, reduceMotion: reduceMotion) { item in
            let url = item.targetURL
            guard item.moved else {
                failures[url] = item.failureKey
                selectedExploreFiles.remove(url)
                return
            }
            flight.send(url, reduceMotion: reduceMotion)
            withAnimation(reduceMotion ? nil : MotionCurve.retreat.animation(duration: 0.2)) {
                results.removeAll { $0.url == url }
                selectedExploreFiles.remove(url)
            }
        }
        notice = .moveOutcome(report, french: french)
    }

    private func cancelDeleteAction() {
        guard let review = actionReview, let service = actionService else { return }
        actionBusy = true
        actionDialogPresented = false
        actionReview = nil
        actionService = nil
        Task { @MainActor in
            let recorded = await service.recordCancellation(review)
            notice = PageNotice(kind: .note, title: copy(recorded ? "spacelens.delete.cancelled" : "spacelens.delete.cancelled.unrecorded"), nearActions: true)
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
            notice = PageNotice(kind: .error, title: copy("preview.unavailable"), nearActions: true)
            return
        }
        if previewScopeHeld, previewScopedRoot != selectedRoot { releasePreviewScope() }
        let alreadyScopedToRoot = previewScopeHeld && previewScopedRoot == selectedRoot
        let acquiredScope = alreadyScopedToRoot ? false : selectedRoot.startAccessingSecurityScopedResource()
        guard QuickLookCandidate.isAllowed(url, within: selectedRoot) else {
            if acquiredScope { selectedRoot.stopAccessingSecurityScopedResource() }
            notice = PageNotice(kind: .error, title: copy("preview.unavailable"), nearActions: true)
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
        } catch { notice = PageNotice(kind: .error, title: french ? "Favori non enregistré." : "Favorite was not saved.", nearActions: true) }
    }

    @MainActor private func loadFavorites() async {
        guard let store = try? await LocalStoreAccess.open(), let records = try? await store.savedFiles() else { return }
        favoritePaths = Set(records.filter(\.isFavorite).map(\.path))
    }

    private func size(_ measurement: ProductMeasurement<Int64>) -> String {
        switch measurement {
        case .known(let bytes): ProductFormat.bytes(bytes, french: french)
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

/// A plot of the map as a button: it gives a little when pressed.
private struct PlotButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(MotionToken.press.animation(reduceMotion: reduceMotion), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}
