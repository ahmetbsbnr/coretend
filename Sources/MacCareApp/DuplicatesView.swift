import SwiftUI
import ScanCore
import SafetyCore
import DesignSystem
import Persistence

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
    var dryRun = true

    private var scanTask: Task<Void, Never>?
    private var scannedRoots: [URL] = []

    var wastedBytes: Int64 { groups.reduce(0) { $0 + $1.wastedBytes } }
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
        // Never allow a whole group to be removed: at least one copy must survive.
        for group in groups where group.urls.allSatisfy({ selectedPaths.contains($0.path) }) {
            selectedPaths.remove(group.keeper.path)
        }
        phase = .executing
        let toRemove = groups.flatMap { group in
            group.urls.filter { selectedPaths.contains($0.path) }.map { ($0, group.fileSize) }
        }
        let isDryRun = dryRun
        let roots = scannedRoots
        Task {
            let center = SafetyCenter(validator: PathValidator(allowedRoots: roots), dryRun: isDryRun)
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
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 56)).foregroundStyle(MCTheme.accentSecondary)
            Text(L("dupes.idle.title")).font(.title2.weight(.semibold))
            Text(L("dupes.idle.subtitle"))
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button(L("dupes.find")) { model.start() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48)).foregroundStyle(MCTheme.success)
            Text(L("dupes.none_found")).font(.title3.weight(.semibold))
            Button(L("smartcare.scan_again")) { model.start() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("dupes.results.summary", model.groups.count, mcFormatBytes(model.selectedBytes), mcFormatBytes(model.wastedBytes)))
                    .font(.headline)
                Spacer()
                Toggle(L("common.dry_run"), isOn: $model.dryRun).toggleStyle(.switch)
                Button(model.dryRun ? L("leftovers.simulate") : L("dupes.move_to_trash")) {
                    model.removeSelected()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedPaths.isEmpty || model.phase == .executing)
            }
            .padding()
            List {
                ForEach(model.groups) { group in
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
                                }
                                Spacer()
                                Text(url.deletingLastPathComponent().path)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                } label: { Image(systemName: "magnifyingglass") }
                                .buttonStyle(.borderless)
                            }
                        }
                    } header: {
                        Text(L("dupes.group_header", group.urls.count, mcFormatBytes(group.fileSize)))
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func finishedView(_ freed: Int64, _ dryRun: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48)).foregroundStyle(MCTheme.success)
            Text(dryRun ? L("leftovers.finished.dryrun", mcFormatBytes(freed))
                        : L("leftovers.finished.moved", mcFormatBytes(freed)))
                .font(.title3.weight(.semibold))
            Button(L("smartcare.scan_again")) { model.start() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
