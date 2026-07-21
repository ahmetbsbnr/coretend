import SwiftUI
import ScanCore
import DesignSystem
import Persistence

@MainActor
@Observable
final class SpaceLensViewModel {
    enum Phase: Equatable { case idle, scanning(items: Int), ready }

    var phase: Phase = .idle
    var root: SpaceNode?
    var pathStack: [SpaceNode] = []     // navigation into subdirectories
    private var scanTask: Task<Void, Never>?

    var current: SpaceNode? { pathStack.last ?? root }

    func start(url: URL) {
        scanTask?.cancel()
        phase = .scanning(items: 0)
        root = nil
        pathStack = []
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

    func cancel() { scanTask?.cancel() }

    func descend(into node: SpaceNode) {
        guard node.isDirectory, !node.children.isEmpty || node.size > 0 else { return }
        if !node.children.isEmpty { pathStack.append(node) }
    }

    func pop(to index: Int?) {
        if let index { pathStack = Array(pathStack.prefix(index + 1)) } else { pathStack = [] }
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
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: MCIconSize.emptyStateProminent)).foregroundStyle(MCTheme.accent)
            Text(L("spacelens.idle.title")).font(.title2.weight(.semibold))
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
                Text(mcFormatBytes(model.current?.size ?? 0))
                    .font(.headline).monospacedDigit()
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
        .accessibilityLabel(L("spacelens.treemap.accessibility"))
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
                                Image(systemName: "lock.fill").font(.system(size: 8))
                            } else if rect.node.isCloudPlaceholder {
                                Image(systemName: "icloud.fill").font(.system(size: 8))
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
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: child.path)])
                    } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
                    .help(L("common.reveal_in_finder"))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(child.name), \(mcFormatBytes(child.size))"
                                + (child.isAccessDenied ? ", \(L("spacelens.access_denied_short"))" : "")
                                + (child.isCloudPlaceholder ? ", \(L("spacelens.cloud_placeholder_short"))" : ""))
        }
        .listStyle(.inset)
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
