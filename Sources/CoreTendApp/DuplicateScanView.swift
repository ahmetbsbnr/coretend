import DesignSystem
import SwiftUI
import AppKit
import QuickLook
import UniformTypeIdentifiers
import ScanCore
import AppShell
import SafetyCore
import Domain

/// Duplicates, "les pousses jumelles": exact copies found by content, or images that only look
/// close. Nothing is preselected; each exact group shows which file is kept, and the "Kept" label
/// hops to another shoot when the person keeps a different one. Only copies the person checks can
/// go to the Trash, never the kept file.
struct DuplicateScanView: View {
    let french: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var keeperSpace
    @State private var selectingFolder = false
    @State private var scanning = false
    @State private var scanCompletedFiles = 0
    @State private var analysisProgress: DuplicateScanProgress?
    @State private var rootsPhase: ScanRootsPhase?
    @State private var report: DuplicateScanReport?
    @State private var notice: PageNotice?
    @State private var scanTask: Task<Void, Never>?
    @State private var activeScanID: UUID?
    @State private var selectedRoot: URL?
    @State private var selectedCopies: Set<URL> = []
    @State private var keepers = DuplicateKeepers()
    @State private var actionReview: ActionReview?
    @State private var actionDialogPresented = false
    @State private var actionService: FileActionService?
    @State private var actionBusy = false
    @State private var moving = false
    @State private var actionScopeHeld = false
    @State private var actionScopedRoot: URL?
    @State private var similarMode = false
    @State private var similarReport: SimilarImageReport?
    @State private var previewURL: URL?
    @State private var previewScopeHeld = false
    @State private var previewScopedRoot: URL?
    @State private var failures: [URL: String] = [:]
    /// Copies already in the Trash; their group shows what is left, and goes when one file is left.
    @State private var movedAway: Set<URL> = []
    @State private var flight = LeafFlight()
    @State private var scrollTarget: String?

    private var locked: Bool { scanning || actionBusy || actionReview != nil }

    /// Real work done so far: files read, then files hashed or images decoded and compared.
    private var workDone: Int {
        switch analysisProgress {
        case .duplicateHashing(let completed, _), .imageCandidates(let completed, _), .imageComparisons(let completed, _):
            scanCompletedFiles + completed
        case nil:
            scanCompletedFiles
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation(reduceMotion ? nil : MotionCurve.sap.animation(duration: MotionToken.grow.duration)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    scrollTarget = nil
                }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            modes
            if let selectedRoot {
                scope(selectedRoot)
            } else {
                SerreParcel {
                    SerreEmptyState(title: copy("duplicates.initial.title"), message: copy("duplicates.initial.message")) {
                        Button { selectingFolder = true } label: {
                            Label { Text(copy("explore.choose")) } icon: { SerreIcon(.duplicates, size: 15) }
                        }
                        .buttonStyle(.serre(.primary))
                        .accessibilityHint(copy("duplicates.choose.hint"))
                        .padding(.top, 6)
                    }
                }
            }
            if let notice, !notice.nearActions { banner(notice) }
            if let rootsPhase { roots(rootsPhase).id("duplicates.roots") }
            if !scanning {
                if similarMode, let similarReport { similarSection(similarReport) }
                if !similarMode, let report { exactSection(report) }
            }
        }
        .leafFlightLayer(flight)
        .motion(.standard, value: notice)
        .motion(.standard, value: rootsPhase)
        .fileImporter(isPresented: $selectingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let root = urls.first else {
                notice = PageNotice(kind: .error, title: copy("scan.failed"), recovery: .chooseAgain); return
            }
            selectedRoot = root
            beginScan(root)
        }
        .onDisappear {
            scanTask?.cancel(); activeScanID = nil; scanning = false
            analysisProgress = nil
            previewURL = nil
            releasePreviewScope()
            if actionReview != nil { cancelAction() }
        }
        .confirmationDialog(french ? "Déplacer vers la Corbeille macOS ?" : "Move to macOS Trash?", isPresented: $actionDialogPresented, titleVisibility: .visible) {
            Button(french ? "Déplacer les copies" : "Move copies to Trash", role: .destructive) { beginExecution() }
            Button(copy("common.cancel"), role: .cancel) { cancelAction() }
                // Return cancels: a move to the Trash is only ever a deliberate click.
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(reviewMessage)
        }
        .quickLookPreview($previewURL)
        .onChange(of: previewURL) { _, item in
            if item == nil { releasePreviewScope() }
        }
        .onChange(of: actionDialogPresented) { _, presented in
            if !presented && actionReview != nil { cancelAction() }
        }
    }

    // MARK: - Sections

    private var modes: some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 6) {
                Text(copy("duplicates.intro.title")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                Text(copy("duplicates.intro.message")).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                    .padding(.bottom, 6)
                modeRow(similar: false, title: "duplicates.mode.exact", help: "duplicates.mode.exact.help")
                modeRow(similar: true, title: "duplicates.mode.similar", help: "duplicates.mode.similar.help")
            }
        }
        .motion(.quick, value: similarMode)
    }

    private func modeRow(similar: Bool, title: String, help: String) -> some View {
        let selected = similarMode == similar
        return Button {
            guard similarMode != similar else { return }
            similarMode = similar
            if let selectedRoot { beginScan(selectedRoot) }
        } label: {
            HStack(spacing: 12) {
                SerreCheck(isOn: selected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(copy(title)).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                    Text(copy(help)).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.serre(.row(selected: selected)))
        .disabled(locked)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func scope(_ root: URL) -> some View {
        SerreParcel {
            HStack(alignment: .center, spacing: 12) {
                SerreIcon(.duplicates, size: 18).foregroundStyle(Palette.accent.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(copy("explore.scope")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                    Text(root.path).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                        .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 8)
                Button(copy("explore.chooseOther")) { selectingFolder = true }
                    .buttonStyle(.serre(.secondary))
                    .disabled(locked)
                    .accessibilityHint(copy("duplicates.choose.hint"))
            }
        }
    }

    private func roots(_ phase: ScanRootsPhase) -> some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 12) {
                ScanRoots(completed: workDone,
                          count: ProductFormat.count(scanCompletedFiles, french: french),
                          caption: ProductFormat.filesExamined(scanCompletedFiles, french: french) + "\n"
                              + (phase == .finished ? copy("scan.finished") : progressTitle + " · " + progressDetail),
                          phase: phase)
                if phase == .reading {
                    Button(copy("scan.cancel")) { cancelScan() }
                        .buttonStyle(.serre(.secondary))
                }
            }
        }
        .transition(.opacity)
    }

    private func banner(_ notice: PageNotice) -> some View {
        PageNoticeBanner(notice: notice, french: french, disabled: locked, chooseAgain: { selectingFolder = true },
                         retryScan: selectedRoot.map { root in { beginScan(root) } })
    }

    /// A group as it stands now: the files still in place, if at least two remain.
    private func standing(_ group: DuplicateGroup) -> [URL]? {
        let files = group.files.filter { !movedAway.contains($0) }
        return files.count > 1 ? files : nil
    }

    @ViewBuilder
    private func exactSection(_ report: DuplicateScanReport) -> some View {
        let groups = report.groups.filter { standing($0) != nil }
        if report.groups.isEmpty && flight.landed == 0 {
            SerreEmptyState(title: copy("duplicates.none"), message: copy("duplicates.none.help"))
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(copy("duplicates.count", count: groups.count))
                        .font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                    Spacer()
                    Text(french ? "Aucune sélection automatique" : "Nothing selected automatically")
                        .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                }
                ForEach(Array(groups.enumerated()), id: \.element.digest) { index, group in
                    groupParcel(group).serreRise(index)
                }
                Text(copy("duplicates.check"))
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .leafFlightAnchor("list")
                HStack(spacing: 14) {
                    TrashIndicator(landed: flight.landed, moving: moving, french: french)
                    Spacer()
                    Button { Task { await prepareAction() } } label: {
                        Text(french ? "Examiner \(ProductFormat.items(selectedCopies.count, french: true))"
                                    : "Review \(ProductFormat.items(selectedCopies.count, french: false))")
                    }
                    .buttonStyle(.serre(.primary))
                    .disabled(selectedCopies.isEmpty || locked)
                    .accessibilityHint(french ? "Les copies choisies seront revérifiées avant déplacement vers la Corbeille." : "Chosen copies are revalidated before moving to Trash.")
                }
                if let notice, notice.nearActions { banner(notice) }
                if !report.issues.isEmpty {
                    SerreBanner(.partial, title: copy("scan.partial"))
                }
            }
        }
    }

    private func groupParcel(_ group: DuplicateGroup) -> some View {
        let kept = keepers.keeper(of: group.digest, suggested: group.suggestedKeeper)
        return SerreParcel {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(ProductFormat.count((standing(group) ?? group.files).count, french: french)) \(copy("duplicates.twins"))")
                    .font(CoreTendTypography.caption.weight(.semibold)).foregroundStyle(Palette.secondaryInk.color)
                    .padding(.bottom, 4)
                ForEach(standing(group) ?? group.files, id: \.path) { file in
                    shoot(file, group: group, kept: file == kept)
                }
            }
        }
    }

    /// One shoot of a group: the kept one wears the "Kept" leaf; any other can be checked for the
    /// Trash or become the kept one.
    private func shoot(_ file: URL, group: DuplicateGroup, kept: Bool) -> some View {
        let selected = selectedCopies.contains(file)
        let failure = failures[file]
        return HStack(spacing: 10) {
            Button {
                guard !kept, !locked else { return }
                if selected { selectedCopies.remove(file) } else { selectedCopies.insert(file) }
            } label: {
                HStack(spacing: 12) {
                    SerreCheck(isOn: selected).opacity(kept ? 0 : 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.lastPathComponent).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                            .lineLimit(1).truncationMode(.middle)
                        Text(relativeFolder(file)).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                            .lineLimit(1).truncationMode(.middle)
                        if let failure {
                            Text(copy(failure)).font(CoreTendTypography.caption).foregroundStyle(Palette.danger.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    if kept { keptLabel(group.digest) }
                }
            }
            .buttonStyle(.serre(.row(selected: selected)))
            // The kept shoot stays bright: it is chosen, not unavailable; clicking it does nothing.
            .disabled(locked)
            .accessibilityLabel(file.lastPathComponent)
            .accessibilityValue(kept ? copy("duplicates.kept") : (failure.map { copy($0) } ?? ""))
            .accessibilityAddTraits(selected ? .isSelected : [])
            if !kept {
                Button(copy("duplicates.keepThis")) {
                    withAnimation(reduceMotion ? nil : MotionCurve.sprout.animation(duration: 0.38)) {
                        keepers.keep(file, of: group.digest, files: group.files, selection: &selectedCopies)
                    }
                }
                .buttonStyle(.serre(.icon))
                .disabled(locked)
            }
            Button { showPreview(file) } label: {
                Image(systemName: "eye").foregroundStyle(Palette.secondaryInk.color)
            }
            .buttonStyle(.serre(.icon))
            .help(copy("explore.preview"))
            .accessibilityLabel(previewLabel(for: file))
        }
        .overlay {
            if failure != nil { LeafCorner.control.shape.strokeBorder(Palette.danger.color, lineWidth: 1) }
        }
        .leafFlightRow(file)
        .transition(reduceMotion ? .identity : .asymmetric(insertion: .identity, removal: .opacity.combined(with: .scale(scale: 0.6, anchor: .leading))))
    }

    /// The "Kept" leaf. One per group; it hops to the newly kept shoot.
    private func keptLabel(_ digest: String) -> some View {
        HStack(spacing: 5) {
            RiskLeafShape(level: .low).fill(Palette.onAccent.color).frame(width: 10, height: 10)
            Text(copy("duplicates.kept")).font(CoreTendTypography.caption.weight(.semibold))
        }
        .foregroundStyle(Palette.onAccent.color)
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background(Palette.accent.color, in: LeafCorner.control.shape)
        .matchedGeometryEffect(id: "kept.\(digest)", in: keeperSpace)
    }

    @ViewBuilder
    private func similarSection(_ report: SimilarImageReport) -> some View {
        if report.candidates.isEmpty {
            SerreEmptyState(title: copy("duplicates.similar.none"), message: copy("duplicates.similar.none.help"))
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text(french ? "\(ProductFormat.count(report.candidates.count, french: true)) paires proches" : "\(ProductFormat.count(report.candidates.count, french: false)) close pairs")
                    .font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                ForEach(Array(report.candidates.enumerated()), id: \.element.id) { index, pair in
                    SerreParcel {
                        HStack(alignment: .center, spacing: 14) {
                            twin(pair.first)
                            twin(pair.second)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pair.first.lastPathComponent).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                                Text(pair.second.lastPathComponent).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                                Text(french ? "Écart perceptuel : \(pair.differingBits)/64" : "Perceptual distance: \(pair.differingBits)/64")
                                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .serreRise(index)
                }
                SerreBanner(.note, title: copy("duplicates.mode.similar.help"))
            }
        }
        if report.skippedCount > 0 {
            SerreBanner(.partial, title: french ? "\(report.skippedCount) fichiers ignorés (format ou limite)." : "\(report.skippedCount) files skipped (format or limit).")
        }
    }

    private func twin(_ url: URL) -> some View {
        Button { showPreview(url) } label: { imagePreview(url) }
            .buttonStyle(.serre(.tile))
            .accessibilityLabel(previewLabel(for: url))
            .accessibilityHint(french ? "Ouvre l’aperçu Quick Look." : "Opens the Quick Look preview.")
    }

    private func relativeFolder(_ url: URL) -> String {
        guard let root = selectedRoot else { return url.deletingLastPathComponent().path }
        let folder = url.deletingLastPathComponent().standardizedFileURL.path
        let base = root.standardizedFileURL.path
        guard folder.hasPrefix(base) else { return folder }
        let rest = folder.dropFirst(base.count).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return rest.isEmpty ? root.lastPathComponent : root.lastPathComponent + "/" + rest
    }

    // MARK: - Scanning

    private func beginScan(_ root: URL) {
        scanTask?.cancel()
        previewURL = nil
        let scanID = UUID()
        activeScanID = scanID
        let hasScope = root.startAccessingSecurityScopedResource()
        scanning = true
        rootsPhase = .reading
        scrollTarget = "duplicates.roots"
        scanCompletedFiles = 0
        analysisProgress = nil
        notice = nil
        report = nil
        similarReport = nil
        selectedCopies = []
        keepers = DuplicateKeepers()
        failures = [:]
        movedAway = []
        flight.landed = 0
        scanTask = Task {
            var rootFailure: String?
            var partialFailures = Set<String>()
            defer {
                if hasScope { root.stopAccessingSecurityScopedResource() }
                if activeScanID == scanID { scanning = false; activeScanID = nil }
            }
            do {
                var candidates: [ScanResult] = []
                let exclusions = try await LocalStoreAccess.exclusions()
                for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: .duplicates)], exclusions: exclusions)) {
                    guard !Task.isCancelled, activeScanID == scanID else { return }
                    switch event {
                    case .result(let result): candidates.append(result)
                    case .itemFailure(let path, let reason):
                        if path == root.path { rootFailure = reason } else { partialFailures.insert(reason) }
                    case .progress(let completed): scanCompletedFiles = completed
                    case .finished: break
                    }
                }
                try Task.checkCancellation()
                guard activeScanID == scanID else { return }
                if let rootFailure {
                    rootsPhase = nil
                    notice = PageNotice(kind: .denied, title: ProductCopy.scanRootFailure(reason: rootFailure, french: french), recovery: .chooseAgain)
                    return
                }
                if similarMode {
                    let result = try await findSimilarWithProgress(candidates.map(\.url))
                    try Task.checkCancellation()
                    guard activeScanID == scanID else { return }
                    similarReport = result
                } else {
                    let result = try await findDuplicatesWithProgress(candidates)
                    try Task.checkCancellation()
                    guard activeScanID == scanID else { return }
                    report = result
                }
                rootsPhase = .finished
                if !partialFailures.isEmpty {
                    notice = PageNotice(kind: .partial, title: copy("scan.partial"),
                                        message: ProductCopy.scanPartialFailure(reasons: partialFailures, french: french))
                }
            } catch is CancellationError {
                if activeScanID == scanID { notice = PageNotice(kind: .note, title: copy("scan.cancelled")) }
            } catch {
                if activeScanID == scanID {
                    rootsPhase = nil
                    notice = PageNotice(kind: .error, title: copy("scan.failed"), recovery: .retryScan)
                }
            }
        }
    }

    private func cancelScan() {
        scanTask?.cancel()
        activeScanID = nil
        scanning = false
        analysisProgress = nil
        notice = PageNotice(kind: .note, title: copy("scan.cancelled"))
        rootsPhase = .retracted
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 450))
            if rootsPhase == .retracted { rootsPhase = nil; scanCompletedFiles = 0 }
        }
    }

    private var progressTitle: String {
        guard let analysisProgress else { return copy("scan.progress") }
        switch analysisProgress {
        case .duplicateHashing: return french ? "Hachage des doublons" : "Hashing duplicates"
        case .imageCandidates: return french ? "Analyse des images" : "Checking images"
        case .imageComparisons: return french ? "Comparaison des images" : "Comparing images"
        }
    }

    private var progressDetail: String {
        guard let analysisProgress else { return ProductCopy.scanProgress(completedFiles: scanCompletedFiles, french: french) }
        switch analysisProgress {
        case .duplicateHashing(let completed, let total):
            return ProductCopy.duplicateHashProgress(completed: completed, total: total, french: french)
        case .imageCandidates(let completed, let total):
            return ProductCopy.similarImageProgress(completed: completed, total: total, comparingPairs: false, french: french)
        case .imageComparisons(let completed, let total):
            return ProductCopy.similarImageProgress(completed: completed, total: total, comparingPairs: true, french: french)
        }
    }

    private func findDuplicatesWithProgress(_ candidates: [ScanResult]) async throws -> DuplicateScanReport {
        let channel = AsyncStream<DuplicateScanProgress>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let worker = Task.detached(priority: .utility) {
            defer { channel.continuation.finish() }
            return try await DuplicateEngine().findGroups(in: candidates) { channel.continuation.yield($0) }
        }
        return try await withTaskCancellationHandler {
            for await progress in channel.stream {
                try Task.checkCancellation()
                analysisProgress = progress
            }
            try Task.checkCancellation()
            return try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private func findSimilarWithProgress(_ urls: [URL]) async throws -> SimilarImageReport {
        let channel = AsyncStream<DuplicateScanProgress>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let worker = Task.detached(priority: .utility) {
            defer { channel.continuation.finish() }
            return try await SimilarImageEngine().findSimilar(in: urls) { channel.continuation.yield($0) }
        }
        return try await withTaskCancellationHandler {
            for await progress in channel.stream {
                try Task.checkCancellation()
                analysisProgress = progress
            }
            try Task.checkCancellation()
            return try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private func releasePreviewScope() {
        if previewScopeHeld, let previewScopedRoot { previewScopedRoot.stopAccessingSecurityScopedResource() }
        previewScopeHeld = false
        previewScopedRoot = nil
    }

    private func showPreview(_ url: URL) {
        guard let selectedRoot else {
            notice = PageNotice(kind: .error, title: copy("preview.unavailable"), nearActions: true)
            return
        }
        if previewScopeHeld, previewScopedRoot != selectedRoot { releasePreviewScope() }
        let alreadyScopedToRoot = previewScopeHeld && previewScopedRoot == selectedRoot
        let acquiredScope = alreadyScopedToRoot ? false : selectedRoot.startAccessingSecurityScopedResource()
        guard QuickLookCandidate.isAllowed(url, within: selectedRoot) else {
            if acquiredScope { selectedRoot.stopAccessingSecurityScopedResource() }
            notice = PageNotice(kind: .error, title: copy("preview.unavailable"), nearActions: true)
            return
        }
        if acquiredScope {
            previewScopeHeld = true
            previewScopedRoot = selectedRoot
        }
        previewURL = url
    }

    @MainActor private func prepareAction() async {
        guard let root = selectedRoot, let exactReport = report, !similarMode,
              !selectedCopies.isEmpty, !scanning, !actionBusy, actionReview == nil else { return }
        actionBusy = true
        defer { actionBusy = false; if actionReview == nil { releaseActionScope() } }
        do {
            actionScopeHeld = root.startAccessingSecurityScopedResource()
            actionScopedRoot = root
            let store = try await LocalStoreAccess.open()
            let rule = ScanRule.duplicates.rawValue
            let allowed = Set([rule])
            let executor = SafeActionExecutor(allowedRoots: [root], allowedRules: allowed, trash: MacOSTrashClient())
            let service = FileActionService(validator: .init(), executor: executor, store: store, allowedRoots: [root], allowedRuleIDs: allowed)
            let selections = selectedCopies.sorted { $0.path < $1.path }.map { FileActionSelection(url: $0, ruleID: rule) }
            // The kept file of every touched group is protected: the review refuses to move it and
            // the move stops if it changed.
            let protectedKeepers = keepers.protectedKeepers(
                groups: exactReport.groups.map { (digest: $0.digest, files: $0.files, suggested: $0.suggestedKeeper) },
                selection: selectedCopies)
            let review = try service.prepareReview(selections, protectedKeepers: protectedKeepers)
            guard await service.recordProposal(review) else {
                notice = PageNotice(kind: .error, title: french ? "Journal indisponible; action bloquée." : "History unavailable; action blocked.", nearActions: true)
                return
            }
            actionReview = review
            actionService = service
            actionDialogPresented = true
        } catch { notice = PageNotice(kind: .error, title: french ? "Revue impossible; aucune copie déplacée." : "Review failed; no copies moved.", nearActions: true) }
    }

    private func beginExecution() {
        guard let review = actionReview, let service = actionService else { return }
        actionBusy = true
        actionDialogPresented = false
        actionReview = nil; actionService = nil
        Task { await executeAction(review, service) }
    }

    @MainActor private func executeAction(_ review: ActionReview, _ service: FileActionService) async {
        moving = true
        defer { moving = false; actionBusy = false; releaseActionScope() }
        let batch: ConfirmedActionBatch
        do { batch = try service.confirm(review, accepted: true) } catch {
            notice = PageNotice(kind: .error, title: french ? "Action refusée; aucune copie déplacée." : "Action refused; no copies moved.", nearActions: true)
            return
        }
        failures = [:]; flight.landed = 0; notice = nil
        let outcome = await executeShowingEachItem(service, batch, reduceMotion: reduceMotion) { item in
            let url = item.targetURL
            guard item.moved else {
                failures[url] = item.failureKey
                selectedCopies.remove(url)
                return
            }
            flight.send(url, reduceMotion: reduceMotion)
            withAnimation(reduceMotion ? nil : MotionCurve.retreat.animation(duration: 0.2)) {
                selectedCopies.remove(url)
                movedAway.insert(url)
            }
        }
        notice = .moveOutcome(outcome, french: french)
    }

    private func cancelAction() {
        guard let review = actionReview, let service = actionService else { return }
        actionBusy = true
        actionDialogPresented = false
        actionReview = nil; actionService = nil
        Task { @MainActor in
            let saved = await service.recordCancellation(review)
            notice = PageNotice(kind: .note, title: saved ? (french ? "Action annulée; annulation journalisée." : "Action cancelled; cancellation recorded.") : (french ? "Action annulée; journal indisponible." : "Action history unavailable."), nearActions: true)
            releaseActionScope()
            actionBusy = false
        }
    }

    private var reviewMessage: String {
        let names = actionReview?.items.prefix(5).map { $0.url.lastPathComponent }.joined(separator: "\n") ?? ""
        let count = actionReview?.items.count ?? 0
        let extra = max(0, count - 5)
        let suffix = extra > 0 ? (french ? "\n… et \(extra) autres" : "\n… and \(extra) more") : ""
        return french ? "\(count) copies sélectionnées :\n\(names)\(suffix)\nCopies gardées exclues. Aucun effacement définitif." : "\(count) copies selected:\n\(names)\(suffix)\nSuggested keepers excluded. No permanent deletion."
    }

    private func releaseActionScope() {
        if actionScopeHeld, let actionScopedRoot { actionScopedRoot.stopAccessingSecurityScopedResource() }
        actionScopeHeld = false
        actionScopedRoot = nil
    }

    private func copy(_ key: String, count: Int? = nil) -> String {
        if key == "duplicates.count", let count { return french ? "\(count) groupes de doublons exacts" : "\(count) exact duplicate groups" }
        return ProductCopy.value(for: key, french: french)
    }

    private func previewLabel(for url: URL) -> String {
        french ? "Aperçu de \(url.lastPathComponent)" : "Preview \(url.lastPathComponent)"
    }

    private func imagePreview(_ url: URL) -> some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").resizable().scaledToFit().padding(18).foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(url.lastPathComponent)
    }
}
