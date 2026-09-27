import DesignSystem
import SwiftUI
import AppKit
import QuickLook
import UniformTypeIdentifiers
import ScanCore
import AppShell
import SafetyCore
import Domain

struct DuplicateScanView: View {
    let french: Bool
    @State private var selectingFolder = false
    @State private var scanning = false
    @State private var scanCompletedFiles = 0
    @State private var analysisProgress: DuplicateScanProgress?
    @State private var report: DuplicateScanReport?
    @State private var status: String?
    @State private var scanTask: Task<Void, Never>?
    @State private var activeScanID: UUID?
    @State private var selectedRoot: URL?
    @State private var selectedCopies: Set<URL> = []
    @State private var actionReview: ActionReview?
    @State private var actionDialogPresented = false
    @State private var actionService: FileActionService?
    @State private var actionBusy = false
    @State private var actionScopeHeld = false
    @State private var actionScopedRoot: URL?
    @State private var similarMode = false
    @State private var similarReport: SimilarImageReport?
    @State private var previewURL: URL?
    @State private var previewScopeHeld = false
    @State private var previewScopedRoot: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(french ? "Comparer sans décider à votre place" : "Compare files without deciding for you")
                    .font(.title3.weight(.semibold))
                Text(french ? "Les choix de conservation et de déplacement restent manuels. Aucun fichier n’est présélectionné." : "Keep and move choices stay manual. No file is preselected.")
                    .font(.callout).foregroundStyle(Palette.secondaryInk.color)
            Picker(french ? "Analyse" : "Analysis", selection: $similarMode) {
                Text(french ? "Doublons exacts" : "Exact duplicates").tag(false)
                Text(french ? "Images similaires" : "Similar images").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(scanning || actionBusy || actionReview != nil)
            Text(similarMode
                 ? (french ? "Candidats heuristiques : proximité visuelle possible, égalité exacte non établie." : "Heuristic candidates: visual similarity may exist; exact equality is not established.")
                 : (french ? "Groupes exacts : contenu identique détecté. Choisissez manuellement les copies à examiner." : "Exact groups: identical content detected. Manually choose copies to review."))
                .font(.caption).foregroundStyle(Palette.secondaryInk.color)
            }
            .padding(14)
            .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 14))
            Button { selectingFolder = true } label: {
                Label(copy("duplicates.choose"), systemImage: similarMode ? "photo.on.rectangle.angled" : "doc.on.doc")
            }
            .disabled(scanning || actionBusy || actionReview != nil)
            .accessibilityHint(copy("duplicates.choose.hint"))
            if let selectedRoot {
                Label(selectedRoot.path, systemImage: "folder.fill")
                    .font(.caption.monospaced()).foregroundStyle(Palette.accent.color).textSelection(.enabled)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityElement(children: .combine)
            }
            if scanning {
                HStack(spacing: 14) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(progressTitle).font(.headline)
                        Text(progressDetail).font(.caption).foregroundStyle(Palette.secondaryInk.color)
                    }
                    Spacer()
                    Button(copy("scan.cancel")) { cancelScan() }
                }
                .padding(14).background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
                .motion(.standard, value: scanning)
            }
            if let status {
                Label(status, systemImage: "info.circle")
                    .foregroundStyle(Palette.secondaryInk.color)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 10))
            }
            if similarMode, let similarReport {
                if similarReport.candidates.isEmpty {
                    ContentUnavailableView(french ? "Aucune paire similaire détectée" : "No similar image pairs found", systemImage: "photo.on.rectangle.angled")
                } else {
                    Text(french ? "\(similarReport.candidates.count) paires candidates" : "\(similarReport.candidates.count) candidate pairs").font(.headline)
                    Text(french ? "Comparaison visuelle heuristique. Vérifiez chaque image; aucune suppression proposée." : "Heuristic visual matching. Review every image; no deletion action offered.").foregroundStyle(Palette.secondaryInk.color)
                    List(similarReport.candidates, id: \.id) { pair in
                        HStack(alignment: .top, spacing: 12) {
                            Button { showPreview(pair.first) } label: { imagePreview(pair.first) }
                                .buttonStyle(.serre(.tile))
                                .accessibilityLabel(previewLabel(for: pair.first))
                                .accessibilityHint(french ? "Ouvre l’aperçu Quick Look." : "Opens the Quick Look preview.")
                            Button { showPreview(pair.second) } label: { imagePreview(pair.second) }
                                .buttonStyle(.serre(.tile))
                                .accessibilityLabel(previewLabel(for: pair.second))
                                .accessibilityHint(french ? "Ouvre l’aperçu Quick Look." : "Opens the Quick Look preview.")
                            VStack(alignment: .leading) {
                                Text(pair.first.lastPathComponent).font(.headline)
                                Text(pair.second.lastPathComponent)
                            Text(french ? "Écart perceptuel : \(pair.differingBits)/64" : "Perceptual distance: \(pair.differingBits)/64").font(.caption).foregroundStyle(Palette.secondaryInk.color)
                            }
                        }
                        .padding(10)
                        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                if similarReport.skippedCount > 0 { Text(french ? "\(similarReport.skippedCount) fichiers ignorés (format ou limite)." : "\(similarReport.skippedCount) files skipped (format or limit).") .foregroundStyle(Palette.secondaryInk.color) }
            }
            if !similarMode, let report {
                if report.groups.isEmpty {
                    ContentUnavailableView(copy("duplicates.none"), systemImage: "doc.on.doc")
                } else {
                    Text(copy("duplicates.count", count: report.groups.count)).font(.title3.weight(.semibold))
                    List(report.groups, id: \.digest) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(french ? "Suggestion de conservation — à vérifier" : "Suggested keeper — review before deciding", systemImage: "checkmark.circle")
                                .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent.color)
                            Text(group.suggestedKeeper.lastPathComponent).font(.headline)
                            Button { showPreview(group.suggestedKeeper) } label: {
                                Label(copy("explore.preview"), systemImage: "eye")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(previewLabel(for: group.suggestedKeeper))
                            .accessibilityHint(french ? "Ouvre l’aperçu Quick Look du fichier à conserver." : "Opens Quick Look for the suggested file to keep.")
                            ForEach(group.files.filter { $0 != group.suggestedKeeper }, id: \.path) { file in
                                HStack {
                                    Toggle(isOn: Binding(get: { selectedCopies.contains(file) }, set: { enabled in
                                        guard !scanning && !actionBusy && actionReview == nil else { return }
                                        if enabled { selectedCopies.insert(file) } else { selectedCopies.remove(file) }
                                    })) {
                                        Label(file.lastPathComponent, systemImage: "doc.on.doc")
                                    }
                                    Button { showPreview(file) } label: {
                                        Label(copy("explore.preview"), systemImage: "eye")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(previewLabel(for: file))
                                    .accessibilityHint(french ? "Ouvre l’aperçu Quick Look de cette copie." : "Opens Quick Look for this copy.")
                                }
                                .disabled(actionBusy || actionReview != nil)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    Text(french ? "Cochez uniquement les copies que vous avez vérifiées. Elles ne seront déplacées qu’après revue et confirmation." : "Check only copies you have reviewed. They move only after review and confirmation.")
                        .font(.caption).foregroundStyle(Palette.secondaryInk.color)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 10))
                    Button { Task { await prepareAction() } } label: {
                        Label(french ? "Examiner \(selectedCopies.count) copies" : "Review \(selectedCopies.count) copies", systemImage: "trash")
                    }
                    .disabled(selectedCopies.isEmpty || scanning || actionBusy || actionReview != nil)
                    .accessibilityHint(french ? "Les copies choisies seront revérifiées avant déplacement vers la Corbeille." : "Chosen copies are revalidated before moving to Trash.")
                }
                if !report.issues.isEmpty {
                    Label(copy("scan.partial"), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Palette.caution.color)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            if actionBusy { ProgressView() }
        }
        .fileImporter(isPresented: $selectingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let root = urls.first else {
                status = copy("scan.failed"); return
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

    private func beginScan(_ root: URL) {
        scanTask?.cancel()
        previewURL = nil
        let scanID = UUID()
        activeScanID = scanID
        let hasScope = root.startAccessingSecurityScopedResource()
        scanning = true
        scanCompletedFiles = 0
        analysisProgress = nil
        status = nil
        report = nil
        similarReport = nil
        selectedCopies = []
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
                    status = ProductCopy.scanRootFailure(reason: rootFailure, french: french)
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
                if !partialFailures.isEmpty { status = ProductCopy.scanPartialFailure(reasons: partialFailures, french: french) }
            } catch is CancellationError {
                if activeScanID == scanID { status = copy("scan.cancelled") }
            } catch {
                if activeScanID == scanID { status = copy("scan.failed") }
            }
        }
    }

    private func cancelScan() {
        scanTask?.cancel()
        activeScanID = nil
        scanning = false
        scanCompletedFiles = 0
        analysisProgress = nil
        status = copy("scan.cancelled")
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
            status = copy("preview.unavailable")
            return
        }
        if previewScopeHeld, previewScopedRoot != selectedRoot { releasePreviewScope() }
        let alreadyScopedToRoot = previewScopeHeld && previewScopedRoot == selectedRoot
        let acquiredScope = alreadyScopedToRoot ? false : selectedRoot.startAccessingSecurityScopedResource()
        guard QuickLookCandidate.isAllowed(url, within: selectedRoot) else {
            if acquiredScope { selectedRoot.stopAccessingSecurityScopedResource() }
            status = copy("preview.unavailable")
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
            let protectedKeepers = exactReport.groups.compactMap { group in
                group.files.contains(where: selectedCopies.contains) ? group.suggestedKeeper : nil
            }
            let review = try service.prepareReview(selections, protectedKeepers: protectedKeepers)
            guard await service.recordProposal(review) else {
                status = french ? "Journal indisponible; action bloquée." : "History unavailable; action blocked."
                return
            }
            actionReview = review
            actionService = service
            actionDialogPresented = true
        } catch { status = french ? "Revue impossible; aucune copie déplacée." : "Review failed; no copies moved." }
    }

    private func beginExecution() {
        guard let review = actionReview, let service = actionService else { return }
        actionBusy = true
        actionDialogPresented = false
        actionReview = nil; actionService = nil
        Task { await executeAction(review, service) }
    }

    @MainActor private func executeAction(_ review: ActionReview, _ service: FileActionService) async {
        defer { actionBusy = false; releaseActionScope() }
        do {
            let batch = try service.confirm(review, accepted: true)
            let report = await service.execute(batch)
            let failed = report.items.filter { if case .movedToTrash = $0.outcome { false } else { true } }.count
            status = french ? "\(report.movedCount) déplacées vers la Corbeille; \(failed) échec(s)." : "\(report.movedCount) copies moved to Trash; \(failed) failure(s)."
            selectedCopies = []
            self.report = nil
        } catch { status = french ? "Action refusée; aucune copie déplacée." : "Action refused; no copies moved." }
    }

    private func cancelAction() {
        guard let review = actionReview, let service = actionService else { return }
        actionBusy = true
        actionDialogPresented = false
        actionReview = nil; actionService = nil
        Task { @MainActor in
            let saved = await service.recordCancellation(review)
            status = saved ? (french ? "Action annulée; annulation journalisée." : "Action cancelled; cancellation recorded.") : (french ? "Action annulée; journal indisponible." : "Action history unavailable.")
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
