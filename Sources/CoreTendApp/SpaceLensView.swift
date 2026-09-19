// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import ScanCore
import SafetyCore
import DesignSystem
import Persistence
import QuickLookUI
import QuickLook

@MainActor
@Observable
final class SpaceLensViewModel: CancellableScan {
    enum Phase: Equatable { case idle, scanning(items: Int), ready }

    var phase: Phase = .idle
    var root: SpaceNode?
    var pathStack: [SpaceNode] = []     // navigation into subdirectories
    /// Set only while a delete confirmation sheet is up; nil the rest of the time.
    var pendingDelete: SpaceNode?
    var lastDeleteError: String?
    var isScanPaused = false
    var scanTask: Task<Void, Never>?
    var pauseController: ScanPauseController?
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
                    phase = .ready; CaptureHarness.note(state: "ready")
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Space Lens: \(node.name) — \(mcFormatBytes(node.size))",
                        itemCount: node.children.count, bytes: node.size))
                    AppEnvironment.shared.recordLocationVisit(path: url.path, bytes: node.size)
                case .cancelled:
                    // Normally unreachable — see CancellableScan.
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
                switch event {
                case let .progress(items, _):
                    // Was unhandled: the rescan showed a frozen "0 items"
                    // counter for its whole duration.
                    phase = .scanning(items: items)
                case let .finished(node):
                    root = node
                    var stack: [SpaceNode] = []
                    var cursor = node
                    for path in pathsToRestore.prefix(depth) {
                        guard let match = cursor.children.first(where: { $0.path == path }) else { break }
                        stack.append(match)
                        cursor = match
                    }
                    pathStack = stack
                    phase = .ready; CaptureHarness.note(state: "ready")
                case .cancelled:
                    // Was unhandled: a cancelled rescan left the view spinning
                    // on .scanning permanently, with no way back.
                    phase = root == nil ? .idle : .ready
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
        cancelScanning()
    }

    func resetPhaseAfterCancellation() {
        if case .scanning = phase { phase = root == nil ? .idle : .ready }
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
            // Carry the refusal's reason. `lastDeleteError = node.name` was
            // assigned identically here and at execution-time skip, so the
            // alert could say only *that* a delete failed — never why, and
            // never which of two very different causes it was.
            let op: ApprovedFileOperation
            do throws(SafetyError) {
                op = try await center.approve(
                    url: URL(fileURLWithPath: node.path), logicalSize: node.size,
                    ruleID: "spacelens.delete", risk: .medium)
            } catch {
                lastDeleteError = "\(node.name) — \(ExecutionOutcome.explain(error))"
                return
            }
            let outcome = ExecutionOutcome(result: await center.execute([op]))
            AppEnvironment.shared.record(ActivityRecord(
                kind: .cleanup,
                summary: outcome.annotate(
                    "Space Lens: moved \(node.name) to Trash (\(mcFormatBytes(outcome.movedToTrashBytes)))"),
                itemCount: outcome.executedCount, bytes: outcome.movedToTrashBytes))
            if outcome.executedCount > 0 {
                rescanPreservingDepth()
            } else {
                // One operation in, so a skip means nothing happened at all.
                // Previously this branch was silent: the folder stayed, the
                // view did not refresh, and no alert appeared — the click
                // looked like it had simply been ignored. Re-validation
                // refusing a path that changed is the product working, and it
                // has to say so.
                // ...and say *which* refusal it was: the two reachable
                // causes (refused before acting, refused at the moment
                // of acting) mean different things to the user.
                lastDeleteError = "\(node.name) — \(L("spacelens.delete.changed"))"
            }
        }
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

struct SpaceMapView: View {
    /// Full Disk Access, re-checked on appear. Without it this module reads a
    /// fraction of what is there and reports it as a result.
    @State private var hasFullDiskAccess = SystemAuthorization.probeLive().hasFullDiskAccess
    @State private var scanAnyway = false
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
            case .idle where !hasFullDiskAccess && !scanAnyway:
                MCPermissionState(
                    title: L("permission.fulldisk.title"),
                    explanation: L("permission.fulldisk.explanation"),
                    limitation: L("permission.fulldisk.limitation"),
                    onContinue: { scanAnyway = true })
            case .idle: idleView
            case let .scanning(items): scanningView(items)
            case .ready: readyView
            }
        }
        .onAppear {
            hasFullDiskAccess = SystemAuthorization.probeLive().hasFullDiskAccess
            if CaptureHarness.autostartScan, case .idle = model.phase {
                scanAnyway = true
                model.start(url: CaptureHarness.scanHome)
            }
        }
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
                        .foregroundStyle(MCColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .mcAppear()

                MCScanButton(L("spacelens.scan_home"), systemImage: "circle.hexagongrid") {
                    model.start(url: CaptureHarness.scanHome)
                }
                .accessibilityIdentifier("spacelens.scan.home")
                .mcAppear(delay: 0.06)

                Button(L("spacelens.choose_folder")) {
                    if let url = FolderPicker.chooseFolderOrNil() {
                        model.start(url: url)
                    }
                }
                .buttonStyle(.link)

                VStack(alignment: .leading, spacing: MCSpacing.sm) {
                    VStack(alignment: .leading, spacing: MCSpacing.sm) {
                        MCSectionHeader(L("spacelens.filter_category"))
                        MCFeatureRow(L("spacelens.category.folder"),
                                     icon: "folder.fill")
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
            MCScanControls(
                identifierPrefix: "spacelens",
                isPaused: model.isScanPaused,
                pauseHintKey: "cleanup.pause_hint",
                resumeHintKey: "cleanup.resume_hint",
                onPause: { model.pauseScan() },
                onResume: { model.resumeScan() },
                onCancel: { model.cancel() })
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
                if !model.pathStack.isEmpty {
                    Button {
                        navigate { model.pop(to: model.pathStack.count >= 2 ? model.pathStack.count - 2 : nil) }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("[", modifiers: .command)
                    .help(L("spacelens.up"))
                    .accessibilityLabel(L("spacelens.up"))
                    .accessibilityIdentifier("spacelens.up")
                    .padding(.trailing, 2)
                }
                Button(root.name) { navigate { model.pop(to: nil) } }
                    .buttonStyle(.link)
                ForEach(Array(model.pathStack.enumerated()), id: \.element.id) { index, node in
                    Image(systemName: "chevron.right").font(MCFont.micro).foregroundStyle(MCColor.textTertiary)
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
    /// The map: a squarified treemap of the current folder's children.
    ///
    /// Bubbles were decorative — one orb per folder in a ring, sized by
    /// radius, so a 10× difference in bytes read as a 3× difference in
    /// diameter and the eye could not compare anything. A treemap gives area
    /// to bytes directly and puts a name on every cell big enough to hold one.
    /// Click selects; double-click or Return descends; the list below is the
    /// same data for keyboard and VoiceOver users.
    private func bubbleMap(for node: SpaceNode) -> some View {
        GeometryReader { proxy in
            let rects = TreemapLayout.layout(nodes: filteredChildren(of: node),
                                             in: CGRect(origin: .zero, size: proxy.size).insetBy(dx: 1, dy: 1))
            ZStack {
                ForEach(rects) { cell(for: $0) }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(minHeight: 280, maxHeight: 460)
        .background(MCColor.secondaryBackground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("spacelens.treemap.a11y_summary",
                              node.children.count, mcFormatBytes(node.size))
                            + " " + L("spacelens.treemap.accessibility"))
    }

    @ViewBuilder
    private func cell(for r: TreemapLayout.Rect) -> some View {
        let category = SpaceNodeCategory.of(r.node)
        let isSelected = selectedID == r.node.id
        let isHovered = hoveredID == r.node.id
        let frame = r.frame.insetBy(dx: 1, dy: 1)
        let showLabel = frame.width >= 64 && frame.height >= 30
        ZStack(alignment: .topLeading) {
            Rectangle().fill(category.color.opacity(r.node.isDirectory ? 0.78 : 0.5))
            if isHovered || isSelected {
                Rectangle().fill(Color.white.opacity(isSelected ? 0.14 : 0.07))
            }
            if r.node.isAccessDenied {
                Rectangle().fill(Color.black.opacity(MCOpacity.unavailableOverlay))
            }
            if showLabel {
                VStack(alignment: .leading, spacing: 0) {
                    Text(r.node.name).font(MCFont.captionEmphasis).lineLimit(1)
                    Text(mcFormatBytes(r.node.size)).font(MCFont.micro).opacity(MCOpacity.onFillSecondary)
                }
                .foregroundStyle(.white)
                .padding(5)
            }
        }
        .overlay(Rectangle().strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0))
        .frame(width: max(0, frame.width), height: max(0, frame.height))
        // position, not offset: offset moves from wherever the stack chose to
        // put the child, and the first capture showed every cell shifted by
        // the width of a label. A position is absolute in the map.
        .position(x: frame.midX, y: frame.midY)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { navigate { model.descend(into: r.node) } }
        .onTapGesture { selectedID = r.node.id }
        .onHover { hovering in hoveredID = hovering ? r.node.id : nil }
        .help(L("spacelens.fragment.help", r.node.path, mcFormatBytes(r.node.size))
              + (r.node.isAccessDenied ? " — \(L("spacelens.access_denied_suffix"))" : "")
              + (r.node.isCloudPlaceholder ? " — \(L("spacelens.cloud_placeholder_suffix"))" : ""))
        .contextMenu {
            if r.node.isDirectory {
                Button(L("spacelens.open_folder")) { navigate { model.descend(into: r.node) } }
            }
            Button(L("common.reveal_in_finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: r.node.path)])
            }
        }
    }

    private func childList(for node: SpaceNode) -> some View {
        List(filteredChildren(of: node), selection: $selectedID) { child in
            HStack {
                Image(systemName: child.isDirectory ? "folder" : "doc")
                    .foregroundStyle(SpaceNodeCategory.of(child).color)
                Text(child.name)
                if child.isAccessDenied {
                    Image(systemName: "lock.fill").font(MCFont.micro).foregroundStyle(MCColor.textSecondary)
                        .accessibilityLabel(L("spacelens.access_denied_suffix"))
                }
                if child.isCloudPlaceholder {
                    Image(systemName: "icloud.fill").font(MCFont.micro).foregroundStyle(MCColor.textSecondary)
                        .accessibilityLabel(L("spacelens.cloud_placeholder_suffix"))
                }
                Spacer()
                Text(mcFormatBytes(child.size)).monospacedDigit().foregroundStyle(MCColor.textSecondary)
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
                    } label: { Image(systemName: "folder") }
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


/// Explore: one place to look at the disk, four ways.
///
/// The map, the largest and oldest files, visually similar images and the
/// local footprint of cloud folders were three sidebar destinations and one
/// module. They are all the same question — where is the space going — asked
/// with different instruments, so they are tabs of one screen.
struct SpaceLensView: View {
    @State private var tab = 0

    var body: some View {
        ModuleSubNav(sections: [
            .init(0, L("explore.tab.map")),
            .init(1, L("explore.tab.large_old")),
            .init(2, L("explore.tab.similar")),
            .init(3, L("explore.tab.cloud")),
        ], selection: $tab) { tab in
            switch tab {
            case 1: LargeOldFilesView()
            case 2: SimilarImagesView()
            case 3: CloudCleanupView()
            default: SpaceMapView()
            }
        }
        .navigationTitle(L("module.explore"))
    }
}
