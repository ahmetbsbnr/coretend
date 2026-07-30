import SwiftUI
import ScanCore
import DesignSystem
import Persistence
import QuickLookUI
import QuickLook
@preconcurrency import QuickLookThumbnailing

@MainActor
@Observable
final class SimilarImagesViewModel {
    enum Phase: Equatable { case idle, scanning(processed: Int, total: Int), results, empty }

    var phase: Phase = .idle
    var previewURL: URL?
    var groups: [SimilarImageGroup] = []
    var searchText = ""
    var selectedVolumeID: String?
    let volumeResolver: VolumeResolving
    let exclusionsController = ClutterExclusionsController()
    private var scanTask: Task<Void, Never>?

    init(volumeResolver: VolumeResolving = SystemVolumeResolver()) {
        self.volumeResolver = volumeResolver
    }

    var availableVolumes: [VolumeInfo] {
        ClutterVolumeGrouping.availableVolumes(for: groups.flatMap(\.urls), resolver: volumeResolver)
    }

    /// Same any-member-matches semantics as Duplicates: a cluster of similar
    /// photos commonly spans an internal volume and an external/backup one.
    var filteredGroups: [SimilarImageGroup] {
        groups.filter { group in
            group.urls.contains {
                ClutterSearch.matches(fileName: $0.lastPathComponent, path: $0.path, query: searchText)
            } && group.urls.contains {
                ClutterVolumeGrouping.matches($0, volumeID: selectedVolumeID, resolver: volumeResolver)
            }
        }
    }

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
                MCEmptyState(
                    icon: "photo.on.rectangle.angled", title: L("similar.idle.title"), message: L("similar.idle.subtitle"),
                    iconColor: MCTheme.accent, iconSize: MCIconSize.emptyStateProminent,
                    actionTitle: L("similar.analyze")) { model.start() }
            case let .scanning(processed, total):
                VStack(spacing: 16) {
                    if total > 0 {
                        ProgressView(value: Double(processed), total: Double(total))
                            .frame(width: 260)
                        Text(L("similar.analyzing", processed, total)).monospacedDigit()
                    } else {
                        ProgressView()
                        Text(L("similar.collecting"))
                    }
                    Button(L("common.cancel")) { model.cancel() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: MCIconSize.emptyState)).foregroundStyle(MCTheme.success)
                    Text(L("similar.none_found")).font(.title3.weight(.semibold))
                    Button(L("similar.analyze_again")) { model.start() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results:
                HStack {
                    MCSearchField(text: $model.searchText, placeholder: L("clutter.search_placeholder"))
                    if model.availableVolumes.count > 1 {
                        Picker(L("clutter.volume"), selection: $model.selectedVolumeID) {
                            Text(L("clutter.all_volumes")).tag(String?.none)
                            ForEach(model.availableVolumes) { volume in
                                Text(volume.id == VolumeInfo.unavailable.id ? L("clutter.volume_unavailable") : volume.name)
                                    .tag(String?.some(volume.id))
                            }
                        }
                        .frame(width: 180)
                    }
                    Spacer()
                    ExclusionsMenu(controller: model.exclusionsController)
                }
                .padding(.horizontal).padding(.top, MCSpacing.xs)
                List {
                    ForEach(model.filteredGroups) { group in
                        let members = group.urls.map { ImageMember(id: $0.path, url: $0) }
                        let best = group.bestResolutionURL
                        Section(L("similar.group_header", group.urls.count, mcFormatBytes(group.totalBytes))) {
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
                                        Text(L("similar.best_resolution"))
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, MCSpacing.xxs).padding(.vertical, 1)
                                            .background(MCColor.coreMint.opacity(0.18), in: Capsule())
                                            .foregroundStyle(MCColor.coreMint)
                                    }
                                    Spacer()
                                    Button {
                                        model.previewURL = url
                                    } label: { Image(systemName: "eye") }
                                    .buttonStyle(.borderless)
                                    .help(L("clutter.quick_look"))
                                    .accessibilityLabel(L("clutter.quick_look"))
                                    Button {
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    } label: { Image(systemName: "magnifyingglass") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("\(L("similar.reveal_a11y", url.lastPathComponent))\(url == best ? ", \(L("similar.best_resolution_a11y"))" : "")")
                                    ExcludeButton(url: url, controller: model.exclusionsController)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .quickLookPreview($model.previewURL)
            }
        }
    }
}
