// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import ScanCore
import FinderShared
import SafetyCore
import DesignSystem
import Persistence
import QuickLookUI
import QuickLook

@MainActor
@Observable
final class SpaceLensViewModel {
    enum Phase: Equatable { case idle, scanning(items: Int), ready }

    var phase: Phase = .idle
    var root: SpaceNode?
    var pathStack: [SpaceNode] = []     // navigation into subdirectories
    /// Set only while a delete confirmation sheet is up; nil the rest of the time.
    var pendingDelete: SpaceNode?
    var lastDeleteError: String?
    var isScanPaused = false
    /// Shared single-click selection — the bubble canvas and the list both
    /// read and write this, so they always agree. Sidebar module selection
    /// is a different piece of state entirely and is never touched here.
    var selectionID: String?
    /// Friendly "where the scan is right now" label (never a raw full path).
    var scanningLocation: String = ""
    /// When the current scan began — the scanning view derives elapsed time
    /// from this, so there is no fabricated percentage anywhere.
    private(set) var scanStartedAt: Date?
    private var scanTask: Task<Void, Never>?
    private var pauseController: ScanPauseController?
    private var rootURL: URL?

    // Live partial-tree publication is throttled so a fast scan can't drive
    // SwiftUI at hundreds of updates per second. Domain correctness is never
    // throttled — only how often the presentation root is swapped.
    @ObservationIgnored private let partialThrottle: TimeInterval
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var lastPartialAt: Date = .distantPast
    /// Test seam: how many partial snapshots were actually published.
    @ObservationIgnored private(set) var publishedPartialCount = 0

    init(partialThrottle: TimeInterval = 0.125, clock: @Sendable @escaping () -> Date = Date.init) {
        self.partialThrottle = partialThrottle
        self.clock = clock
    }

    var current: SpaceNode? { pathStack.last ?? root }

    /// The bounded, value-typed projection of the current directory the UI
    /// renders. Never the raw hierarchy.
    func scope(filter: String,
               visualLimit: Int = SpaceLensAggregator.defaultVisualLimit,
               listLimit: Int = SpaceLensAggregator.defaultListLimit) -> SpaceLensScope {
        guard let current else { return .empty }
        let parentID: String?
        if pathStack.count >= 2 { parentID = pathStack[pathStack.count - 2].path }
        else if pathStack.count == 1 { parentID = root?.path }
        else { parentID = nil }
        return SpaceLensAggregator.scope(
            for: current, parentID: parentID, depth: pathStack.count,
            filter: filter, visualLimit: visualLimit, listLimit: listLimit)
    }

    /// Drill by node id (double-click / Return). Files and the synthetic
    /// "Other" bucket never drill.
    func drill(nodeID: String) {
        guard let current,
              let child = current.children.first(where: { $0.path == nodeID }),
              child.isDirectory,
              !child.path.hasSuffix("\u{2026}other"),
              !child.children.isEmpty
        else { return }
        selectionID = nil
        descend(into: child)
    }

    private var scanGeneration = UUID()

    func start(url: URL, recordVisit: Bool = true) {
        let generation = UUID()
        scanGeneration = generation
        scanTask?.cancel()
        phase = .scanning(items: 0)
        root = nil
        pathStack = []
        selectionID = nil
        scanningLocation = ""
        scanStartedAt = clock()
        lastPartialAt = .distantPast
        publishedPartialCount = 0
        rootURL = url
        isScanPaused = false
        let pauseController = ScanPauseController()
        self.pauseController = pauseController
        let engine = SpaceLensEngine(root: url)
        scanTask = Task {
            if !recordVisit {
                guard url.isFileURL,
                      case .success = SelectionValidator.validate(path: url.path, for: .scanFolder) else {
                    phase = .idle
                    rootURL = nil
                    AppRouter.shared.finderSelectionRejected = true
                    return
                }
            }
            for await event in engine.run(pauseController: pauseController) {
                guard !Task.isCancelled, scanGeneration == generation else { return }
                switch event {
                case let .progress(items, path):
                    phase = .scanning(items: items)
                    scanningLocation = Self.friendlyLocation(path)
                case let .partial(node):
                    applyPartial(node)
                case let .finished(node):
                    root = node
                    phase = .ready
                    if recordVisit {
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Space Lens: \(node.name) — \(mcFormatBytes(node.size))",
                        itemCount: node.children.count, bytes: node.size))
                    AppEnvironment.shared.recordLocationVisit(path: url.path, bytes: node.size)
                    }
                case .cancelled:
                    isScanPaused = false
                    phase = root == nil ? .idle : .ready
                }
            }
        }
    }

    /// Publish a live partial root, throttled to `partialThrottle`. During a
    /// scan there is no navigation depth yet, so this only ever replaces the
    /// top-level root the `scanningView` reads. `internal` for the throttle
    /// test (which drives it with an injected clock).
    func applyPartial(_ node: SpaceNode) {
        guard pathStack.isEmpty else { return }
        let now = clock()
        guard now.timeIntervalSince(lastPartialAt) >= partialThrottle else { return }
        lastPartialAt = now
        publishedPartialCount += 1
        root = node
    }

    /// A short, privacy-safe "~/Library/Caches/…" style label — never the raw
    /// absolute path, which can be long and expose account details.
    static func friendlyLocation(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        let abbreviated = (path as NSString).abbreviatingWithTildeInPath
        let parts = abbreviated.split(separator: "/").suffix(3)
        return parts.joined(separator: "/")
    }

    /// Re-runs the scan from the same root, preserving the current navigation
    /// depth where possible, so a delete's effect on sizes/listing is real
    /// rather than a locally-patched guess.
    private func rescanPreservingDepth() {
        guard let rootURL else { return }
        let depth = pathStack.count
        let pathsToRestore = pathStack.map(\.path)
        scanTask?.cancel()
        phase = .scanning(items: 0)
        isScanPaused = false
        let pauseController = ScanPauseController()
        self.pauseController = pauseController
        let engine = SpaceLensEngine(root: rootURL)
        scanTask = Task {
            for await event in engine.run(pauseController: pauseController) {
                if case let .finished(node) = event {
                    root = node
                    var stack: [SpaceNode] = []
                    var cursor = node
                    for path in pathsToRestore.prefix(depth) {
                        guard let match = cursor.children.first(where: { $0.path == path }) else { break }
                        stack.append(match)
                        cursor = match
                    }
                    pathStack = stack
                    phase = .ready
                }
            }
        }
    }

    func pauseScan() {
        guard case .scanning = phase, !isScanPaused else { return }
        isScanPaused = true
        Task { await pauseController?.pause() }
    }

    func resumeScan() {
        guard case .scanning = phase, isScanPaused else { return }
        isScanPaused = false
        Task { await pauseController?.resume() }
    }

    func cancel() {
        isScanPaused = false
        scanTask?.cancel()
        Task { await pauseController?.resume() }
    }

    func descend(into node: SpaceNode) {
        guard node.isDirectory, !node.children.isEmpty || node.size > 0 else { return }
        if !node.children.isEmpty { pathStack.append(node) }
    }

    func pop(to index: Int?) {
        if let index { pathStack = Array(pathStack.prefix(index + 1)) } else { pathStack = [] }
    }

    func requestDelete(_ node: SpaceNode) {
        guard !node.path.hasSuffix("\u{2026}other") else { return }
        pendingDelete = node
    }

    /// Trashes the node approved via `pendingDelete`, scoped to the original
    /// scan root so this can never reach outside the tree being browsed.
    func confirmDelete() {
        guard let node = pendingDelete, let rootURL else { return }
        pendingDelete = nil
        Task {
            let validator = PathValidator(allowedRoots: [rootURL])
            let center = SafetyCenter(validator: validator, sink: AppEnvironment.shared.store)
            guard let op = try? await center.approve(
                url: URL(fileURLWithPath: node.path), logicalSize: node.size,
                ruleID: "spacelens.delete", risk: .medium
            ) else {
                lastDeleteError = node.name
                return
            }
            let result = await center.execute([op])
            let freed = result.executed.reduce(0) { $0 + $1.logicalSize }
            AppEnvironment.shared.record(ActivityRecord(
                kind: .cleanup,
                summary: "Space Lens: moved \(node.name) to Trash (\(mcFormatBytes(freed)))",
                itemCount: result.executed.count, bytes: freed))
            if !result.executed.isEmpty {
                rescanPreservingDepth()
            }
        }
    }
}

/// Radial "point of focus" packing for Space Lens — the biggest folder sits
/// dead centre and its siblings cluster outward around it, each bubble's area
/// proportional to its byte size. Pure geometry so it can be reasoned about
/// (and unit-tested) without a view.
enum RadialPack {
    struct Bubble: Identifiable {
        let id: String
        let node: SpaceLensNode
        let center: CGPoint
        let radius: CGFloat
    }

    /// Deterministic: the input order (largest first, ties by path) fixes the
    /// spiral slot for every id, so a partial-scan update or a re-filter does
    /// not reshuffle bubbles that were already placed.
    static func pack(_ nodes: [SpaceLensNode], in size: CGSize, limit: Int = 40) -> [Bubble] {
        guard size.width > 8, size.height > 8, !nodes.isEmpty else { return [] }
        let items = Array(nodes.prefix(limit))
        let maxByte = Double(max(items.first?.logicalBytes ?? 1, 1))
        let shortSide = min(size.width, size.height)
        let maxR = shortSide * 0.27
        let minR: CGFloat = 12
        let gap: CGFloat = 6
        let mid = CGPoint(x: size.width / 2, y: size.height / 2)

        func radius(for node: SpaceLensNode) -> CGFloat {
            let frac = (Double(max(node.logicalBytes, 1)) / maxByte).squareRoot()   // area ∝ bytes
            return max(minR, min(maxR, CGFloat(frac) * maxR))
        }

        var placed: [Bubble] = []
        for (i, node) in items.enumerated() {
            let r = radius(for: node)
            guard i > 0 else {
                placed.append(Bubble(id: node.id, node: node, center: mid, radius: r))
                continue
            }
            // Walk outward along a golden-angle spiral until the disc clears
            // every placed disc and stays on-canvas.
            var angle = Double(i) * 2.399963
            var dist = (placed.first?.radius ?? r) + r + gap
            var spot = mid
            var settled = false
            var steps = 0
            while !settled && steps < 6000 {
                let p = CGPoint(x: mid.x + CGFloat(cos(angle)) * dist,
                                y: mid.y + CGFloat(sin(angle)) * dist)
                let onCanvas = p.x - r >= 0 && p.x + r <= size.width
                    && p.y - r >= 0 && p.y + r <= size.height
                let clears = placed.allSatisfy { hypot($0.center.x - p.x, $0.center.y - p.y) >= $0.radius + r + gap }
                if onCanvas && clears { spot = p; settled = true }
                else { angle += 0.32; dist += 1.4 }
                steps += 1
            }
            if !settled {
                spot = CGPoint(x: mid.x + CGFloat(cos(angle)) * dist,
                               y: mid.y + CGFloat(sin(angle)) * dist)
            }
            placed.append(Bubble(id: node.id, node: node, center: spot, radius: r))
        }
        return placed
    }
}

/// Semantic color-by-type for Space Lens bubbles — never arbitrary index cycling.
enum SpaceNodeCategory: String, Hashable {
    case folder, media, document, archive, code, other

    var label: String {
        switch self {
        case .folder: L("spacelens.category.folder")
        case .media: L("spacelens.category.media")
        case .document: L("spacelens.category.document")
        case .archive: L("spacelens.category.archive")
        case .code: L("spacelens.category.code")
        case .other: L("spacelens.category.other")
        }
    }

    static func of(_ node: SpaceNode) -> SpaceNodeCategory {
        if node.isDirectory { return .folder }
        switch (node.name as NSString).pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "heic", "gif", "mov", "mp4", "mp3", "m4a", "wav": return .media
        case "pdf", "doc", "docx", "pages", "txt", "rtf", "key", "numbers", "xlsx": return .document
        case "zip", "dmg", "pkg", "tar", "gz": return .archive
        case "swift", "py", "js", "ts", "m", "h", "json", "yml", "c", "cpp": return .code
        default: return .other
        }
    }

    var color: Color {
        switch self {
        case .folder: return MCTheme.accent
        case .media: return MCColor.cellTealDeep
        case .document: return MCColor.cellGraphite
        case .archive: return MCTheme.warning
        case .code: return MCColor.cellTealPale
        case .other: return .secondary
        }
    }
}

struct SpaceLensView: View {
    @State private var model = SpaceLensViewModel()
    @Namespace private var zoomSpace
    @State private var hoveredID: String?
    @State private var previewURL: URL?
    @State private var searchText = ""
    @State private var searchDebounced = ""
    @State private var categoryFilter: SpaceNodeCategory?
    @State private var exclusionsController = ClutterExclusionsController()
    @State private var showFavoritesRecents = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The bubble-canvas bound. Kept well under the domain model's 40-node
    /// ceiling: past ~14 circles the radial pack runs out of clear on-canvas
    /// slots and the map stops being readable. Anything beyond this rolls
    /// into the on-canvas "Other" bubble; the precise list (bound 120) still
    /// shows the long tail.
    private let visualLimit = 14

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .idle: idleView
            case let .scanning(items): scanningView(items)
            case .ready: readyView
            }
        }
        .navigationTitle(L("spacelens.title"))
        .toolbar {
            ToolbarItem {
                Button {
                    showFavoritesRecents = true
                } label: {
                    Label(L("spacelens.favorites_recents"), systemImage: "star")
                }
                .accessibilityIdentifier("spacelens.favoritesRecents.open")
            }
        }
        // Favorites/Recents jumps back into Space Lens via .mcOpenSpaceLensAt
        // (handled below), so it's presented from here rather than living as
        // its own sidebar module.
        .sheet(isPresented: $showFavoritesRecents) {
            NavigationStack {
                FavoritesRecentsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L("common.done")) { showFavoritesRecents = false }
                        }
                    }
            }
            .frame(minWidth: 480, minHeight: 420)
        }
        .task { await exclusionsController.load() }
        .confirmationDialog(
            model.pendingDelete.map { L("spacelens.delete.confirm_title", $0.name) } ?? "",
            isPresented: Binding(get: { model.pendingDelete != nil }, set: { if !$0 { model.pendingDelete = nil } }),
            presenting: model.pendingDelete
        ) { node in
            Button(L("spacelens.delete.confirm_action"), role: .destructive) {
                model.confirmDelete()
            }
            Button(L("common.cancel"), role: .cancel) { model.pendingDelete = nil }
        } message: { node in
            Text(L("spacelens.delete.confirm_message", mcFormatBytes(node.size)))
        }
        .alert(L("spacelens.delete.error_title"), isPresented: Binding(
            get: { model.lastDeleteError != nil }, set: { if !$0 { model.lastDeleteError = nil } }
        )) {
            Button(L("common.done"), role: .cancel) {}
        } message: {
            Text(L("spacelens.delete.error_message", model.lastDeleteError ?? ""))
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcOpenSpaceLensAt)) { note in
            if let url = note.object as? URL {
                if note.userInfo?["finder"] as? Bool == true {
                    guard let selected = AppRouter.shared.consumePendingFolderScanURL() else { return }
                    model.start(url: selected, recordVisit: false)
                } else {
                    model.start(url: url)
                }
                showFavoritesRecents = false
            }
        }
        .onAppear {
            // Cold launch / not-yet-mounted: a Finder "Scan Folder" route
            // left a validated folder URL for us to pick up. Read-only scan.
            if let url = AppRouter.shared.consumePendingFolderScanURL() {
                model.start(url: url, recordVisit: false)
                showFavoritesRecents = false
            }
        }
        .accessibilityIdentifier("spacelens.root")
    }

    private var idleView: some View {
        GeometryReader { proxy in
        ScrollView {
            VStack(spacing: MCSpacing.xl) {
                VStack(spacing: MCSpacing.xs) {
                    Text(L("spacelens.idle.title"))
                        .font(MCFont.pageTitle)
                        .multilineTextAlignment(.center)
                    Text(L("spacelens.idle.subtitle"))
                        .font(MCFont.secondaryBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .mcAppear()

                MCScanButton(L("spacelens.scan_home"), systemImage: "circle.hexagongrid") {
                    model.start(url: FileManager.default.homeDirectoryForCurrentUser)
                }
                .accessibilityIdentifier("spacelens.scan.home")
                .mcAppear(delay: 0.06)

                Button(L("spacelens.choose_folder")) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK, let url = panel.url {
                        model.start(url: url)
                    }
                }
                .buttonStyle(.link)

                MCCard {
                    VStack(alignment: .leading, spacing: MCSpacing.sm) {
                        MCSectionHeader(L("spacelens.filter_category"))
                        MCFeatureRow(L("spacelens.category.folder"),
                                     icon: "folder.fill", iconColor: MCTheme.accent)
                        MCFeatureRow(L("spacelens.category.media"),
                                     icon: "photo", iconColor: MCColor.cellTealDeep)
                        MCFeatureRow(L("spacelens.category.document"),
                                     icon: "doc.text", iconColor: MCColor.cellGraphite)
                        MCFeatureRow(L("spacelens.category.archive"),
                                     icon: "archivebox", iconColor: MCTheme.warning)
                        MCFeatureRow(L("spacelens.category.code"),
                                     icon: "curlybraces", iconColor: MCColor.cellTealPale)
                    }
                }
                .frame(maxWidth: 480)
                .mcAppear(delay: 0.12)
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
        }
        }
    }


    // MARK: - Scanning (real partial state, no fabricated percentage)

    private func scanningView(_ items: Int) -> some View {
        VStack(spacing: MCSpacing.lg) {
            MCScanStage(isScanning: !model.isScanPaused) {
                VStack(spacing: 4) {
                    Text(L("spacelens.scanning_progress", items)).monospacedDigit()
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(L("spacelens.elapsed",
                               smartScanElapsedText(Date().timeIntervalSince(model.scanStartedAt ?? Date()))))
                            .font(MCFont.badge).foregroundStyle(.secondary).monospacedDigit()
                    }
                    if !model.scanningLocation.isEmpty {
                        Text(L("spacelens.scanning_location", model.scanningLocation))
                            .font(MCFont.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.head)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L("spacelens.scanning_progress", items))

            if let partial = model.root, !partial.children.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("spacelens.partial_top"))
                        .font(MCFont.badge).textCase(.uppercase).kerning(0.4)
                        .foregroundStyle(.secondary)
                    ForEach(partial.children.prefix(5), id: \.id) { child in
                        HStack(spacing: MCSpacing.xs) {
                            Image(systemName: child.isDirectory ? "folder" : "doc")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(child.name).font(MCFont.caption).lineLimit(1)
                            Spacer()
                            Text(mcFormatBytes(child.size)).font(MCFont.caption)
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 360)
                .accessibilityElement(children: .combine)
            }

            HStack(spacing: MCSpacing.sm) {
                if model.isScanPaused {
                    Button(L("common.resume")) { model.resumeScan() }
                        .keyboardShortcut("r", modifiers: [])
                        .help(L("spacelens.resume_hint"))
                        .accessibilityHint(L("spacelens.resume_hint"))
                        .accessibilityIdentifier("spacelens.scan.resume")
                } else {
                    Button(L("common.pause")) { model.pauseScan() }
                        .keyboardShortcut("p", modifiers: [])
                        .help(L("spacelens.pause_hint"))
                        .accessibilityHint(L("spacelens.pause_hint"))
                        .accessibilityIdentifier("spacelens.scan.pause")
                }
                Button(L("common.cancel")) { model.cancel() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("spacelens.scan.cancel")
            }
        }
        // Local scroll host — centred detail state with focusable controls;
        // keeps AppKit's first-responder reveal off the sidebar.
        .mcCenteredScrollState()
    }

    // MARK: - Ready (bounded explorer)

    @ViewBuilder
    private var readyView: some View {
        if model.current != nil {
            let scope = model.scope(filter: searchDebounced, visualLimit: visualLimit)
            VStack(alignment: .leading, spacing: 0) {
                breadcrumb
                    .padding(.horizontal).padding(.vertical, 8)
                if scope.foldedIntoOther > 0 {
                    Text(L("spacelens.folded_note", scope.foldedIntoOther))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                        .padding(.horizontal).padding(.bottom, 4)
                }
                searchAndFilterRow
                    .padding(.horizontal).padding(.bottom, 8)
                bubbleCanvas(scope)
                    .padding(.horizontal)
                Divider().padding(.top, 8)
                childList(scope)
            }
            .task(id: searchText) {
                try? await Task.sleep(for: .milliseconds(200))
                searchDebounced = searchText
                // If the current selection is no longer visible, drop it so
                // canvas and list never point at something off-screen.
                let visible = Set(model.scope(filter: searchDebounced).listNodes.map(\.id))
                if let sel = model.selectionID, !visible.contains(sel) { model.selectionID = nil }
            }
        }
    }

    private func applyCategory(_ nodes: [SpaceLensNode]) -> [SpaceLensNode] {
        guard let categoryFilter else { return nodes }
        // Drop "Other" while a category filter is active — its aggregate bytes
        // are computed before category filtering and would misrepresent the
        // filtered view.
        return nodes.filter { !$0.isOther && $0.category == categoryFilter }
    }

    private var searchAndFilterRow: some View {
        HStack {
            MCSearchField(text: $searchText, placeholder: L("spacelens.search_placeholder"))
            Picker(L("spacelens.filter_category"), selection: $categoryFilter) {
                Text(L("spacelens.filter_all")).tag(SpaceNodeCategory?.none)
                ForEach([SpaceNodeCategory.folder, .media, .document, .archive, .code, .other], id: \.self) { category in
                    Text(category.label).tag(SpaceNodeCategory?.some(category))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
            Spacer()
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 4) {
            if let root = model.root {
                if !model.pathStack.isEmpty {
                    Button {
                        navigate { model.pop(to: model.pathStack.count >= 2 ? model.pathStack.count - 2 : nil) }
                    } label: {
                        Label(L("spacelens.back"), systemImage: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("[", modifiers: .command)
                    .help(L("spacelens.back"))
                    .accessibilityLabel(L("spacelens.back"))
                    .accessibilityIdentifier("spacelens.up")
                    .padding(.trailing, 2)
                }
                Button(root.name) { navigate { model.pop(to: nil) } }
                    .buttonStyle(.link)
                ForEach(Array(model.pathStack.enumerated()), id: \.element.id) { index, node in
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    Button(node.name) { navigate { model.pop(to: index) } }
                        .buttonStyle(.link)
                }
                Spacer()
                Text(mcFormatBytes(model.current?.size ?? 0))
                    .font(MCFont.cardTitle).monospacedDigit()
                Button(L("spacelens.new_scan")) { model.phase = .idle }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .accessibilityIdentifier("spacelens.breadcrumb")
    }

    /// descend/pop wrapped so a real state change animates; clears the shared
    /// selection so the new scope starts unselected.
    private func navigate(_ action: () -> Void) {
        model.selectionID = nil
        withAnimation(MCMotion.animation(MCMotion.settle, reduce: reduceMotion)) {
            action()
        }
    }

    // MARK: Canvas

    private func bubbleCanvas(_ scope: SpaceLensScope) -> some View {
        let nodes = applyCategory(scope.visualNodes)
        return GeometryReader { proxy in
            let bubbles = RadialPack.pack(nodes, in: proxy.size, limit: visualLimit)
            ZStack {
                ForEach(1...3, id: \.self) { ring in
                    Circle()
                        .stroke(MCColor.separator.opacity(0.18), lineWidth: 1)
                        .frame(width: min(proxy.size.width, proxy.size.height) * CGFloat(ring) * 0.32)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                ForEach(bubbles) { bubble($0) }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .matchedGeometryEffect(id: scope.directoryID, in: zoomSpace, isSource: false)
        }
        .frame(minHeight: 340, maxHeight: 460)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("spacelens.canvas_a11y_summary", nodes.count))
    }

    private func bubbleA11y(_ node: SpaceLensNode) -> String {
        L("spacelens.bubble_a11y",
          node.displayName,
          mcFormatBytes(node.logicalBytes),
          Int((node.percentageOfScope * 100).rounded()),
          node.isDirectory ? L("spacelens.kind.directory") : L("spacelens.kind.file"))
    }

    @ViewBuilder
    private func bubble(_ b: RadialPack.Bubble) -> some View {
        let isSelected = model.selectionID == b.node.id
        let isHovered = hoveredID == b.node.id
        let showLabel = b.radius >= 30

        ZStack {
            Circle().fill(b.node.category.color.opacity(b.node.isDirectory ? 0.85 : 0.55))
            Circle().fill(
                RadialGradient(colors: [.white.opacity(0.20), .clear],
                               center: UnitPoint(x: 0.34, y: 0.30),
                               startRadius: 0, endRadius: b.radius))
            if b.node.isAccessDenied {
                Canvas { context, size in
                    var path = Path()
                    var x = -size.height
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x + size.height, y: 0))
                        x += 6
                    }
                    context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 1)
                }
                .clipShape(Circle())
            } else if b.node.isCloudPlaceholder {
                Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(.white.opacity(0.7))
            }
            if showLabel {
                VStack(spacing: 1) {
                    Text(b.node.displayName).font(.caption2.weight(.semibold)).lineLimit(1)
                    Text(mcFormatBytes(b.node.logicalBytes)).font(.system(size: 9)).opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .frame(maxWidth: b.radius * 1.7)
            }
        }
        // Selection reads through stroke + halo only — never a scale change,
        // so layout is identical selected or not (Reduce Motion safe).
        .overlay(Circle().strokeBorder(Color.white,
                                       lineWidth: isSelected ? 3 : (isHovered ? 1.5 : 0)))
        .shadow(color: .white.opacity(isSelected ? 0.55 : 0), radius: isSelected ? 6 : 0)
        .frame(width: b.radius * 2, height: b.radius * 2)
        // A mild hover cue only, and only when motion is allowed.
        .scaleEffect(isHovered && !reduceMotion ? 1.03 : 1)
        .position(b.center)
        .matchedGeometryEffect(id: b.node.id, in: zoomSpace, isSource: true)
        .contentShape(Circle())
        .onTapGesture(count: 2) {
            if !b.node.isOther { model.drill(nodeID: b.node.id) }
        }
        .onTapGesture(count: 1) {
            model.selectionID = b.node.id
        }
        .onHover { hovering in
            if reduceMotion {
                hoveredID = hovering ? b.node.id : nil
            } else {
                withAnimation(MCMotion.animation(MCMotion.settle, reduce: reduceMotion)) {
                    hoveredID = hovering ? b.node.id : nil
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(bubbleA11y(b.node))
        .accessibilityAddTraits(b.node.isDrillable ? .isButton : [])
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(b.node.isDrillable ? L("spacelens.drill_hint") : "")
        .help(L("spacelens.fragment.help", b.node.sourcePath.isEmpty ? b.node.displayName : b.node.sourcePath,
                mcFormatBytes(b.node.logicalBytes))
              + (b.node.isAccessDenied ? " — \(L("spacelens.access_denied_suffix"))" : "")
              + (b.node.isCloudPlaceholder ? " — \(L("spacelens.cloud_placeholder_suffix"))" : ""))
    }

    // MARK: List (the precise, VoiceOver-primary view)

    private func childList(_ scope: SpaceLensScope) -> some View {
        let rows = applyCategory(scope.listNodes)
        return List(rows, selection: Binding(
            get: { model.selectionID },
            set: { model.selectionID = $0 })
        ) { node in
            row(node)
        }
        .listStyle(.inset)
        .quickLookPreview($previewURL)
        .focusable()
        .onKeyPress(.return) {
            if let id = model.selectionID {
                withAnimation(MCMotion.animation(MCMotion.settle, reduce: reduceMotion)) {
                    model.drill(nodeID: id)
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.rightArrow) {
            if let id = model.selectionID { model.drill(nodeID: id); return .handled }
            return .ignored
        }
        .onKeyPress(.escape) {
            navigate { model.pop(to: model.pathStack.count >= 2 ? model.pathStack.count - 2 : nil) }
            return .handled
        }
    }

    @ViewBuilder
    private func row(_ node: SpaceLensNode) -> some View {
        HStack {
            Image(systemName: node.isOther ? "ellipsis.circle"
                  : (node.isDirectory ? "folder" : "doc"))
                .foregroundStyle(node.category.color)
            Text(node.displayName)
            if node.isAccessDenied {
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                    .accessibilityLabel(L("spacelens.access_denied_suffix"))
            }
            if node.isCloudPlaceholder {
                Image(systemName: "icloud.fill").font(.caption2).foregroundStyle(.secondary)
                    .accessibilityLabel(L("spacelens.cloud_placeholder_suffix"))
            }
            Spacer()
            Text("\(Int((node.percentageOfScope * 100).rounded()))%")
                .font(MCFont.badge).foregroundStyle(.tertiary).monospacedDigit()
            Text(mcFormatBytes(node.logicalBytes)).monospacedDigit().foregroundStyle(.secondary)
            if node.isDrillable {
                Button { model.drill(nodeID: node.id) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }
            if !node.isOther {
                if !node.isDirectory {
                    Button { previewURL = URL(fileURLWithPath: node.sourcePath) } label: {
                        Image(systemName: "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(L("clutter.quick_look"))
                    .accessibilityLabel(L("clutter.quick_look"))
                }
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.sourcePath)])
                } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(.borderless)
                .help(L("common.reveal_in_finder"))
                Button(role: .destructive) {
                    if let real = model.current?.children.first(where: { $0.path == node.sourcePath }) {
                        model.requestDelete(real)
                    }
                } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help(L("spacelens.delete.help"))
                ExcludeButton(url: URL(fileURLWithPath: node.sourcePath), controller: exclusionsController)
            }
        }
        .contentShape(Rectangle())
        // Additive so it never steals the List's own single-click selection
        // or the row's borderless action buttons.
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if node.isDrillable {
                withAnimation(MCMotion.animation(MCMotion.settle, reduce: reduceMotion)) {
                    model.drill(nodeID: node.id)
                }
            }
        })
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bubbleA11y(node)
                            + (node.isAccessDenied ? ", \(L("spacelens.access_denied_short"))" : "")
                            + (node.isCloudPlaceholder ? ", \(L("spacelens.cloud_placeholder_short"))" : ""))
        .accessibilityHint(node.isDrillable ? L("spacelens.drill_hint") : "")
    }
}
