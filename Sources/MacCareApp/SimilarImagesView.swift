import SwiftUI
import ScanCore
import DesignSystem
import Persistence
import QuickLookThumbnailing

@MainActor
@Observable
final class SimilarImagesViewModel {
    enum Phase: Equatable { case idle, scanning(processed: Int, total: Int), results, empty }

    var phase: Phase = .idle
    var groups: [SimilarImageGroup] = []
    private var scanTask: Task<Void, Never>?

    func start() {
        if case .scanning = phase { return }
        phase = .scanning(processed: 0, total: 0)
        groups = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let engine = SimilarImagesEngine(roots: [
            home.appendingPathComponent("Pictures"),
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Desktop"),
        ])
        scanTask = Task {
            for await event in engine.run() {
                switch event {
                case let .progress(processed, total):
                    phase = .scanning(processed: processed, total: total)
                case let .finished(found):
                    groups = found
                    phase = found.isEmpty ? .empty : .results
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Similar images: \(found.count) groups",
                        itemCount: found.count,
                        bytes: found.reduce(0) { $0 + $1.totalBytes }, dryRun: true))
                case .cancelled:
                    phase = groups.isEmpty ? .idle : .results
                case let .unavailable(reason):
                    phase = .empty
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .error, summary: "Similar images unavailable: \(reason)",
                        itemCount: 0, bytes: 0, dryRun: true))
                }
            }
        }
    }

    func cancel() { scanTask?.cancel() }
}

/// Identifiable wrapper so raw `URL`s can drive `MCOverlapStack`.
private struct ImageMember: Identifiable {
    let id: String   // path
    let url: URL
}

/// Loads a small thumbnail on demand; never keeps full images in memory.
struct AsyncThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.quaternary)
                    .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task {
            let request = QLThumbnailGenerator.Request(
                fileAt: url, size: CGSize(width: 144, height: 144),
                scale: 2, representationTypes: .thumbnail)
            if let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                image = representation.nsImage
            }
        }
    }
}

struct SimilarImagesView: View {
    @State private var model = SimilarImagesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .idle:
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 56)).foregroundStyle(MCTheme.accent)
                    Text("Find visually similar images").font(.title2.weight(.semibold))
                    Text("Uses on-device Vision analysis of Pictures, Downloads and Desktop.\nPhotos libraries are never touched. Review in Finder; nothing is deleted here.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Analyze Images") { model.start() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .scanning(processed, total):
                VStack(spacing: 16) {
                    if total > 0 {
                        ProgressView(value: Double(processed), total: Double(total))
                            .frame(width: 260)
                        Text("Analyzing \(processed) of \(total) images").monospacedDigit()
                    } else {
                        ProgressView()
                        Text("Collecting images…")
                    }
                    Button("Cancel") { model.cancel() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48)).foregroundStyle(MCTheme.success)
                    Text("No similar image groups found").font(.title3.weight(.semibold))
                    Button("Analyze Again") { model.start() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results:
                List {
                    ForEach(model.groups) { group in
                        let members = group.urls.map { ImageMember(id: $0.path, url: $0) }
                        let best = group.bestResolutionURL
                        Section("\(group.urls.count) similar — \(mcFormatBytes(group.totalBytes))") {
                            // Overlap motif: near-duplicates shown slightly
                            // overlapping, separating on hover. Decorative —
                            // the rows below carry the real accessible detail.
                            MCOverlapStack(items: members, markedID: best?.path) { member in
                                AsyncThumbnail(url: member.url)
                                    .onTapGesture {
                                        NSWorkspace.shared.activateFileViewerSelecting([member.url])
                                    }
                            }
                            .padding(.vertical, MCSpacing.xs)
                            ForEach(group.urls, id: \.path) { url in
                                HStack {
                                    Text(url.lastPathComponent).lineLimit(1)
                                    if url == best {
                                        Text("Best resolution")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, MCSpacing.xxs).padding(.vertical, 1)
                                            .background(MCColor.coreMint.opacity(0.18), in: Capsule())
                                            .foregroundStyle(MCColor.coreMint)
                                    }
                                    Spacer()
                                    Button {
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    } label: { Image(systemName: "magnifyingglass") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Reveal \(url.lastPathComponent) in Finder\(url == best ? ", best resolution" : "")")
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
