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
    var dryRun = true
    /// Set only while a delete confirmation sheet is up; nil the rest of the time.
    var pendingDelete: SpaceNode?
    var lastDeleteError: String?
    private var scanTask: Task<Void, Never>?
    private var rootURL: URL?
    private var dryRunDefaultLoaded = false

    var current: SpaceNode? { pathStack.last ?? root }

    /// Mirrors every other destructive module's own "dry-run by default"
    /// setting — without this, Space Lens's delete would silently ignore the
    /// user's app-wide safety preference.
    func loadDryRunDefault() async {
        guard !dryRunDefaultLoaded else { return }
        dryRunDefaultLoaded = true
        dryRun = AppEnvironment.dryRunEnabled(
            fromSetting: (try? await AppEnvironment.shared.store?.setting("dryRunDefault")) ?? nil)
    }

    func start(url: URL) {
        scanTask?.cancel()
        phase = .scanning(items: 0)
        root = nil
        pathStack = []
        rootURL = url
        let engine = SpaceLensEngine(root: url)
        scanTask = Task {
            for await event in engine.run() {
                switch event {
                case let .progress(items, _):
                    phase = .scanning(items: items)
                case let .finished(node):
                    root = node
                    phase = .ready
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Space Lens: \(node.name) — \(mcFormatBytes(node.size))",
                        itemCount: node.children.count, bytes: node.size, dryRun: true))
                case .cancelled:
                    phase = root == nil ? .idle : .ready
                }
            }
        }
    }

    /// Re-runs the scan from the same root, preserving the current navigation
    /// depth where possible, so a delete's effect on sizes/listing is real
    /// rather than a locally-patched guess. Only called after a real (non
    /// dry-run) delete, since a dry run changes nothing on disk to reflect.
    private func rescanPreservingDepth() {
        guard let rootURL else { return }
        let depth = pathStack.count
        let pathsToRestore = pathStack.map(\.path)
        scanTask?.cancel()
        phase = .scanning(items: 0)
        let engine = SpaceLensEngine(root: rootURL)
        scanTask = Task {
            for await event in engine.run() {
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

    func cancel() { scanTask?.cancel() }

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
        let isDryRun = dryRun
        Task {
            let validator = PathValidator(allowedRoots: [rootURL])
            let center = SafetyCenter(validator: validator, dryRun: isDryRun, sink: AppEnvironment.shared.store)
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
                summary: isDryRun
                    ? "Space Lens dry run: would free \(mcFormatBytes(freed)) (\(node.name))"
                    : "Space Lens: moved \(node.name) to Trash (\(mcFormatBytes(freed)))",
                itemCount: result.executed.count, bytes: freed, dryRun: result.wasDryRun))
            if !result.executed.isEmpty && !isDryRun {
                rescanPreservingDepth()
            }
        }
    }
}

/// Semantic color-by-type for treemap fragments — never arbitrary index cycling.
enum SpaceNodeCategory: String {
    case folder, media, document, archive, code, other

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
        case .media: return MCColor.novaMagenta
        case .document: return MCColor.glacierBlue
        case .archive: return MCTheme.warning
        case .code: return MCColor.mossGreen
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
        .task { await model.loadDryRunDefault() }
        .confirmationDialog(
            model.pendingDelete.map { L("spacelens.delete.confirm_title", $0.name) } ?? "",
            isPresented: Binding(get: { model.pendingDelete != nil }, set: { if !$0 { model.pendingDelete = nil } }),
            presenting: model.pendingDelete
        ) { node in
            Button(model.dryRun ? L("spacelens.delete.confirm_dryrun") : L("spacelens.delete.confirm_action"), role: .destructive) {
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
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: MCIconSize.emptyStateProminent)).foregroundStyle(MCTheme.accent)
            Text(L("spacelens.idle.title")).font(MCFont.pageTitle)
            Text(L("spacelens.idle.subtitle"))
                .foregroundStyle(.secondary)
            HStack {
                Button(L("spacelens.scan_home")) {
                    model.start(url: FileManager.default.homeDirectoryForCurrentUser)
                }
                .buttonStyle(.borderedProminent)
                Button(L("spacelens.choose_folder")) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK, let url = panel.url {
                        model.start(url: url)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scanningView(_ items: Int) -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(L("spacelens.scanning_progress", items)).monospacedDigit()
            Button(L("common.cancel")) { model.cancel() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var readyView: some View {
        if let current = model.current {
            VStack(alignment: .leading, spacing: 0) {
                breadcrumb
                    .padding(.horizontal).padding(.vertical, 8)
                treemap(for: current)
                    .padding(.horizontal)
                Divider().padding(.top, 8)
                childList(for: current)
            }
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
                Toggle(L("common.dry_run"), isOn: Binding(get: { model.dryRun }, set: { model.dryRun = $0 }))
                    .toggleStyle(.checkbox)
                    .help(L("spacelens.dryrun.help"))
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

    private func treemap(for node: SpaceNode) -> some View {
        GeometryReader { proxy in
            let rects = TreemapLayout.layout(
                nodes: node.children,
                in: CGRect(origin: .zero, size: proxy.size))
            ZStack(alignment: .topLeading) {
                ForEach(rects) { rect in
                    fragment(for: rect)
                }
            }
            // Anchors the whole map to the node that was just zoomed into,
            // so the transition reads as continuous rather than a hard cut.
            .matchedGeometryEffect(id: node.id, in: zoomSpace, isSource: false)
        }
        .frame(minHeight: 260, maxHeight: 380)
        // The treemap is a purely visual duplicate of the accessible child
        // list below; collapse its fragments into one element so VoiceOver
        // reads a summary, not dozens of unlabeled rectangles.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("spacelens.treemap.a11y_summary",
                              node.children.count, mcFormatBytes(node.size))
                            + " " + L("spacelens.treemap.accessibility"))
    }

    @ViewBuilder
    private func fragment(for rect: TreemapLayout.Rect) -> some View {
        let category = SpaceNodeCategory.of(rect.node)
        let isSelected = selectedID == rect.node.id
        let isHovered = hoveredID == rect.node.id
        RoundedRectangle(cornerRadius: 3)
            .fill(category.color.opacity(rect.node.isDirectory ? 0.75 : 0.45))
            .overlay {
                // Denied/cloud branches get a distinct pattern, never color-only.
                if rect.node.isAccessDenied {
                    Canvas { context, size in
                        var path = Path()
                        var x: CGFloat = -size.height
                        while x < size.width {
                            path.move(to: CGPoint(x: x, y: size.height))
                            path.addLine(to: CGPoint(x: x + size.height, y: 0))
                            x += 6
                        }
                        context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 1)
                    }
                } else if rect.node.isCloudPlaceholder {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .overlay(alignment: .topLeading) {
                if rect.frame.width > 60 && rect.frame.height > 24 {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 2) {
                            if rect.node.isAccessDenied {
                                Image(systemName: "lock.fill").font(.system(size: MCIconSize.inline))
                            } else if rect.node.isCloudPlaceholder {
                                Image(systemName: "icloud.fill").font(.system(size: MCIconSize.inline))
                            }
                            Text(rect.node.name).font(.caption2.weight(.medium)).lineLimit(1)
                        }
                        Text(mcFormatBytes(rect.node.size)).font(.caption2).opacity(0.8)
                    }
                    .padding(4)
                    .foregroundStyle(.white)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.white, lineWidth: isSelected ? 2 : (isHovered ? 1 : 0))
            )
            .frame(width: max(rect.frame.width - 2, 1), height: max(rect.frame.height - 2, 1))
            .offset(x: rect.frame.minX + 1, y: rect.frame.minY + 1)
            .matchedGeometryEffect(id: rect.node.id, in: zoomSpace, isSource: true)
            .onTapGesture {
                selectedID = rect.node.id
                navigate { model.descend(into: rect.node) }
            }
            .onHover { hovering in hoveredID = hovering ? rect.node.id : nil }
            .help(L("spacelens.fragment.help", rect.node.path, mcFormatBytes(rect.node.size))
                  + (rect.node.isAccessDenied ? " — \(L("spacelens.access_denied_suffix"))" : "")
                  + (rect.node.isCloudPlaceholder ? " — \(L("spacelens.cloud_placeholder_suffix"))" : ""))
    }

    private func childList(for node: SpaceNode) -> some View {
        List(node.children, selection: $selectedID) { child in
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
            if let id = selectedID, let child = node.children.first(where: { $0.id == id }) {
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
