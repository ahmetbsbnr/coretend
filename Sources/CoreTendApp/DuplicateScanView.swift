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
        VStack(alignment: .leading, spacing: 16) {
            Picker(french ? "Analyse" : "Analysis", selection: $similarMode) {
                Text(french ? "Doublons exacts" : "Exact duplicates").tag(false)
                Text(french ? "Images similaires" : "Similar images").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(scanning || actionBusy || actionReview != nil)
            Button { selectingFolder = true } label: {
                Label(copy("duplicates.choose"), systemImage: similarMode ? "photo.on.rectangle.angled" : "doc.on.doc")
            }
            .disabled(scanning || actionBusy || actionReview != nil)
            .accessibilityHint(copy("duplicates.choose.hint"))
            if scanning {
                ProgressView(copy("scan.progress"))
                Button(copy("scan.cancel")) { cancelScan() }
            }
            if let status { Text(status).foregroundStyle(.secondary) }
            if similarMode, let similarReport {
                if similarReport.candidates.isEmpty {
                    ContentUnavailableView(french ? "Aucune paire similaire détectée" : "No similar image pairs found", systemImage: "photo.on.rectangle.angled")
                } else {
                    Text(french ? "\(similarReport.candidates.count) paires candidates" : "\(similarReport.candidates.count) candidate pairs").font(.headline)
                    Text(french ? "Comparaison visuelle heuristique. Vérifiez chaque image; aucune suppression proposée." : "Heuristic visual matching. Review every image; no deletion action offered.").foregroundStyle(.secondary)
                    List(similarReport.candidates, id: \.id) { pair in
                        HStack(alignment: .top, spacing: 12) {
                            Button { previewURL = pair.first } label: { imagePreview(pair.first) }
                                .buttonStyle(.plain)
                            Button { previewURL = pair.second } label: { imagePreview(pair.second) }
                                .buttonStyle(.plain)
                            VStack(alignment: .leading) {
                                Text(pair.first.lastPathComponent).font(.headline)
                                Text(pair.second.lastPathComponent)
                            Text(french ? "Écart perceptuel : \(pair.differingBits)/64" : "Perceptual distance: \(pair.differingBits)/64").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if similarReport.skippedCount > 0 { Text(french ? "\(similarReport.skippedCount) fichiers ignorés (format ou limite)." : "\(similarReport.skippedCount) files skipped (format or limit).") .foregroundStyle(.secondary) }
            }
            if !similarMode, let report {
                if report.groups.isEmpty {
                    ContentUnavailableView(copy("duplicates.none"), systemImage: "doc.on.doc")
                } else {
                    Text(copy("duplicates.count", count: report.groups.count)).font(.headline)
                    List(report.groups, id: \.digest) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(copy("duplicates.keep"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(group.suggestedKeeper.lastPathComponent).font(.headline)
                            Button { previewURL = group.suggestedKeeper } label: {
                                Label(copy("explore.preview"), systemImage: "eye")
                            }
                            .buttonStyle(.borderless)
                            ForEach(group.files.filter { $0 != group.suggestedKeeper }, id: \.path) { file in
                                HStack {
                                    Toggle(isOn: Binding(get: { selectedCopies.contains(file) }, set: { enabled in
                                        if enabled { selectedCopies.insert(file) } else { selectedCopies.remove(file) }
                                    })) {
                                        Label(file.lastPathComponent, systemImage: "doc.on.doc")
                                    }
                                    Button { previewURL = file } label: {
                                        Label(copy("explore.preview"), systemImage: "eye")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .disabled(actionBusy || actionReview != nil)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    Button { Task { await prepareAction() } } label: {
                        Label(french ? "Examiner \(selectedCopies.count) copies" : "Review \(selectedCopies.count) copies", systemImage: "trash")
                    }
                    .disabled(selectedCopies.isEmpty || scanning || actionBusy || actionReview != nil)
                }
                if !report.issues.isEmpty { Text(copy("scan.partial")).foregroundStyle(.secondary) }
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
            else if !previewScopeHeld, let selectedRoot {
                previewScopeHeld = selectedRoot.startAccessingSecurityScopedResource()
                if previewScopeHeld { previewScopedRoot = selectedRoot }
            }
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
        status = nil
        report = nil
        similarReport = nil
        selectedCopies = []
        scanTask = Task {
            var rootFailure: String?
            var partialFailure = false
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
                        if path == root.path { rootFailure = reason } else { partialFailure = true }
                    case .progress, .finished: break
                    }
                }
                try Task.checkCancellation()
                guard activeScanID == scanID else { return }
                if let rootFailure {
                    status = ProductCopy.scanRootFailure(reason: rootFailure, french: french)
                    return
                }
                if similarMode {
                    let result = try await SimilarImageEngine().findSimilar(in: candidates.map(\.url))
                    try Task.checkCancellation()
                    guard activeScanID == scanID else { return }
                    similarReport = result
                } else {
                    let result = try await DuplicateEngine().findGroups(in: candidates)
                    try Task.checkCancellation()
                    guard activeScanID == scanID else { return }
                    report = result
                }
                if partialFailure { status = copy("scan.partial") }
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
        status = copy("scan.cancelled")
    }

    private func releasePreviewScope() {
        if previewScopeHeld, let previewScopedRoot { previewScopedRoot.stopAccessingSecurityScopedResource() }
        previewScopeHeld = false
        previewScopedRoot = nil
    }

    @MainActor private func prepareAction() async {
        guard let root = selectedRoot, !selectedCopies.isEmpty, !scanning, !actionBusy, actionReview == nil else { return }
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
            let review = try service.prepareReview(selections)
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
