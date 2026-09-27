import SwiftUI
import UniformTypeIdentifiers
import Domain
import AppShell
import ScanCore
import SafetyCore
import DesignSystem

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
    @State private var searchText = ""

    private var visibleRecords: [ApplicationRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return records }
        return records.filter {
            $0.displayName.localizedStandardContains(query)
                || $0.bundleIdentifier.localizedStandardContains(query)
                || $0.url.path.localizedStandardContains(query)
                || ($0.version?.localizedStandardContains(query) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ObservatoryCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(french ? "Inventaire local" : "Local inventory")
                                .font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                            Text(copy("apps.limits"))
                                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Button { selectingFolder = true } label: {
                            Label(copy("apps.choose"), systemImage: "folder.badge.plus")
                        }
                        .disabled(scanning || removalBusy || removalReview != nil)
                        .accessibilityHint(copy("apps.choose.hint"))
                    }
                    if let selectedRoot {
                        Label(selectedRoot.path, systemImage: "folder")
                            .font(CoreTendTypography.secondary.monospaced())
                            .foregroundStyle(Palette.secondaryInk.color).textSelection(.enabled)
                    }
                    if scanning { ProgressView(copy("scan.progress")) }
                    if let status {
                        Label(status, systemImage: "info.circle")
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !records.isEmpty {
                        Palette.separator.color.frame(height: 1)
                        HStack {
                            Text(copy("apps.count", count: records.count))
                                .font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                            Spacer()
                            Text(french ? "\(visibleRecords.count) affichées" : "\(visibleRecords.count) shown")
                                .font(CoreTendTypography.secondary.monospacedDigit())
                                .foregroundStyle(Palette.secondaryInk.color)
                        }
                        HStack(spacing: 9) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondaryInk.color)
                            TextField(french ? "Rechercher par nom, identifiant, version ou chemin" : "Search name, identifier, version, or path", text: $searchText)
                                .textFieldStyle(.plain)
                                .accessibilityLabel(french ? "Rechercher dans l’inventaire d’apps" : "Search app inventory")
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                                    .buttonStyle(.plain).accessibilityLabel(french ? "Effacer la recherche" : "Clear search")
                            }
                        }
                        .padding(10)
                        .background(Palette.raisedSurface.color, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.separator.color, lineWidth: 1))
                    }
                }
            }
            if !records.isEmpty {
                if visibleRecords.isEmpty {
                    ContentUnavailableView(french ? "Aucune app correspondante" : "No matching apps",
                                           systemImage: "magnifyingglass",
                                           description: Text(french ? "Essayez un autre nom, identifiant, version ou chemin." : "Try another name, identifier, version, or path."))
                        .frame(maxWidth: .infinity, minHeight: 130)
                }
                LazyVStack(spacing: 12) {
                    ForEach(visibleRecords) { app in applicationCard(app) }
                }
            } else if !scanning && selectedRoot != nil && issues.isEmpty {
                ContentUnavailableView(copy("apps.empty"), systemImage: "app.dashed",
                                       description: Text(french ? "Choisissez un autre dossier pour examiner ses apps au premier niveau." : "Choose another folder to inspect its top-level apps."))
            } else if !scanning && selectedRoot == nil {
                ContentUnavailableView(french ? "Choisissez un dossier d’applications" : "Choose an Applications folder",
                                       systemImage: "app.dashed", description: Text(copy("apps.limits")))
            }
            if !issues.isEmpty {
                ObservatoryCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(copy("apps.partial", count: issues.count), systemImage: "exclamationmark.circle")
                            .font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.caution.color)
                        Text(french ? "Certains dossiers ou bundles n’ont pas pu être entièrement examinés. Leur absence de l’inventaire ne prouve pas qu’ils sont absents du dossier." : "Some folders or bundles could not be fully inspected. Their absence from this inventory does not prove they are absent from the folder.")
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(issueReason(issue.reason)).font(CoreTendTypography.secondary)
                                    .foregroundStyle(Palette.ink.color)
                                Text(issue.path).font(CoreTendTypography.secondary.monospaced())
                                    .foregroundStyle(Palette.secondaryInk.color).textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            if let app = associationApp {
                ObservatoryCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(french ? "Fichiers candidats · \(app.displayName)" : "Candidate files · \(app.displayName)")
                            .font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                        Text(french ? "Correspondance de nom seulement; appartenance non prouvée. Vérifiez avant toute action." : "Name match only; ownership is unverified. Inspect before taking any action.")
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                            .fixedSize(horizontal: false, vertical: true)
                        if let associationStatus { Text(associationStatus).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color) }
                        ForEach(associationResults, id: \.path) { url in Text(url.path).font(CoreTendTypography.secondary.monospaced()).textSelection(.enabled) }
                        if associationResults.isEmpty && associationStatus == nil { Text(french ? "Aucun candidat trouvé." : "No candidates found.").foregroundStyle(Palette.secondaryInk.color) }
                    }
                }
            }
        }
        .motion(.standard, value: records)
        .motion(.quick, value: searchText)
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

    private func applicationCard(_ app: ApplicationRecord) -> some View {
        ObservatoryCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "app.dashed")
                        .font(.title2).foregroundStyle(Palette.accent.color)
                        .frame(width: 38, height: 38)
                        .background(Palette.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.displayName).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                            .textSelection(.enabled)
                        Text(app.bundleIdentifier).font(CoreTendTypography.secondary.monospaced())
                            .foregroundStyle(Palette.secondaryInk.color).textSelection(.enabled)
                    }
                    Spacer(minLength: 4)
                    Text(app.version ?? (french ? "Version inconnue" : "Version unknown"))
                        .font(CoreTendTypography.secondary.monospacedDigit())
                        .foregroundStyle(Palette.secondaryInk.color)
                        .multilineTextAlignment(.trailing)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label(app.url.path, systemImage: "folder")
                        .font(CoreTendTypography.secondary.monospaced())
                        .foregroundStyle(Palette.secondaryInk.color).textSelection(.enabled)
                    updateSourceView(for: app)
                }
                Palette.separator.color.frame(height: 1)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        associationButton(for: app)
                        Spacer(minLength: 8)
                        removalButton(for: app)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        associationButton(for: app)
                        removalButton(for: app)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func associationButton(for app: ApplicationRecord) -> some View {
        Button {
            associationApp = app
            associationResults = []
            associationStatus = nil
            selectingAssociationFolder = true
        } label: {
            Label(french ? "Examiner un dossier associé…" : "Review files in a folder…", systemImage: "doc.text.magnifyingglass")
        }
        .disabled(scanning || removalBusy || removalReview != nil)
        .accessibilityHint(french ? "Choisissez un dossier précis. Aucun fichier ne sera modifié et aucune attribution ne sera déduite." : "Choose a specific folder. No files will be changed and ownership will not be inferred.")
    }

    private func removalButton(for app: ApplicationRecord) -> some View {
        Button(role: .destructive) { Task { await prepareRemoval(app) } } label: {
            Label(french ? "Corbeille…" : "Move to Trash…", systemImage: "trash")
        }
        .disabled(scanning || removalBusy || removalReview != nil)
        .accessibilityHint(french ? "Seul ce bundle sera proposé, après revue, revalidation et confirmation." : "Only this app bundle will be proposed, after review, revalidation, and confirmation.")
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

    @ViewBuilder private func updateSourceView(for app: ApplicationRecord) -> some View {
        switch app.updateSource {
        case .declaredHTTPSFeed(let url):
            Text(french ? "Flux HTTPS déclaré par l’app : \(url.host ?? "hôte inconnu") · version non vérifiée" : "App-declared HTTPS feed: \(url.host ?? "unknown host") · version not checked")
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            Link(french ? "Ouvrir le flux déclaré" : "Open declared feed", destination: url)
                .font(CoreTendTypography.secondary)
                .accessibilityHint(french ? "Ouvre l’adresse HTTPS déclarée par cette app dans le navigateur. CoreTend ne vérifie aucune version." : "Opens this app’s declared HTTPS address in the browser. CoreTend does not compare versions.")
        case .invalidDeclaredFeed:
            Text(french ? "Adresse de mise à jour déclarée inutilisable." : "Declared update address is unusable.")
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
        case .unknown:
            Text(french ? "Source de mise à jour inconnue." : "Update source unknown.")
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
        }
    }

    private func issueReason(_ reason: String) -> String {
        switch reason {
        case "selected_root_unavailable": return french ? "Dossier choisi indisponible." : "Selected folder is unavailable."
        case "selected_root_unreadable": return french ? "Impossible de lire le dossier choisi." : "Could not read the selected folder."
        case "bundle_contents_unavailable": return french ? "Contenu du bundle indisponible." : "Bundle contents are unavailable."
        case "bundle_identifier_missing": return french ? "Identifiant de bundle absent ou invalide." : "Bundle identifier is missing or invalid."
        case "bundle_metadata_unavailable": return french ? "Métadonnées du bundle illisibles, trop volumineuses ou modifiées pendant la lecture." : "Bundle metadata could not be read, exceeded the size limit, or changed while being read."
        default: return french ? "Métadonnées du bundle indisponibles." : "Bundle metadata unavailable."
        }
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

private struct ObservatoryCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.separator.color.opacity(0.75), lineWidth: 1))
    }
}
