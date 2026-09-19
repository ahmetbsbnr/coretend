// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import ScanCore
import SafetyCore
import DesignSystem
import Persistence
import QuickLookUI
import QuickLook
@preconcurrency import QuickLookThumbnailing

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
    /// Full Disk Access, re-checked on appear. Without it this module reads a
    /// fraction of what is there and reports it as a result.
    @State private var hasFullDiskAccess = ScanTargetAccess.canReadScanTarget
    @State private var scanAnyway = false
    @State var model = DuplicatesViewModel()
    @State private var selectionAnchor: String?
    private enum FocusTarget: Hashable { case groups, detail }
    @FocusState private var focus: FocusTarget?
    @State private var showMoveConfirmation = false
    @State private var selectedGroupID: String?
    /// Separate from the selection: side by side there is always a selected
    /// group, pushed there must be none on arrival or the person lands on a
    /// detail screen they never asked for.
    @State private var pushedGroupID: String?

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .idle where !hasFullDiskAccess && !scanAnyway:
                MCPermissionState(
                    title: L("permission.fulldisk.title"),
                    explanation: L("permission.fulldisk.explanation"),
                    limitation: L("permission.fulldisk.limitation"),
                    onContinue: { scanAnyway = true })
            case .idle:
                idleView
            case let .scanning(processed, total): scanningView(processed, total)
            case .empty: emptyView
            case .results, .executing: resultsView
            case let .finished(outcome): finishedView(outcome)
            }
        }
        // On the body, not on the idle branch: the permission gate matches
        // first, so the idle branch never appears and an autostarted capture
        // waited forever for a scan nobody had asked to run.
        .onAppear {
            hasFullDiskAccess = ScanTargetAccess.canReadScanTarget
            if CaptureHarness.autostartScan, model.phase == .idle {
                scanAnyway = true
                model.start()
            }
        }
        .navigationTitle(L("module.duplicates"))
        .scanCommands(
            start: { model.start() },
            pauseOrResume: { model.isScanPaused ? model.resumeScan() : model.pauseScan() },
            cancel: { model.cancel() })
        .accessibilityIdentifier("duplicates.root")
        .onChange(of: pushedGroupID) { old, new in
            if old != nil, new == nil { focus = .groups }
        }
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
                // ⌘A and ⌘⇧A were missing here entirely.
                //
                // Cleanup has bound them since the rebuild; Duplicates offered
                // bulk selection only as a button, so the shortcut a Mac user
                // reaches for first did nothing on the one screen where
                // selecting many things at once is the entire task. Found by
                // exercising the running app, not by reading the view: ⌘A
                // produced a byte-identical capture.
                Button(L("dupes.select_extras")) { model.selectAllButKeepers() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("a", modifiers: .command)
                    .disabled(model.filteredGroups.isEmpty)
                Button(L("dupes.select_none")) { model.selectedPaths.removeAll() }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(model.selectedPaths.isEmpty)
                    .accessibilityIdentifier("duplicates.select_none")
                Button(L("dupes.move_to_trash")) { showMoveConfirmation = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selectedPaths.isEmpty || model.phase == .executing)
                    .accessibilityIdentifier("duplicates.results.remove")
            }
            .padding(.horizontal, MCSpacing.page).padding(.vertical, MCSpacing.sm)
            Divider()
            // Side by side when both halves can be read, pushed when they
            // cannot — the shape the Record already uses. At 860pt the list's
            // 300pt minimum left the detail around 320pt for paths that are
            // routinely longer than that, and every one of them truncated.
            GeometryReader { proxy in
                if proxy.size.width >= 900 {
                    HStack(spacing: 0) {
                        groupList
                        Divider()
                        groupDetail
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .focusable().focused($focus, equals: .detail)
                            .onKeyPress(.escape) { focus = .groups; return .handled }
                    }
                    .onAppear { pushedGroupID = nil }
                } else {
                    NavigationStack {
                        groupList
                            .frame(maxWidth: .infinity)
                            .navigationDestination(item: $pushedGroupID) { _ in
                                groupDetail.navigationTitle(L("dupes.group"))
                                    .focusable().focused($focus, equals: .detail)
                                    .onAppear { focus = .detail }
                                    .onKeyPress(.escape) { pushedGroupID = nil; return .handled }
                            }
                    }
                }
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

    private var groupList: some View {
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
                    List(model.filteredGroups, selection: Binding(
                        get: { selectedGroupID },
                        set: { id in
                            selectedGroupID = id
                            selectionAnchor = nil
                        }
                    )) { group in
                        HStack(spacing: MCSpacing.xs) {
                            // The group list is the first place a person
                            // looks for "which pile is this?". A generic
                            // file-type icon answered "a picture" for every
                            // one of forty rows; the keeper's own preview
                            // answers it for this one.
                            DuplicateThumbnail(url: group.keeper, size: 22)
                            Text(group.keeper.lastPathComponent)
                                .font(MCFont.rowTitle)
                                .lineLimit(1)
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
                    .scrollContentBackground(.hidden)
                    .environment(\.defaultMinListRowHeight, 28)
                    .focused($focus, equals: .groups)
                    // Real actions, not an empty menu — see RecordView for the
                    // same defect and the audit that found both.
                    .contextMenu(forSelectionType: String.self) { ids in
                        if let id = ids.first,
                           let group = model.filteredGroups.first(where: { $0.id == id }) {
                            Button(L("dupes.context.open_group")) {
                                selectedGroupID = id
                                pushedGroupID = id
                                focus = .detail
                            }
                            Divider()
                            Button(L("dupes.context.select_group_extras")) {
                                for url in group.urls where url.path != group.keeper.path {
                                    model.selectedPaths.insert(url.path)
                                }
                            }
                            Button(L("common.reveal_in_finder")) {
                                NSWorkspace.shared.activateFileViewerSelecting([group.keeper])
                            }
                        }
                    } primaryAction: { ids in
                        guard let id = ids.first else { return }
                        selectedGroupID = id
                        pushedGroupID = id
                        focus = .detail
                    }
                }
        .frame(minWidth: 300, idealWidth: 380, maxWidth: 460)
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
                    Divider()
                    // Keeper first. It was in document order, so on a group
                    // of 31 copies the one row that says which file survives
                    // was the twentieth — below the fold, on a screen whose
                    // whole job is to show what will be kept.
                    ForEach(group.urls.sorted { a, b in
                        if (a.path == group.keeper.path) != (b.path == group.keeper.path) {
                            return a.path == group.keeper.path
                        }
                        return a.path < b.path
                    }, id: \.path) { url in
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
        // A 52pt preview next to baseline-aligned text pushes the checkbox and
        // the name down to the preview's first line of text, which is nothing.
        // Top alignment is what a row with artwork in it needs.
        return HStack(alignment: .top, spacing: MCSpacing.sm) {
            // Two points of accent against the row, the full height of the
            // preview. That is the whole "this one survives" signal: it is
            // unmissable when scanning a column of rows, and it colours none
            // of the content — the previous treatment put a filled badge in
            // the title line and the eye read the badge instead of the name.
            Rectangle()
                .fill(isKeeper ? MCTheme.accent : Color.clear)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)
            Toggle("", isOn: Binding(
                get: { model.selectedPaths.contains(url.path) },
                set: { on in
                    if on { model.selectedPaths.insert(url.path) } else { model.selectedPaths.remove(url.path) }
                }
            ))
            .labelsHidden()
            .accessibilityLabel(L("dupes.select_copy", url.lastPathComponent))
            DuplicateThumbnail(url: url, size: 52)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: MCSpacing.xs) {
                    // The name first. Every row showed only the folder, so a
                    // group of copies sitting in one folder rendered as the
                    // same truncated path repeated thirty-one times — nothing
                    // on screen distinguished one copy from another.
                    Text(url.lastPathComponent)
                        .font(MCFont.rowTitle)
                        .lineLimit(1).truncationMode(.middle)
                    if isKeeper {
                        // Text, not a filled pill. The word is small, it sits
                        // in the accent rather than in a block of it, and the
                        // rule down the left already carries the state — a
                        // pill here would be the same fact said twice, louder.
                        Text(L("dupes.suggested_keeper"))
                            .font(MCFont.microEmphasis)
                            .textCase(.uppercase)
                            .foregroundStyle(MCTheme.accent)
                            .accessibilityLabel(L("dupes.suggested_keeper"))
                    }
                }
                HStack(spacing: MCSpacing.xs) {
                    Text(PathDisplay.folder(of: url)).font(MCFont.monoCaption)
                        .foregroundStyle(MCColor.textTertiary)
                        .lineLimit(1).truncationMode(.middle)
                    // The date is what actually differs between copies, and it
                    // is the fact a person uses to decide which one is theirs.
                    if let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                        .contentModificationDate,
                       let age = FindingMetadata.ageDescription(for: modified) {
                        Text("·").foregroundStyle(MCColor.textTertiary)
                        Text(age).font(MCFont.caption)
                            .foregroundStyle(MCColor.textTertiary).lineLimit(1)
                    }
                }
                // Only the keeper has a recommendation. An empty Text still
                // occupies a line box, which is what made every one of the
                // other rows a third taller than it needed to be.
                let recommendation = model.recommendationText(for: url, in: group)
                if !recommendation.isEmpty {
                    Text(recommendation)
                        .font(MCFont.micro)
                        .foregroundStyle(MCColor.textTertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            ExcludeButton(url: url, controller: model.exclusionsController)
        }
        .padding(.vertical, MCSpacing.xxs)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.previewURL = url }
        .onTapGesture {
            let ordered = group.urls.sorted { a, b in
                if (a == group.keeper) != (b == group.keeper) { return a == group.keeper }
                return a.path < b.path
            }.map(\.path)
            if NSEvent.modifierFlags.contains(.shift),
               let anchor = selectionAnchor, let start = ordered.firstIndex(of: anchor),
               let end = ordered.firstIndex(of: url.path) {
                model.selectedPaths.formUnion(ordered[min(start, end)...max(start, end)])
            } else {
                if !model.selectedPaths.insert(url.path).inserted { model.selectedPaths.remove(url.path) }
                selectionAnchor = url.path
            }
        }
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

/// A copy's preview, or its file-type icon when it has none.
///
/// This screen's verb is *compare*. At 32pt a photograph is a coloured
/// rectangle — enough to say "this is a picture", not enough to say "this is
/// the same picture", which is the only question a person is asking while
/// looking at eight copies of one file. So a real preview is shown at the
/// size the caller asks for, and a file with no preview falls back to its
/// type icon at a *smaller* size inside the same box: an icon blown up to
/// 56pt is a blurred glyph pretending to be content.
///
/// The shape stays a plain rounded rect on the row's own surface. A card, a
/// shadow or a border around each thumbnail would make every row a panel, and
/// eight panels inside a panel is exactly the "cartes dans des cartes" this
/// screen had to stop doing.
struct DuplicateThumbnail: View {
    let url: URL
    var size: CGFloat = 32
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable().aspectRatio(contentMode: .fit)
                    // The icon keeps its own scale rather than filling the
                    // preview box, so a row of previews and a row of icons
                    // read as two different things — which they are.
                    .padding(size > 40 ? size * 0.22 : 4)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size > 40 ? MCRadius.small : 4, style: .continuous))
        .accessibilityHidden(true)
        .task(id: url) {
            // Best representation, not a forced render: a thumbnail the system
            // has to generate from scratch for a 9 GB archive is not worth the
            // wait, and the type icon says enough.
            let request = QLThumbnailGenerator.Request(
                fileAt: url, size: CGSize(width: size * 2, height: size * 2),
                scale: 2, representationTypes: .thumbnail)
            image = try? await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request).nsImage
        }
    }
}
