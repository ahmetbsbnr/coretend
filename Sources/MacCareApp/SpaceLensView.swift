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

struct SpaceLensView: View {
    @State private var model = SpaceLensViewModel()

    private static let palette: [Color] = [
        MCTheme.accent, MCTheme.accentSecondary, Color(red: 0.75, green: 0.45, blue: 0.75),
        MCTheme.warning, Color(red: 0.35, green: 0.65, blue: 0.85), Color(red: 0.55, green: 0.72, blue: 0.35),
    ]

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .idle: idleView
            case let .scanning(items): scanningView(items)
            case .ready: readyView
            }
        }
        .navigationTitle("Space Lens")
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 56)).foregroundStyle(MCTheme.accent)
            Text("Visualize your storage").font(.title2.weight(.semibold))
            Text("Builds an interactive size map. Analysis only — nothing is modified.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Scan Home Folder") {
                    model.start(url: FileManager.default.homeDirectoryForCurrentUser)
                }
                .buttonStyle(.borderedProminent)
                Button("Choose Folder…") {
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
            Text("Measured \(items) items…").monospacedDigit()
            Button("Cancel") { model.cancel() }
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
                Button(root.name) { model.pop(to: nil) }
                    .buttonStyle(.link)
                ForEach(Array(model.pathStack.enumerated()), id: \.element.id) { index, node in
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    Button(node.name) { model.pop(to: index) }
                        .buttonStyle(.link)
                }
                Spacer()
                Text(mcFormatBytes(model.current?.size ?? 0))
                    .font(.headline).monospacedDigit()
                Button("New Scan") { model.phase = .idle }
            }
        }
    }

    private func treemap(for node: SpaceNode) -> some View {
        GeometryReader { proxy in
            let rects = TreemapLayout.layout(
                nodes: node.children,
                in: CGRect(origin: .zero, size: proxy.size))
            ZStack(alignment: .topLeading) {
                ForEach(Array(rects.enumerated()), id: \.element.id) { index, rect in
                    let color = Self.palette[index % Self.palette.count]
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(rect.node.isDirectory ? 0.75 : 0.45))
                        .overlay(alignment: .topLeading) {
                            if rect.frame.width > 60 && rect.frame.height > 24 {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(rect.node.name).font(.caption2.weight(.medium)).lineLimit(1)
                                    Text(mcFormatBytes(rect.node.size)).font(.caption2).opacity(0.8)
                                }
                                .padding(4)
                                .foregroundStyle(.white)
                            }
                        }
                        .frame(width: max(rect.frame.width - 2, 1), height: max(rect.frame.height - 2, 1))
                        .offset(x: rect.frame.minX + 1, y: rect.frame.minY + 1)
                        .onTapGesture { model.descend(into: rect.node) }
                        .help("\(rect.node.path) — \(mcFormatBytes(rect.node.size))")
                }
            }
        }
        .frame(minHeight: 260, maxHeight: 380)
        .accessibilityLabel("Storage treemap. Use the list below for keyboard navigation.")
    }

    private func childList(for node: SpaceNode) -> some View {
        List(node.children) { child in
            HStack {
                Image(systemName: child.isDirectory ? "folder" : "doc")
                    .foregroundStyle(child.isDirectory ? MCTheme.accent : .secondary)
                Text(child.name)
                Spacer()
                Text(mcFormatBytes(child.size)).monospacedDigit().foregroundStyle(.secondary)
                if child.isDirectory && !child.children.isEmpty {
                    Button { model.descend(into: child) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                }
                if !child.path.hasSuffix("\u{2026}other") {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: child.path)])
                    } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
                    .help("Reveal in Finder")
                }
            }
        }
        .listStyle(.inset)
    }
}
