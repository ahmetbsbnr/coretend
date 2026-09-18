// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

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
final class DuplicatesViewModel: CancellableScan {
    enum Phase: Equatable { case idle, scanning(processed: Int, total: Int), results, empty, executing, finished(ExecutionOutcome) }

    var phase: Phase = .idle
    var groups: [DuplicateGroup] = []
    var selectedPaths: Set<String> = []   // paths selected for removal
    var previewURL: URL?
    var searchText = ""
    var selectedVolumeID: String?
    var isScanPaused = false
    var exportError: String?
    var lastExportURL: URL?
    let volumeResolver: VolumeResolving
    let exclusionsController = ClutterExclusionsController()

    var scanTask: Task<Void, Never>?
    var pauseController: ScanPauseController?
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

    var exportFileName: String {
        "CoreTend-Duplicates-\(Self.exportDateFormatter.string(from: Date())).csv"
    }

    func start() {
        if case .scanning = phase { return }
        phase = .scanning(processed: 0, total: 0)
        groups = []
        selectedPaths = []
        isScanPaused = false
        let pauseController = ScanPauseController()
        self.pauseController = pauseController
        let home = CaptureHarness.scanHome
        scannedRoots = ["Downloads", "Documents", "Desktop"].map { home.appendingPathComponent($0) }
        let engine = DuplicateEngine(roots: scannedRoots)
        scanTask = Task {
            for await event in engine.run(pauseController: pauseController) {
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
                    CaptureHarness.note(state: groups.isEmpty ? "empty" : "results")
                    AppEnvironment.shared.record(ActivityRecord(
                        kind: .scan, summary: "Duplicate scan: \(count) groups",
                        itemCount: count, bytes: wasted))
                case .cancelled:
                    // Normally unreachable — see CancellableScan.
                    isScanPaused = false
                    phase = groups.isEmpty ? .idle : .results
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
        if case .scanning = phase { phase = groups.isEmpty ? .idle : .results }
    }

    /// Every copy that is not the suggested keeper. The batch rule people
    /// actually want, offered as one click rather than a hundred.
    func selectAllButKeepers() {
        for group in filteredGroups {
            for url in group.urls where url.path != group.keeper.path {
                selectedPaths.insert(url.path)
            }
        }
    }

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
        let roots = scannedRoots
        Task {
            let center = SafetyCenter(validator: PathValidator(allowedRoots: roots), sink: AppEnvironment.shared.store)
            let batch = await center.approveAll(toRemove.map {
                ApprovalRequest(url: $0.0, logicalSize: $0.1,
                                ruleID: "clutter.duplicates", risk: .medium)
            })
            let outcome = ExecutionOutcome(
                result: await center.execute(batch.approved),
                rejections: batch.rejections)
            phase = .finished(outcome)
            AppEnvironment.shared.record(ActivityRecord(
                kind: .cleanup,
                summary: outcome.annotate("Moved \(outcome.executedCount) duplicate copies to Trash"),
                itemCount: outcome.executedCount, bytes: outcome.movedToTrashBytes))
        }
    }

    func exportCSV(language: AppLanguage? = nil) -> String {
        var rows: [[String]] = [[
            "group_id", "path", "file_name", "directory", "size_bytes", "size_readable",
            "selected_for_removal", "suggested_keeper", "recommendation"
        ]]
        for group in filteredGroups {
            for url in group.urls {
                rows.append([
                    group.id,
                    url.path,
                    url.lastPathComponent,
                    url.deletingLastPathComponent().path,
                    "\(group.fileSize)",
                    mcFormatBytes(group.fileSize),
                    selectedPaths.contains(url.path) ? "true" : "false",
                    url.path == group.keeper.path ? "true" : "false",
                    recommendationText(for: url, in: group, language: language)
                ])
            }
        }
        return rows.map { $0.map(Self.csvField).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    func exportSelection(to url: URL) throws {
        try exportCSV().write(to: url, atomically: true, encoding: .utf8)
        lastExportURL = url
        exportError = nil
        AppEnvironment.shared.record(ActivityRecord(
            kind: .scan, summary: "Duplicate report exported",
            itemCount: filteredGroups.count, bytes: selectedBytes))
    }

    func recommendationText(for url: URL, in group: DuplicateGroup, language: AppLanguage? = nil) -> String {
        guard url.path == group.keeper.path else { return "" }
        return language.map {
            LocalizationManager.string(forKey: "dupes.suggested_keeper.why", language: $0)
        } ?? L("dupes.suggested_keeper.why")
    }

    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    // Pure string escaping — touches no actor-isolated state, so it doesn't
    // need MainActor isolation. Without `nonisolated`, Swift 6.0.3 (Xcode
    // 16.2, the Compatibility Matrix floor) rejects passing this as a bare
    // function reference to `.map` as a "main actor-isolated ... in a
    // synchronous nonisolated context" error that Swift 6.1+ (Xcode 16.4,
    // used by the green main CI) does not raise for the same code — a
    // compiler-version isolation-inference gap, not a real data race.
    private nonisolated static func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

struct DuplicatesView: View {
    @State private var model = DuplicatesViewModel()
    @State private var showMoveConfirmation = false
    @State private var selectedGroupID: String?

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .idle: idleView.onAppear { if CaptureHarness.autostartScan { model.start() } }
            case let .scanning(processed, total): scanningView(processed, total)
            case .empty: emptyView
            case .results, .executing: resultsView
            case let .finished(outcome): finishedView(outcome)
            }
        }
        .navigationTitle(L("module.duplicates"))
        .scanCommands(
            start: { model.start() },
            pauseOrResume: { model.isScanPaused ? model.resumeScan() : model.pauseScan() },
            cancel: { model.cancel() })
        .accessibilityIdentifier("duplicates.root")
        .confirmationDialog(
            L("common.trash_confirm.title"),
            isPresented: $showMoveConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("common.trash_confirm.action"), role: .destructive) {
                model.removeSelected()
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("common.trash_confirm.message"))
        }
    }

    private var idleView: some View {
        VStack(spacing: MCSpacing.xl) {
            VStack(spacing: MCSpacing.xs) {
                Text(L("dupes.idle.title"))
                    .font(MCFont.pageTitle)
                    .multilineTextAlignment(.center)
                Text(L("dupes.idle.subtitle"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(MCColor.textSecondary)
                    .multilineTextAlignment(.center)
                    // No .fixedSize here. fixedSize(vertical:) makes a Text
                    // report its ideal, UNWRAPPED width upward; for this
                    // three-line string that ideal width propagated out as the
                    // detail column's minimum and collapsed the
                    // NavigationSplitView sidebar to zero width. The rows
                    // stayed in the accessibility tree — they were simply laid
                    // out at no width — which is why the sidebar looked empty
                    // rather than missing. That was the blank sidebar reported
                    // against 1.0.1, and it reproduced only here because this
                    // is the longest idle subtitle in the app.
                    //
                    // Reordering does not help: .frame(maxWidth:) is a maximum,
                    // not a clamp, so the ideal width still propagates. The
                    // frame alone wraps the text correctly and is enough.
                    .frame(maxWidth: 460)
            }
            .mcAppear()
            MCScanButton(L("dupes.find"), systemImage: "doc.on.doc.fill") { model.start() }
                .accessibilityIdentifier("duplicates.scan.start")
                .mcAppear(delay: 0.06)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MCSpacing.xl)
    }

    private func scanningView(_ processed: Int, _ total: Int) -> some View {
        VStack(spacing: MCSpacing.lg) {
            MCScanStage(isScanning: !model.isScanPaused,
                        fraction: total > 0 ? Double(processed) / Double(total) : nil) {
                Text(total > 0 ? L("dupes.comparing", processed, total) : L("dupes.building_inventory"))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(total > 0 ? L("dupes.comparing", processed, total) : L("dupes.building_inventory"))
            MCScanControls(
                identifierPrefix: "duplicates",
                isPaused: model.isScanPaused,
                pauseHintKey: "cleanup.pause_hint",
                resumeHintKey: "cleanup.resume_hint",
                onPause: { model.pauseScan() },
                onResume: { model.resumeScan() },
                onCancel: { model.cancel() })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        MCEmptyState(icon: "checkmark.circle", title: L("dupes.none_found"), message: "",
                     iconColor: MCTheme.success,
                     actionTitle: L("smartcare.scan_again")) { model.start() }
    }

    /// The decision workflow: pick a group on the left, decide on the right.
    ///
    /// Every group is one line — the name, how many copies, what one copy
    /// weighs, what the extra copies cost. The right pane shows the copies of
    /// the selected group with the suggested keeper marked and the reason
    /// spelled out, a checkbox per copy, and Quick Look on Space. The former
    /// layout listed every copy of every group in one scroll, with the wasted
    /// total in 40pt on top; a decision screen that starts with a number in
    /// display type is a screen that has decided for you.
    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: MCSpacing.md) {
                Text(L("dupes.results.sentence", model.groups.count, mcFormatBytes(model.wastedBytes),
                       mcFormatBytes(model.selectedBytes)))
                    .font(MCFont.body)
                Spacer()
                Button(L("dupes.select_extras")) { model.selectAllButKeepers() }
                    .buttonStyle(.bordered)
                    .disabled(model.filteredGroups.isEmpty)
                Button(L("dupes.move_to_trash")) { showMoveConfirmation = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selectedPaths.isEmpty || model.phase == .executing)
                    .accessibilityIdentifier("duplicates.results.remove")
            }
            .padding(.horizontal, MCSpacing.page).padding(.vertical, MCSpacing.sm)
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: MCSpacing.xs) {
                        MCSearchField(text: $model.searchText, placeholder: L("clutter.search_placeholder"))
                        if model.availableVolumes.count > 1 {
                            Picker(L("clutter.volume"), selection: $model.selectedVolumeID) {
                                Text(L("clutter.all_volumes")).tag(String?.none)
                                ForEach(model.availableVolumes) { volume in
                                    Text(volume.id == VolumeInfo.unavailable.id ? L("clutter.volume_unavailable") : volume.name)
                                        .tag(String?.some(volume.id))
                                }
                            }
                            .pickerStyle(.menu).labelsHidden().frame(width: 140)
                        }
                        Spacer(minLength: 0)
                        ExclusionsMenu(controller: model.exclusionsController)
                    }
                    .padding(.horizontal, MCSpacing.sm).padding(.vertical, MCSpacing.xs)
                    Divider()
                    List(model.filteredGroups, selection: $selectedGroupID) { group in
                        HStack(spacing: MCSpacing.xs) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: group.keeper.path))
                                .resizable().frame(width: 16, height: 16).accessibilityHidden(true)
                            Text(group.keeper.lastPathComponent).lineLimit(1)
                            Text(L("dupes.copies_count", group.urls.count))
                                .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                            Spacer(minLength: MCSpacing.xs)
                            Text(mcFormatBytes(group.wastedBytes)).font(MCFont.tabular)
                                .foregroundStyle(MCColor.textSecondary)
                        }
                        .tag(group.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(L("dupes.group_a11y", group.keeper.lastPathComponent,
                                              group.urls.count, mcFormatBytes(group.wastedBytes)))
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 28)
                }
                .frame(minWidth: 300, idealWidth: 380, maxWidth: 460)
                Divider()
                groupDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { if selectedGroupID == nil { selectedGroupID = model.filteredGroups.first?.id } }
        .quickLookPreview($model.previewURL)
        .alert(L("settings.migration_failed"), isPresented: Binding(
            get: { model.exportError != nil },
            set: { if !$0 { model.exportError = nil } }
        )) {
            Button(L("onboarding.check.status.ok"), role: .cancel) { model.exportError = nil }
        } message: {
            Text(model.exportError ?? "")
        }
    }

    @ViewBuilder
    private var groupDetail: some View {
        if let group = model.filteredGroups.first(where: { $0.id == selectedGroupID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: MCSpacing.md) {
                    Text(group.keeper.lastPathComponent).font(MCFont.pageTitle).lineLimit(2)
                    Text(L("dupes.group_fact", group.urls.count, mcFormatBytes(group.fileSize),
                           mcFormatBytes(group.wastedBytes)))
                        .font(MCFont.body).foregroundStyle(MCColor.textSecondary)
                    Text(L("dupes.suggested_keeper.why")).font(MCFont.caption)
                        .foregroundStyle(MCColor.textSecondary)
                    Divider()
                    ForEach(group.urls, id: \.path) { url in
                        copyRow(url, in: group)
                        Divider()
                    }
                }
                .padding(MCSpacing.page)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            MCEmptyState(icon: "sidebar.left", title: L("dupes.select_group_title"),
                         message: L("dupes.select_group_message"))
        }
    }

    private func copyRow(_ url: URL, in group: DuplicateGroup) -> some View {
        let isKeeper = url.path == group.keeper.path
        return HStack(alignment: .top, spacing: MCSpacing.sm) {
            Toggle("", isOn: Binding(
                get: { model.selectedPaths.contains(url.path) },
                set: { on in
                    if on { model.selectedPaths.insert(url.path) } else { model.selectedPaths.remove(url.path) }
                }
            ))
            .labelsHidden()
            .accessibilityLabel(L("dupes.select_copy", url.lastPathComponent))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: MCSpacing.xs) {
                    Text(url.deletingLastPathComponent().path).font(MCFont.monoCaption)
                        .lineLimit(1).truncationMode(.middle)
                    if isKeeper {
                        Text(L("dupes.suggested_keeper")).font(MCFont.badge)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(MCTheme.success.opacity(0.18), in: Capsule())
                            .foregroundStyle(MCTheme.success)
                    }
                }
                Text(model.recommendationText(for: url, in: group))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            }
            Spacer(minLength: 0)
            ExcludeButton(url: url, controller: model.exclusionsController)
        }
        .padding(.vertical, MCSpacing.xxs)
        .fileRowActions(FileRowAction.inspection(for: url) { model.previewURL = $0 })
    }

    private func finishedView(_ outcome: ExecutionOutcome) -> some View {
        MCSuccessState(
            title: L("leftovers.finished.moved", mcFormatBytes(outcome.movedToTrashBytes)),
            message: outcome.message,
            actionTitle: L("smartcare.scan_again")) { model.start() }
    }

    private func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = model.exportFileName
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try model.exportSelection(to: url)
            } catch {
                model.exportError = error.localizedDescription
            }
        }
    }
}
