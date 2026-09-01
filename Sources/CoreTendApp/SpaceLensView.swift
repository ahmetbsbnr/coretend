import SwiftUI
import ScanCore
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
    private var scanTask: Task<Void, Never>?
    private var pauseController: ScanPauseController?
    private var rootURL: URL?

    var current: SpaceNode? { pathStack.last ?? root }

    func start(url: URL) {
        scanTask?.cancel()
        phase = .scanning(items: 0)
        root = nil
        pathStack = []
        rootURL = url
        isScanPaused = false
        let pauseController = ScanPauseController()
        self.pauseController = pauseController
        let engine = SpaceLensEngine(root: url)
        scanTask = Task {
            for await event in engine.run(pauseController: pauseController) {
                switch event {
                case let .progress(items, _):
                    phase = .scanning(items: items)
                case let .finished(node):
                    root = node
                    phase = .ready
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Space Lens: \(node.name) — \(mcFormatBytes(node.size))",
                        itemCount: node.children.count, bytes: node.size))
                    AppEnvironment.shared.recordLocationVisit(path: url.path, bytes: node.size)
                case .cancelled:
                    isScanPaused = false
                    phase = root == nil ? .idle : .ready
                }
            }
        }
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
        let node: SpaceNode
        let center: CGPoint
        let radius: CGFloat
    }

    static func pack(_ nodes: [SpaceNode], in size: CGSize, limit: Int = 13) -> [Bubble] {
        guard size.width > 8, size.height > 8, !nodes.isEmpty else { return [] }
        let items = Array(nodes.prefix(limit))
        let maxByte = Double(max(items.first?.size ?? 1, 1))
        let shortSide = min(size.width, size.height)
        let maxR = shortSide * 0.27
        let minR: CGFloat = 12
        let gap: CGFloat = 6
        let mid = CGPoint(x: size.width / 2, y: size.height / 2)

        func radius(for node: SpaceNode) -> CGFloat {
            let frac = (Double(max(node.size, 1)) / maxByte).squareRoot()   // area ∝ bytes
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
    @State private var selectedID: String?
    @State private var hoveredID: String?
    @State private var previewURL: URL?
    @State private var searchText = ""
    @State private var categoryFilter: SpaceNodeCategory?
    @State private var exclusionsController = ClutterExclusionsController()
    @State private var showFavoritesRecents = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                model.start(url: url)
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

    private func scanningView(_ items: Int) -> some View {
        VStack(spacing: MCSpacing.lg) {
            MCScanStage(isScanning: !model.isScanPaused) {
                Text(L("spacelens.scanning_progress", items)).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L("spacelens.scanning_progress", items))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var readyView: some View {
        if let current = model.current {
            VStack(alignment: .leading, spacing: 0) {
                breadcrumb
                    .padding(.horizontal).padding(.vertical, 8)
                searchAndFilterRow
                    .padding(.horizontal).padding(.bottom, 8)
                bubbleMap(for: current)
                    .padding(.horizontal)
                Divider().padding(.top, 8)
                childList(for: current)
            }
        }
    }

    /// Filters by name (locale-aware substring, same comparison My Clutter
    /// uses) and/or category — applied identically to the treemap and the
    /// accessible list below it, so the two never disagree about what's shown.
    private func filteredChildren(of node: SpaceNode) -> [SpaceNode] {
        node.children.filter { child in
            let matchesSearch = searchText.isEmpty || child.name.localizedStandardContains(searchText)
            let matchesCategory = categoryFilter == nil || SpaceNodeCategory.of(child) == categoryFilter
            return matchesSearch && matchesCategory
        }
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
    }

    /// Real navigation (descend/pop) wrapped so the matchedGeometryEffect
    /// zoom interpolates — no animation runs unless a real state change fires it.
    private func navigate(_ action: () -> Void) {
        selectedID = nil
        withAnimation(MCMotion.animation(MCMotion.settle, reduce: reduceMotion)) {
            action()
        }
    }

    /// Radial size map — the biggest child dead centre, siblings orbiting it,
    /// bubble area proportional to bytes. Faint concentric rings give the eye
    /// a fixed centre to read against.
    private func bubbleMap(for node: SpaceNode) -> some View {
        GeometryReader { proxy in
            let bubbles = RadialPack.pack(filteredChildren(of: node), in: proxy.size)
            ZStack {
                ForEach(1...3, id: \.self) { ring in
                    Circle()
                        .stroke(MCColor.separator.opacity(0.18), lineWidth: 1)
                        .frame(width: min(proxy.size.width, proxy.size.height) * CGFloat(ring) * 0.32)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                ForEach(bubbles) { bubble(for: $0) }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            // Anchors the map to the node just zoomed into, so descend/pop
            // reads as continuous rather than a hard cut.
            .matchedGeometryEffect(id: node.id, in: zoomSpace, isSource: false)
        }
        .frame(minHeight: 320, maxHeight: 440)
        // The map is a purely visual duplicate of the accessible child list
        // below; collapse it so VoiceOver reads a summary, not dozens of
        // unlabeled shapes.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("spacelens.treemap.a11y_summary",
                              node.children.count, mcFormatBytes(node.size))
                            + " " + L("spacelens.treemap.accessibility"))
    }

    @ViewBuilder
    private func bubble(for b: RadialPack.Bubble) -> some View {
        let category = SpaceNodeCategory.of(b.node)
        let isSelected = selectedID == b.node.id
        let isHovered = hoveredID == b.node.id
        let showLabel = b.radius >= 30

        ZStack {
            Circle().fill(category.color.opacity(b.node.isDirectory ? 0.85 : 0.55))
            // Top-left sheen for a little depth — transform/opacity only.
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
                    Text(b.node.name).font(.caption2.weight(.semibold)).lineLimit(1)
                    Text(mcFormatBytes(b.node.size)).font(.system(size: 9)).opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .frame(maxWidth: b.radius * 1.7)
            }
        }
        .overlay(Circle().strokeBorder(Color.white,
                                       lineWidth: isSelected ? 2.5 : (isHovered ? 1.5 : 0)))
        .frame(width: b.radius * 2, height: b.radius * 2)
        .scaleEffect(isHovered && !reduceMotion ? 1.04 : 1)
        .position(b.center)
        .matchedGeometryEffect(id: b.node.id, in: zoomSpace, isSource: true)
        .onTapGesture {
            selectedID = b.node.id
            navigate { model.descend(into: b.node) }
        }
        .onHover { hovering in
            withAnimation(MCMotion.animation(MCMotion.settle, reduce: reduceMotion)) {
                hoveredID = hovering ? b.node.id : nil
            }
        }
        .help(L("spacelens.fragment.help", b.node.path, mcFormatBytes(b.node.size))
              + (b.node.isAccessDenied ? " — \(L("spacelens.access_denied_suffix"))" : "")
              + (b.node.isCloudPlaceholder ? " — \(L("spacelens.cloud_placeholder_suffix"))" : ""))
    }

    private func childList(for node: SpaceNode) -> some View {
        List(filteredChildren(of: node), selection: $selectedID) { child in
            HStack {
                Image(systemName: child.isDirectory ? "folder" : "doc")
                    .foregroundStyle(SpaceNodeCategory.of(child).color)
                Text(child.name)
                if child.isAccessDenied {
                    Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                        .accessibilityLabel(L("spacelens.access_denied_suffix"))
                }
                if child.isCloudPlaceholder {
                    Image(systemName: "icloud.fill").font(.caption2).foregroundStyle(.secondary)
                        .accessibilityLabel(L("spacelens.cloud_placeholder_suffix"))
                }
                Spacer()
                Text(mcFormatBytes(child.size)).monospacedDigit().foregroundStyle(.secondary)
                if child.isDirectory && !child.children.isEmpty {
                    Button { navigate { model.descend(into: child) } } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
                if !child.path.hasSuffix("\u{2026}other") {
                    if !child.isDirectory {
                        Button {
                            previewURL = URL(fileURLWithPath: child.path)
                        } label: { Image(systemName: "eye") }
                        .buttonStyle(.borderless)
                        .help(L("clutter.quick_look"))
                        .accessibilityLabel(L("clutter.quick_look"))
                    }
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: child.path)])
                    } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
                    .help(L("common.reveal_in_finder"))
                    Button(role: .destructive) {
                        model.requestDelete(child)
                    } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help(L("spacelens.delete.help"))
                    ExcludeButton(url: URL(fileURLWithPath: child.path), controller: exclusionsController)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(child.name), \(mcFormatBytes(child.size))"
                                + (child.isAccessDenied ? ", \(L("spacelens.access_denied_short"))" : "")
                                + (child.isCloudPlaceholder ? ", \(L("spacelens.cloud_placeholder_short"))" : ""))
        }
        .listStyle(.inset)
        .quickLookPreview($previewURL)
        .focusable()
        .onKeyPress(.return) {
            if let id = selectedID, let child = filteredChildren(of: node).first(where: { $0.id == id }) {
                navigate { model.descend(into: child) }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            navigate { model.pop(to: model.pathStack.count >= 2 ? model.pathStack.count - 2 : nil) }
            return .handled
        }
    }
}
