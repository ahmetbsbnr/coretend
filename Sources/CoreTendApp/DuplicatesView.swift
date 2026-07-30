import SwiftUI
import ScanCore
import SafetyCore
import DesignSystem
import Persistence
import QuickLookUI
import QuickLook

/// Identifiable wrapper so raw `URL`s can drive `MCOverlapStack`.
private struct DupMember: Identifiable {
    let id: String   // path
    let url: URL
}

@MainActor
@Observable
final class DuplicatesViewModel {
    enum Phase: Equatable { case idle, scanning(processed: Int, total: Int), results, empty, executing, finished(freed: Int64, dryRun: Bool) }

    var phase: Phase = .idle
    var groups: [DuplicateGroup] = []
    var selectedPaths: Set<String> = []   // paths selected for removal
    var previewURL: URL?
    var dryRun = true
    var searchText = ""
    var selectedVolumeID: String?
    let volumeResolver: VolumeResolving
    let exclusionsController = ClutterExclusionsController()

    private var scanTask: Task<Void, Never>?
    private var scannedRoots: [URL] = []

    init(volumeResolver: VolumeResolving = SystemVolumeResolver()) {
        self.volumeResolver = volumeResolver
    }

    var wastedBytes: Int64 { groups.reduce(0) { $0 + $1.wastedBytes } }

    var availableVolumes: [VolumeInfo] {
        ClutterVolumeGrouping.availableVolumes(for: groups.flatMap(\.urls), resolver: volumeResolver)
    }

    /// A group matches if any of its copies matches the name search and any
    /// copy sits on the selected volume — duplicates commonly span volumes
    /// (e.g. one copy on the internal disk, one on a backup drive), so
    /// filtering per-copy rather than requiring the whole group to agree
    /// keeps a relevant group visible instead of hiding it entirely.
    var filteredGroups: [DuplicateGroup] {
        groups.filter { group in
            group.urls.contains {
                ClutterSearch.matches(fileName: $0.lastPathComponent, path: $0.path, query: searchText)
            } && group.urls.contains {
                ClutterVolumeGrouping.matches($0, volumeID: selectedVolumeID, resolver: volumeResolver)
            }
        }
    }
    var selectedBytes: Int64 {
        groups.reduce(0) { sum, group in
            sum + group.fileSize * Int64(group.urls.filter { selectedPaths.contains($0.path) }.count)
        }
    }

    func start() {
        if case .scanning = phase { return }
        phase = .scanning(processed: 0, total: 0)
        groups = []
        selectedPaths = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        scannedRoots = ["Downloads", "Documents", "Desktop"].map { home.appendingPathComponent($0) }
        let engine = DuplicateEngine(roots: scannedRoots)
        scanTask = Task {
            for await event in engine.run() {
                switch event {
                case let .progress(_, processed, total):
                    phase = .scanning(processed: processed, total: total)
                case let .group(group):
                    if groups.count < 1000 {
                        let index = groups.firstIndex { $0.wastedBytes < group.wastedBytes } ?? groups.count
                        groups.insert(group, at: index)
                        // Preselect everything except the suggested keeper.
                        for url in group.urls where url.path != group.keeper.path {
                            selectedPaths.insert(url.path)
                        }
                    }
                case let .finished(count, wasted):
                    phase = groups.isEmpty ? .empty : .results
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Duplicate scan: \(count) groups",
                        itemCount: count, bytes: wasted, dryRun: true))
                case .cancelled:
                    phase = groups.isEmpty ? .idle : .results
                }
            }
        }
    }

    func cancel() { scanTask?.cancel() }

    func removeSelected() {
        guard phase == .results, !selectedPaths.isEmpty else { return }
        // Drop any copy that changed on disk since the scan: it is no longer
        // known to be a duplicate, so trashing it could lose real data.
        for group in groups {
            for url in group.urls where group.hasChangedOnDisk(url) {
                selectedPaths.remove(url.path)
            }
        }
        // Never allow a whole group to be removed: at least one copy must survive.
        for group in groups where group.urls.allSatisfy({ selectedPaths.contains($0.path) }) {
            selectedPaths.remove(group.keeper.path)
        }
        guard !selectedPaths.isEmpty else { return }
        phase = .executing
        let toRemove = groups.flatMap { group in
            group.urls.filter { selectedPaths.contains($0.path) }.map { ($0, group.fileSize) }
        }
        let isDryRun = dryRun
        let roots = scannedRoots
        Task {
            let center = SafetyCenter(validator: PathValidator(allowedRoots: roots), dryRun: isDryRun, sink: AppEnvironment.shared.store)
            var approved: [ApprovedFileOperation] = []
            for (url, size) in toRemove {
                if let op = try? await center.approve(url: url, logicalSize: size,
                                                      ruleID: "clutter.duplicates", risk: .medium) {
                    approved.append(op)
                }
            }
            let result = await center.execute(approved)
            let freed = result.executed.reduce(0) { $0 + $1.logicalSize }
            phase = .finished(freed: freed, dryRun: result.wasDryRun)
            AppEnvironment.shared.record(ActivityRecord(
                kind: .cleanup,
                summary: result.wasDryRun
                    ? "Duplicates dry run: \(result.executed.count) copies"
                    : "Moved \(result.executed.count) duplicate copies to Trash",
                itemCount: result.executed.count, bytes: freed, dryRun: result.wasDryRun))
        }
    }
}

struct DuplicatesView: View {
    @State private var model = DuplicatesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .idle: idleView
            case let .scanning(processed, total): scanningView(processed, total)
            case .empty: emptyView
            case .results, .executing: resultsView
            case let .finished(freed, dryRun): finishedView(freed, dryRun)
            }
        }
    }

    private var idleView: some View {
        MCEmptyState(
            icon: "doc.on.doc.fill", title: L("dupes.idle.title"), message: L("dupes.idle.subtitle"),
            iconColor: MCTheme.accentSecondary, iconSize: MCIconSize.emptyStateProminent,
            actionTitle: L("dupes.find")) { model.start() }
    }

    private func scanningView(_ processed: Int, _ total: Int) -> some View {
        VStack(spacing: 16) {
            if total > 0 {
                ProgressView(value: Double(processed), total: Double(total))
                    .frame(width: 260)
                Text(L("dupes.comparing", processed, total)).monospacedDigit()
            } else {
                ProgressView()
                Text(L("dupes.building_inventory"))
            }
            Button(L("common.cancel")) { model.cancel() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        MCEmptyState(icon: "checkmark.circle", title: L("dupes.none_found"), message: "",
                     iconColor: MCTheme.success,
                     actionTitle: L("smartcare.scan_again")) { model.start() }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("dupes.results.summary", model.groups.count, mcFormatBytes(model.selectedBytes), mcFormatBytes(model.wastedBytes)))
                    .font(MCFont.cardTitle)
                Spacer()
                Toggle(L("common.dry_run"), isOn: $model.dryRun).toggleStyle(.switch)
                Button(model.dryRun ? L("leftovers.simulate") : L("dupes.move_to_trash")) {
                    model.removeSelected()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedPaths.isEmpty || model.phase == .executing)
            }
            .padding()
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
            .padding(.horizontal).padding(.bottom, MCSpacing.xs)
            List {
                ForEach(model.filteredGroups) { group in
                    Section {
                        // Overlap motif: near-duplicate copies shown slightly
                        // overlapping, separating on hover — the rows below
                        // remain the real accessible detail and controls.
                        MCOverlapStack(items: group.urls.map { DupMember(id: $0.path, url: $0) },
                                       markedID: group.keeper.path) { member in
                            Image(nsImage: NSWorkspace.shared.icon(forFile: member.url.path))
                                .resizable().frame(width: 32, height: 32)
                                .padding(4)
                                .background(MCColor.elevatedBackground, in: RoundedRectangle(cornerRadius: MCRadius.small))
                        }
                        .padding(.vertical, MCSpacing.xxs)
                        ForEach(group.urls, id: \.path) { url in
                            HStack {
                                Toggle("", isOn: Binding(
                                    get: { model.selectedPaths.contains(url.path) },
                                    set: { on in
                                        if on { model.selectedPaths.insert(url.path) }
                                        else { model.selectedPaths.remove(url.path) }
                                    }
                                ))
                                .labelsHidden()
                                .accessibilityLabel(L("dupes.select_copy", url.lastPathComponent))
                                Text(url.lastPathComponent)
                                if url.path == group.keeper.path {
                                    Text(L("dupes.suggested_keeper"))
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(MCTheme.accent.opacity(0.2), in: Capsule())
                                        .help(L("dupes.suggested_keeper.why"))
                                }
                                Spacer()
                                Text(url.deletingLastPathComponent().path)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
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
                                .accessibilityLabel(L("common.reveal_in_finder"))
                                ExcludeButton(url: url, controller: model.exclusionsController)
                            }
                        }
                    } header: {
                        Text(L("dupes.group_header", group.urls.count, mcFormatBytes(group.fileSize)))
                    }
                }
            }
            .listStyle(.inset)
            .quickLookPreview($model.previewURL)
        }
    }

    private func finishedView(_ freed: Int64, _ dryRun: Bool) -> some View {
        MCEmptyState(
            icon: "checkmark.seal",
            title: dryRun ? L("leftovers.finished.dryrun", mcFormatBytes(freed))
                          : L("leftovers.finished.moved", mcFormatBytes(freed)),
            message: "", iconColor: MCTheme.success,
            actionTitle: L("smartcare.scan_again")) { model.start() }
    }
}
