import SwiftUI
import UniformTypeIdentifiers
import ScanCore
import AppShell
import SafetyCore
import Domain

struct CleanupView: View {
    let french: Bool
    @State private var selectedRule: ScanRule?
    @State private var selectedRoot: URL?
    @State private var choosingFolder = false
    @State private var results: [ScanResult] = []
    @State private var status: String?
    @State private var scanning = false
    @State private var task: Task<Void, Never>?
    @State private var activeScanID: UUID?
    @State private var selectedItems: Set<URL> = []
    @State private var actionReview: ActionReview?
    @State private var actionDialogPresented = false
    @State private var actionService: FileActionService?
    @State private var actionBusy = false
    @State private var actionScopeHeld = false
    @State private var actionScopedRoot: URL?

    private var descriptor: CleanupRuleDescriptor? {
        selectedRule.flatMap(CleanupRuleCatalog.rule)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(copy("cleanup.intro")).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(CleanupRuleCatalog.rules, id: \.id) { rule in
                    Button { selectedRule = rule.id; selectedRoot = nil; results = []; selectedItems = []; status = nil } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedRule == rule.id ? "largecircle.fill.circle" : "circle")
                            VStack(alignment: .leading, spacing: 3) {
                                Text(copy(rule.titleKey)).font(.headline)
                                Text(copy(rule.explanationKey)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(riskLabel(rule.risk)).font(.caption.weight(.semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(scanning || actionBusy || actionReview != nil)
                    .accessibilityAddTraits(selectedRule == rule.id ? .isSelected : [])
                }
            }
            if let descriptor {
                Text("~/" + descriptor.relativePath.joined(separator: "/"))
                    .font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                Button { choosingFolder = true } label: {
                    Label(copy("cleanup.choose"), systemImage: "folder.badge.plus")
                }
                .disabled(scanning || actionBusy || actionReview != nil)
                .accessibilityHint(copy("cleanup.choose.hint"))
                if let selectedRoot {
                    Text(selectedRoot.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                    Button { startScan(descriptor, root: selectedRoot) } label: {
                        Label(copy("cleanup.scan"), systemImage: "magnifyingglass")
                    }
                    .disabled(scanning || actionBusy || actionReview != nil)
                    .accessibilityHint(copy("cleanup.scan.hint"))
                }
            }
            if scanning {
                ProgressView(copy("scan.progress"))
                Button(copy("scan.cancel")) { cancelScan() }
            }
            if !results.isEmpty {
                Text(copy("cleanup.results", count: results.count)).font(.headline)
                List(results, id: \.url) { item in
                    Toggle(isOn: Binding(get: { selectedItems.contains(item.url) }, set: { enabled in
                        if enabled { selectedItems.insert(item.url) } else { selectedItems.remove(item.url) }
                    })) {
                        HStack {
                            Image(systemName: "doc")
                            Text(item.url.lastPathComponent).lineLimit(1)
                            Spacer()
                            Text(size(item)).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    .disabled(scanning || actionBusy || actionReview != nil)
                }
                .frame(minHeight: 220)
                Button { Task { await prepareAction() } } label: {
                    Label(french ? "Examiner \(selectedItems.count) éléments" : "Review \(selectedItems.count) items", systemImage: "trash")
                }
                .disabled(selectedItems.isEmpty || scanning || actionBusy || actionReview != nil || selectedRoot == nil)
            }
            if actionBusy { ProgressView() }
            if let status { Text(status).foregroundStyle(.secondary) }
            Text(copy("cleanup.noAction")).font(.callout).foregroundStyle(.secondary)
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { outcome in
            guard case .success(let urls) = outcome else { return }
            guard let url = urls.first, let descriptor,
                  Array(url.standardizedFileURL.pathComponents.suffix(descriptor.relativePath.count)) == descriptor.relativePath else {
                selectedRoot = nil
                status = copy("cleanup.rootMismatch")
                return
            }
            selectedRoot = url
            status = nil
        }
        .onDisappear { task?.cancel(); activeScanID = nil; scanning = false; if actionReview != nil { cancelAction() } }
        .confirmationDialog(french ? "Déplacer vers la Corbeille macOS ?" : "Move to macOS Trash?", isPresented: $actionDialogPresented, titleVisibility: .visible) {
            Button(french ? "Déplacer vers la Corbeille" : "Move to Trash", role: .destructive) { beginExecution() }
            Button(copy("common.cancel"), role: .cancel) { cancelAction() }
        } message: {
            Text(reviewMessage)
        }
        .onChange(of: actionDialogPresented) { _, presented in
            if !presented && actionReview != nil { cancelAction() }
        }
    }

    private func startScan(_ rule: CleanupRuleDescriptor, root: URL) {
        task?.cancel()
        let scanID = UUID()
        activeScanID = scanID
        results = []; selectedItems = []; status = nil; scanning = true
        let acquiredScope = root.startAccessingSecurityScopedResource()
        task = Task {
            var rootUnavailable = false
            var partialFailure = false
            defer {
                if acquiredScope { root.stopAccessingSecurityScopedResource() }
                if activeScanID == scanID { scanning = false; activeScanID = nil }
            }
            do {
                let exclusions = try await LocalStoreAccess.exclusions()
                for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: rule.id)], exclusions: exclusions)) {
                    guard !Task.isCancelled, activeScanID == scanID else { return }
                    switch event {
                    case .result(let result): results.append(result)
                    case .itemFailure(let path, _):
                        if path == root.path { rootUnavailable = true } else { partialFailure = true }
                    case .finished:
                        status = rootUnavailable ? copy("scan.accessDenied")
                            : partialFailure ? copy("cleanup.partial")
                            : results.isEmpty ? copy("cleanup.none") : nil
                    case .progress: break
                    }
                }
            } catch is CancellationError {
                if activeScanID == scanID { status = copy("scan.cancelled") }
            } catch {
                if activeScanID == scanID { status = copy("scan.failed") }
            }
        }
    }

    private func cancelScan() {
        task?.cancel()
        activeScanID = nil
        scanning = false
        results = []
        selectedItems = []
        status = copy("scan.cancelled")
    }

    @MainActor private func prepareAction() async {
        guard let root = selectedRoot, let rule = descriptor, !selectedItems.isEmpty, !scanning, !actionBusy, actionReview == nil else { return }
        actionBusy = true
        defer { actionBusy = false; if actionReview == nil { releaseActionScope() } }
        do {
            actionScopeHeld = root.startAccessingSecurityScopedResource()
            actionScopedRoot = root
            let store = try await LocalStoreAccess.open()
            let ruleID = rule.id.rawValue
            let allowed = Set([ruleID])
            let executor = SafeActionExecutor(allowedRoots: [root], allowedRules: allowed, trash: MacOSTrashClient())
            let service = FileActionService(validator: .init(), executor: executor, store: store, allowedRoots: [root], allowedRuleIDs: allowed)
            let selections = selectedItems.sorted { $0.path < $1.path }.map { FileActionSelection(url: $0, ruleID: ruleID) }
            let review = try service.prepareReview(selections)
            guard await service.recordProposal(review) else {
                status = french ? "Journal indisponible; action bloquée." : "History unavailable; action blocked."
                return
            }
            actionReview = review
            actionService = service
            actionDialogPresented = true
        } catch { status = french ? "Revue impossible; aucun fichier déplacé." : "Review failed; no files moved." }
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
            status = french ? "\(report.movedCount) déplacés vers la Corbeille; \(failed) échec(s)." : "\(report.movedCount) moved to Trash; \(failed) failure(s)."
            selectedItems = []; results.removeAll()
        } catch { status = french ? "Action refusée; aucun fichier déplacé." : "Action refused; no files moved." }
    }

    private func cancelAction() {
        guard let review = actionReview, let service = actionService else { return }
        actionBusy = true
        actionDialogPresented = false
        actionReview = nil; actionService = nil
        Task { @MainActor in
            let saved = await service.recordCancellation(review)
            status = saved ? (french ? "Action annulée; annulation journalisée." : "Action cancelled; cancellation recorded.") : (french ? "Action annulée; journal indisponible." : "Action cancelled; history unavailable.")
            releaseActionScope()
            actionBusy = false
        }
    }

    private var reviewMessage: String {
        let names = actionReview?.items.prefix(5).map { $0.url.lastPathComponent }.joined(separator: "\n") ?? ""
        let count = actionReview?.items.count ?? 0
        let extra = max(0, count - 5)
        let suffix = extra > 0 ? (french ? "\n… et \(extra) autres" : "\n… and \(extra) more") : ""
        return french ? "\(count) éléments sélectionnés :\n\(names)\(suffix)\nAction journalisée puis revalidée. Aucun effacement définitif." : "\(count) selected items:\n\(names)\(suffix)\nAction is logged and revalidated. No permanent deletion."
    }

    private func releaseActionScope() {
        if actionScopeHeld, let actionScopedRoot { actionScopedRoot.stopAccessingSecurityScopedResource() }
        actionScopeHeld = false
        actionScopedRoot = nil
    }

    private func riskLabel(_ risk: CandidateRisk) -> String {
        switch risk {
        case .low: copy("cleanup.risk.low")
        case .medium: copy("cleanup.risk.medium")
        case .high: copy("cleanup.risk.high")
        }
    }
    private func size(_ result: ScanResult) -> String {
        if case .known(let bytes) = result.allocatedBytes { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
        else { copy("metrics.unknown") }
    }
    private func copy(_ key: String, count: Int? = nil) -> String {
        if key == "cleanup.results", let count { return french ? "\(count) éléments mesurés" : "\(count) measured items" }
        return ProductCopy.value(for: key, french: french)
    }
}
