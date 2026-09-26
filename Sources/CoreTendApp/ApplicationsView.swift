import SwiftUI
import UniformTypeIdentifiers
import Domain
import AppShell
import ScanCore
import SafetyCore

struct ApplicationsView: View {
    let french: Bool
    @State private var selectingFolder = false
    @State private var scanning = false
    @State private var records: [ApplicationRecord] = []
    @State private var issues: [ApplicationDiscoveryIssue] = []
    @State private var status: String?
    @State private var task: Task<Void, Never>?
    @State private var selectingAssociationFolder = false
    @State private var associationApp: ApplicationRecord?
    @State private var associationResults: [URL] = []
    @State private var associationStatus: String?
    @State private var selectedRoot: URL?
    @State private var removalApp: ApplicationRecord?
    @State private var removalReview: ActionReview?
    @State private var removalDialogPresented = false
    @State private var removalService: FileActionService?
    @State private var removalBusy = false
    @State private var removalScopeHeld = false
    @State private var removalScopedRoot: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { selectingFolder = true } label: {
                Label(copy("apps.choose"), systemImage: "folder.badge.plus")
            }
            .disabled(scanning || removalBusy || removalReview != nil)
            .accessibilityHint(copy("apps.choose.hint"))
            Text(copy("apps.limits")).font(.callout).foregroundStyle(.secondary)
            if scanning { ProgressView(copy("scan.progress")) }
            if let status { Text(status).foregroundStyle(.secondary) }
            if !records.isEmpty {
                Text(copy("apps.count", count: records.count)).font(.headline)
                List(records) { app in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "app.dashed")
                            Text(app.displayName).font(.headline)
                            Spacer()
                            Text(app.version ?? copy("metrics.unknown")).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(app.bundleIdentifier).font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text(app.url.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                        Button(french ? "Rechercher des fichiers associés…" : "Review associated files…") {
                            associationApp = app
                            associationResults = []
                            associationStatus = nil
                            selectingAssociationFolder = true
                        }
                        .disabled(scanning || removalBusy || removalReview != nil)
                        .accessibilityHint(french ? "Choisir un dossier à analyser. Aucun fichier ne sera modifié." : "Choose a folder to scan. No files will be changed.")
                        Button(role: .destructive) { Task { await prepareRemoval(app) } } label: {
                            Label(french ? "Déplacer cette app vers la Corbeille…" : "Move this app to Trash…", systemImage: "trash")
                        }
                        .disabled(scanning || removalBusy || removalReview != nil)
                        .accessibilityHint(french ? "Seul le bundle de cette app sera proposé, après revue et confirmation." : "Only this app bundle will be proposed, after review and confirmation.")
                    }
                }
                .frame(minHeight: 260)
            } else if !scanning && status == nil {
                ContentUnavailableView(copy("apps.empty"), systemImage: "app.dashed")
            }
            if !issues.isEmpty { Text(copy("apps.partial", count: issues.count)).font(.caption).foregroundStyle(.secondary) }
            if let app = associationApp {
                GroupBox(french ? "Candidats possibles — \(app.displayName)" : "Possible candidates — \(app.displayName)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(french ? "Correspondance de nom seulement; appartenance non prouvée. Vérifiez avant toute action." : "Name match only; ownership is unverified. Inspect before taking any action.")
                            .font(.caption).foregroundStyle(.secondary)
                        if let associationStatus { Text(associationStatus).foregroundStyle(.secondary) }
                        ForEach(associationResults, id: \.path) { url in Text(url.path).font(.caption.monospaced()).textSelection(.enabled) }
                        if associationResults.isEmpty && associationStatus == nil { Text(french ? "Aucun candidat trouvé." : "No candidates found.").foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .fileImporter(isPresented: $selectingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let root = urls.first else { return }
            discover(root)
        }
        .fileImporter(isPresented: $selectingAssociationFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let root = urls.first, let app = associationApp else { return }
            reviewAssociations(for: app, in: root)
        }
        .onDisappear { task?.cancel(); scanning = false; if removalReview != nil { cancelRemoval() } }
        .confirmationDialog(french ? "Déplacer l’app vers la Corbeille macOS ?" : "Move app to macOS Trash?",
                            isPresented: $removalDialogPresented, titleVisibility: .visible) {
            Button(french ? "Déplacer le bundle" : "Move app bundle", role: .destructive) { beginRemoval() }
            Button(copy("common.cancel"), role: .cancel) { cancelRemoval() }
        } message: {
            Text(removalMessage)
        }
        .onChange(of: removalDialogPresented) { _, presented in
            if !presented && removalReview != nil { cancelRemoval() }
        }
    }

    @MainActor private func prepareRemoval(_ app: ApplicationRecord) async {
        guard let root = selectedRoot, records.contains(app), !removalBusy else { return }
        removalBusy = true
        defer { removalBusy = false }
        do {
            removalScopeHeld = root.startAccessingSecurityScopedResource()
            removalScopedRoot = root
            let store = try await LocalStoreAccess.open()
            let rule = "apps.uninstall"
            let allowed = Set([rule])
            let executor = SafeActionExecutor(allowedRoots: [root], allowedRules: allowed, trash: MacOSTrashClient())
            let service = FileActionService(validator: .init(), executor: executor, store: store,
                                            allowedRoots: [root], allowedRuleIDs: allowed)
            let review = try service.prepareReview([FileActionSelection(url: app.url, ruleID: rule, expectedIdentity: app.fileIdentity)])
            guard await service.recordProposal(review) else {
                status = french ? "Journal indisponible; déplacement bloqué." : "History unavailable; move blocked."
                releaseRemovalScope()
                return
            }
            removalApp = app
            removalReview = review
            removalService = service
            removalDialogPresented = true
        } catch {
            status = french ? "Revue impossible; app inchangée." : "Review failed; app unchanged."
            releaseRemovalScope()
        }
    }

    private var removalMessage: String {
        guard let app = removalApp else { return "" }
        return french
            ? "\(app.displayName)\n\(app.bundleIdentifier)\n\(app.url.path)\nSeul ce bundle ira dans la Corbeille. Les données associées et héritées restent en place."
            : "\(app.displayName)\n\(app.bundleIdentifier)\n\(app.url.path)\nOnly this bundle goes to Trash. Associated and legacy data stay in place."
    }

    private func beginRemoval() {
        guard let review = removalReview, let service = removalService, let app = removalApp else { return }
        removalBusy = true
        removalDialogPresented = false
        removalReview = nil; removalService = nil; removalApp = nil
        Task { await executeRemoval(review, service, app) }
    }

    @MainActor private func executeRemoval(_ review: ActionReview, _ service: FileActionService, _ app: ApplicationRecord) async {
        defer { removalBusy = false; releaseRemovalScope() }
        do {
            let batch = try service.confirm(review, accepted: true)
            let result = await service.execute(batch)
            if result.movedCount == 1 {
                records.removeAll { $0.id == app.id }
                if associationApp?.id == app.id { associationApp = nil; associationResults = [] }
                status = french ? "Bundle déplacé vers la Corbeille; données associées inchangées." : "App bundle moved to Trash; associated data unchanged."
            } else {
                status = french ? "Déplacement échoué; vérifiez l’historique. Bundle non confirmé dans la Corbeille." : "Move failed; check history. Bundle not confirmed in Trash."
            }
        } catch {
            status = french ? "Déplacement refusé; app inchangée." : "Move refused; app unchanged."
        }
    }

    private func cancelRemoval() {
        guard let review = removalReview, let service = removalService else { return }
        removalBusy = true
        removalDialogPresented = false
        removalReview = nil; removalService = nil; removalApp = nil
        Task { @MainActor in
            let recorded = await service.recordCancellation(review)
            status = recorded ? (french ? "Action annulée et journalisée." : "Action cancelled and recorded.")
                              : (french ? "Action annulée; journal indisponible." : "Action cancelled; history unavailable.")
            releaseRemovalScope()
            removalBusy = false
        }
    }

    private func releaseRemovalScope() {
        if removalScopeHeld, let removalScopedRoot { removalScopedRoot.stopAccessingSecurityScopedResource() }
        removalScopeHeld = false
        removalScopedRoot = nil
    }

    private func reviewAssociations(for app: ApplicationRecord, in root: URL) {
        task?.cancel()
        associationResults = []
        associationStatus = french ? "Analyse du dossier choisi…" : "Scanning chosen folder…"
        scanning = true
        let acquiredScope = root.startAccessingSecurityScopedResource()
        task = Task {
            defer {
                if acquiredScope { root.stopAccessingSecurityScopedResource() }
                if !Task.isCancelled { scanning = false }
            }
            do {
                var matches: [URL] = []
                let request = ScanRequest(roots: [.init(url: root, ruleID: .explore)])
                for try await event in LocalScanEngine().scan(request) {
                    try Task.checkCancellation()
                    if case .result(let item) = event {
                        if ApplicationAssociationMatcher.matches(item.url, bundleIdentifier: app.bundleIdentifier) {
                            matches.append(item.url)
                        }
                    }
                }
                try Task.checkCancellation()
                associationResults = matches.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                associationStatus = matches.isEmpty
                    ? (french ? "Aucun nom correspondant dans le dossier choisi." : "No matching names in chosen folder.")
                    : (french ? "\(matches.count) candidats de nom; aucune attribution confirmée." : "\(matches.count) name candidates; none confirmed as app-owned.")
            } catch is CancellationError {
                if !Task.isCancelled { associationStatus = french ? "Analyse annulée." : "Scan cancelled." }
            } catch {
                if !Task.isCancelled { associationStatus = french ? "Analyse impossible." : "Scan failed." }
            }
        }
    }

    private func discover(_ root: URL) {
        task?.cancel()
        selectedRoot = root
        records = []; issues = []; status = nil; scanning = true
        associationApp = nil; associationResults = []; associationStatus = nil
        let acquiredScope = root.startAccessingSecurityScopedResource()
        task = Task {
            defer {
                if acquiredScope { root.stopAccessingSecurityScopedResource() }
                if !Task.isCancelled { scanning = false }
            }
            let service = ApplicationDiscoveryService()
            let report = await Task.detached(priority: .utility) { service.discover(in: root) }.value
            guard !Task.isCancelled else { return }
            records = report.applications
            issues = report.issues
            if report.applications.isEmpty && report.issues.isEmpty { status = copy("apps.empty") }
            else if report.applications.isEmpty { status = copy("apps.failed") }
        }
    }

    private func copy(_ key: String, count: Int? = nil) -> String {
        if key == "apps.count", let count { return french ? "\(count) applications locales" : "\(count) local applications" }
        if key == "apps.partial", let count { return french ? "\(count) éléments ignorés" : "\(count) items skipped" }
        return ProductCopy.value(for: key, french: french)
    }
}
