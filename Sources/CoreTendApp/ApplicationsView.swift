import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Domain
import AppShell
import ScanCore
import SafetyCore
import DesignSystem

/// Applications, "les plantations": the apps at the top of a chosen folder in planting rows, with
/// their real icon, identifier, version and declared update address; the files around one app
/// (name matches in a folder the person chooses, never claimed as the app's); and a reviewed move
/// of one app bundle to the Trash, where its leaf falls and its associated data stay in place.
struct ApplicationsView: View {
    let french: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectingFolder = false
    /// Folder the system panel opens on when a suggested folder is chosen in the App Sandbox.
    @State private var suggestedDirectory: URL?
    @State private var scanning = false
    @State private var records: [ApplicationRecord] = []
    @State private var issues: [ApplicationDiscoveryIssue] = []
    @State private var notice: PageNotice?
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
    @State private var moving = false
    @State private var removalScopeHeld = false
    @State private var removalScopedRoot: URL?
    @State private var searchText = ""
    @State private var failures: [URL: String] = [:]
    @State private var flight = LeafFlight()
    /// Changes once per inventory, so the rows appear once, one after another.
    @State private var plantingSeed = UUID()
    /// Measured bundle sizes by app, filled in the background after the inventory.
    @State private var sizes: [String: Int64] = [:]
    @State private var sizing = false
    @State private var sortMode = "name"
    /// The app whose row is open with its actions.
    @State private var expanded: String?
    @State private var associationEvidence: [URL: AssociationEvidence] = [:]

    private var locked: Bool { scanning || removalBusy || removalReview != nil }

    private var visibleRecords: [ApplicationRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let found = query.isEmpty ? records : records.filter {
            $0.displayName.localizedStandardContains(query)
                || $0.bundleIdentifier.localizedStandardContains(query)
                || $0.url.path.localizedStandardContains(query)
                || ($0.version?.localizedStandardContains(query) ?? false)
        }
        switch sortMode {
        case "size": return found.sorted { (sizes[$0.id] ?? -1) > (sizes[$1.id] ?? -1) }
        case "version": return found.sorted { ($0.version ?? "").localizedStandardCompare($1.version ?? "") == .orderedDescending }
        default: return found.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let selectedRoot {
                scope(selectedRoot)
            } else {
                SerreParcel {
                    SerreEmptyState(title: copy("apps.initial.title"), message: copy("apps.initial.message")) {
                        VStack(spacing: 10) {
                            let found = ApplicationFolders.candidates(home: SandboxAccess.userHome)
                            if !found.isEmpty {
                                // Detected folders are offered, never read: the click is the choice.
                                HStack(spacing: 10) {
                                    ForEach(Array(found.enumerated()), id: \.element.path) { index, folder in
                                        Button { choose(folder) } label: {
                                            Label { Text(folderName(folder)) } icon: { SerreIcon(.applications, size: 15) }
                                        }
                                        .buttonStyle(.serre(index == 0 ? .primary : .secondary))
                                        .help(folder.path)
                                        .accessibilityHint(copy("apps.choose.hint"))
                                    }
                                }
                                Text(copy("apps.detected")).font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
                            }
                            Button(found.isEmpty ? copy("apps.choose") : copy("apps.other")) { selectingFolder = true }
                                .buttonStyle(.serre(found.isEmpty ? .primary : .secondary))
                                .accessibilityHint(copy("apps.choose.hint"))
                        }
                        .padding(.top, 6)
                    }
                }
            }
            if let notice, !notice.nearActions { banner(notice) }
            if scanning && associationApp == nil {
                SerreParcel {
                    HStack(spacing: 14) {
                        SerreIcon(.applications, size: 22).foregroundStyle(Palette.accent.color)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(copy("apps.reading")).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                            Text(copy("apps.reading.help")).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                        }
                    }
                }
            }
            if !records.isEmpty || flight.landed > 0 {
                inventory
            } else if !scanning && selectedRoot != nil && issues.isEmpty && notice == nil {
                SerreEmptyState(title: copy("apps.empty"), message: copy("apps.empty.help"))
            }
            if !issues.isEmpty {
                SerreBanner(.partial, title: copy("apps.issueCount", count: issues.count), message: copy("apps.issues.help")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(issueDescription(issue.reason)).font(CoreTendTypography.secondary).foregroundStyle(Palette.ink.color)
                                Text(issue.path).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                                    .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            }
            if let app = associationApp { associations(app) }
        }
        .leafFlightLayer(flight)
        .motion(.standard, value: notice)
        .motion(.quick, value: searchText)
        .fileImporter(isPresented: $selectingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let root = urls.first else { return }
            discover(root)
        }
        .fileDialogDefaultDirectory(suggestedDirectory)
        .fileImporter(isPresented: $selectingAssociationFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let root = urls.first, let app = associationApp else { return }
            reviewAssociations(for: app, in: root)
        }
        // Fixture-only (captures): open the folder given by the environment, as if chosen.
        .task { if selectedRoot == nil, let root = CoreTendPreferences().fixtureScanRoot { discover(root) } }
        .onDisappear { task?.cancel(); scanning = false; if removalReview != nil { cancelRemoval() } }
        .confirmationDialog(french ? "Déplacer l’app vers la Corbeille macOS ?" : "Move app to macOS Trash?",
                            isPresented: $removalDialogPresented, titleVisibility: .visible) {
            Button(french ? "Déplacer le bundle" : "Move app bundle", role: .destructive) { beginRemoval() }
            Button(copy("common.cancel"), role: .cancel) { cancelRemoval() }
                // Return cancels: a move to the Trash is only ever a deliberate click.
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(removalMessage)
        }
        .onChange(of: removalDialogPresented) { _, presented in
            if !presented && removalReview != nil { cancelRemoval() }
        }
    }

    // MARK: - Sections

    private func scope(_ root: URL) -> some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    SerreIcon(.applications, size: 18).foregroundStyle(Palette.accent.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy("explore.scope")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                        Text(SandboxAccess.displayPath(root)).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                            .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer(minLength: 8)
                    Button(copy("explore.chooseOther")) { selectingFolder = true }
                        .buttonStyle(.serre(.secondary))
                        .disabled(locked)
                        .accessibilityHint(copy("apps.choose.hint"))
                }
                Text(copy("apps.limits")).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// "Applications" for /Applications, "Applications (yours)" for the one in the home folder.
    private func folderName(_ folder: URL) -> String {
        folder.path == "/Applications" ? "Applications" : (french ? "Applications (les vôtres)" : "Applications (yours)")
    }

    private func banner(_ notice: PageNotice) -> some View {
        PageNoticeBanner(notice: notice, french: french, disabled: locked, chooseAgain: { selectingFolder = true },
                         retryScan: selectedRoot.map { root in { discover(root) } })
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(copy("apps.inventory")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                Spacer()
                Text(french ? "\(ProductFormat.count(visibleRecords.count, french: true)) sur \(ProductFormat.count(records.count, french: true))"
                            : "\(ProductFormat.count(visibleRecords.count, french: false)) of \(ProductFormat.count(records.count, french: false))")
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .contentTransition(.numericText(value: Double(visibleRecords.count)))
            }
            HStack(spacing: 10) {
                SerreIcon(.search, size: 15).foregroundStyle(Palette.accent.color).accessibilityHidden(true)
                TextField(french ? "Rechercher par nom, identifiant, version ou chemin" : "Search name, identifier, version, or path", text: $searchText)
                    .textFieldStyle(.plain).font(CoreTendTypography.body)
                    .accessibilityLabel(french ? "Rechercher dans l’inventaire d’apps" : "Search app inventory")
                if !searchText.isEmpty {
                    Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.secondaryInk.color) }
                        .buttonStyle(.serre(.icon)).accessibilityLabel(french ? "Effacer la recherche" : "Clear search")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Palette.raisedSurface.color, in: LeafCorner.control.shape)
            .overlay(LeafCorner.control.shape.strokeBorder(searchText.isEmpty ? Palette.strongSeparator.color : Palette.accent.color, lineWidth: 1))
            HStack(spacing: 12) {
                Picker(copy("apps.sort"), selection: $sortMode) {
                    Text(copy("apps.sort.name")).tag("name")
                    Text(copy("apps.sort.size")).tag("size")
                    Text(copy("apps.sort.version")).tag("version")
                }
                .pickerStyle(.menu).fixedSize().tint(Palette.accent.color).font(CoreTendTypography.secondary)
                Spacer()
                if sizing {
                    Text(copy("apps.sizing")).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                } else if !sizes.isEmpty {
                    Text("\(copy("apps.size.total")) \(ProductFormat.bytes(sizes.values.reduce(0, +), french: french))")
                        .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                }
            }
            if visibleRecords.isEmpty {
                SerreEmptyState(title: copy("apps.noMatch"), message: copy("apps.noMatch.help"))
            } else {
                SerreParcel {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visibleRecords.enumerated()), id: \.element.id) { index, app in
                            if index > 0 { Palette.separator.color.frame(height: 1).padding(.leading, 56) }
                            row(app).serreRise(index)
                        }
                    }
                    .id(plantingSeed)
                }
                .leafFlightAnchor("list")
            }
            HStack(spacing: 14) {
                TrashIndicator(landed: flight.landed, moving: moving, french: french)
                Spacer()
            }
            if let notice, notice.nearActions { banner(notice) }
        }
    }

    /// One planting row: the app's own icon, its name and identifier, version, place and update
    /// address, then its two actions.
    private func row(_ app: ApplicationRecord) -> some View {
        let failure = failures[app.url]
        return HStack(alignment: .top, spacing: 14) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable().interpolation(.high)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(app.displayName).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                        .textSelection(.enabled)
                    Text(app.version ?? (french ? "version inconnue" : "version unknown"))
                        .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                }
                Text(app.bundleIdentifier).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .textSelection(.enabled)
                updateSourceView(for: app)
                if let failure {
                    // An app macOS refuses to move is usually owned by the system or an administrator.
                    Text(copy(failure == "action.failure.trash" ? "apps.failure.protected" : failure))
                        .font(CoreTendTypography.caption).foregroundStyle(Palette.danger.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(sizes[app.id].map { ProductFormat.bytes($0, french: french) } ?? "—")
                    .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color).monospacedDigit()
                Image(systemName: expanded == app.id ? "chevron.up" : "chevron.down")
                    .font(.caption).foregroundStyle(Palette.tertiaryInk.color)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(reduceMotion ? nil : MotionCurve.sprout.animation(duration: 0.35)) {
                expanded = expanded == app.id ? nil : app.id
            }
        }
        .accessibilityAddTraits(.isButton)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if expanded == app.id { actions(app).transition(.opacity.combined(with: .move(edge: .top))) }
        }
        .padding(.vertical, 10)
        .overlay {
            if failure != nil { LeafCorner.control.shape.strokeBorder(Palette.danger.color, lineWidth: 1) }
        }
        .leafFlightRow(app.url)
        .transition(reduceMotion ? .identity : .asymmetric(insertion: .identity, removal: .opacity.combined(with: .scale(scale: 0.6, anchor: .leading))))
        .accessibilityElement(children: .contain)
    }

    /// The open row's actions: files around it, show in Finder, move to the Trash.
    private func actions(_ app: ApplicationRecord) -> some View {
        HStack(spacing: 10) {
            Button {
                associationApp = app
                associationResults = []
                associationEvidence = [:]
                associationStatus = nil
                selectingAssociationFolder = true
            } label: {
                Label { Text(copy("apps.associated")) } icon: { Image(systemName: "doc.text.magnifyingglass") }
            }
            .buttonStyle(.serre(.secondary))
            .disabled(locked)
            .accessibilityHint(french ? "Choisissez un dossier précis. Aucun fichier ne sera modifié et aucune attribution ne sera déduite." : "Choose a specific folder. No files will be changed and ownership will not be inferred.")
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            } label: {
                Label { Text(copy("apps.reveal")) } icon: { Image(systemName: "folder") }
            }
            .buttonStyle(.serre(.secondary))
            Spacer()
            Button { Task { await prepareRemoval(app) } } label: {
                Label { Text(copy("apps.trash")) } icon: { Image(systemName: "trash") }
            }
            .buttonStyle(.serre(.secondary))
            .disabled(locked)
            .accessibilityHint(french ? "Seul ce bundle sera proposé, après revue, revalidation et confirmation." : "Only this app bundle will be proposed, after review, revalidation, and confirmation.")
        }
        .padding(.leading, 54).padding(.bottom, 10)
    }

    private func associations(_ app: ApplicationRecord) -> some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 8) {
                Text(french ? "Fichiers autour de \(app.displayName)" : "Files around \(app.displayName)")
                    .font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                Text(french ? "Correspondance de nom seulement ; appartenance non prouvée. Vérifiez avant toute action." : "Name match only; ownership is unverified. Inspect before taking any action.")
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let associationStatus {
                    Text(associationStatus).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                }
                ForEach(associationResults, id: \.path) { url in
                    HStack(spacing: 8) {
                        RiskLeaf(.medium, size: 10)
                        Text(SandboxAccess.displayPath(url)).font(CoreTendTypography.caption).foregroundStyle(Palette.ink.color)
                            .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                        Spacer(minLength: 6)
                        Text(copy(associationEvidence[url] == .name ? "apps.evidence.name" : "apps.evidence.identifier"))
                            .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    }
                }
                if associationResults.isEmpty && associationStatus == nil {
                    Text(french ? "Aucun candidat trouvé." : "No candidates found.").font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                }
            }
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
                notice = PageNotice(kind: .error, title: french ? "Journal indisponible; déplacement bloqué." : "History unavailable; move blocked.", nearActions: true)
                releaseRemovalScope()
                return
            }
            removalApp = app
            removalReview = review
            removalService = service
            removalDialogPresented = true
        } catch {
            notice = PageNotice(kind: .error, title: french ? "Revue impossible; app inchangée." : "Review failed; app unchanged.", nearActions: true)
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
        moving = true
        defer { moving = false; removalBusy = false; releaseRemovalScope() }
        let batch: ConfirmedActionBatch
        do { batch = try service.confirm(review, accepted: true) } catch {
            notice = PageNotice(kind: .error, title: french ? "Déplacement refusé; app inchangée." : "Move refused; app unchanged.", nearActions: true)
            return
        }
        failures = [:]; flight.landed = 0; notice = nil
        let result = await executeShowingEachItem(service, batch, reduceMotion: reduceMotion) { item in
            guard item.moved else {
                failures[item.targetURL] = item.failureKey
                return
            }
            flight.send(item.targetURL, reduceMotion: reduceMotion)
            withAnimation(reduceMotion ? nil : MotionCurve.retreat.animation(duration: 0.2)) {
                records.removeAll { $0.id == app.id }
            }
            if associationApp?.id == app.id { associationApp = nil; associationResults = [] }
        }
        notice = result.movedCount == 1
            ? PageNotice(kind: .note, title: french ? "Bundle déplacé vers la Corbeille ; données associées inchangées." : "App bundle moved to Trash; associated data unchanged.",
                         message: french ? "Il reste récupérable depuis la Corbeille de macOS." : "It can be restored from the macOS Trash.", nearActions: true)
            : PageNotice(kind: .error, title: french ? "Le bundle est resté en place." : "The app bundle was left in place.",
                         message: french ? "La ligne dit pourquoi ; rien n’a été effacé." : "Its row says why; nothing was erased.", nearActions: true)
    }

    private func cancelRemoval() {
        guard let review = removalReview, let service = removalService else { return }
        removalBusy = true
        removalDialogPresented = false
        removalReview = nil; removalService = nil; removalApp = nil
        Task { @MainActor in
            let recorded = await service.recordCancellation(review)
            notice = PageNotice(kind: .note, title: recorded ? (french ? "Action annulée et journalisée." : "Action cancelled and recorded.")
                                                        : (french ? "Action annulée; journal indisponible." : "Action cancelled; history unavailable."), nearActions: true)
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
            Link(destination: url) {
                Label { Text(french ? "Ouvrir le flux déclaré" : "Open declared feed") } icon: { Image(systemName: "arrow.up.right") }
                    .font(CoreTendTypography.caption)
            }
            .buttonStyle(.serre(.icon))
                .accessibilityHint(french ? "Ouvre l’adresse HTTPS déclarée par cette app dans le navigateur. CoreTend ne vérifie aucune version." : "Opens this app’s declared HTTPS address in the browser. CoreTend does not compare versions.")
        case .invalidDeclaredFeed:
            Text(french ? "Adresse de mise à jour déclarée inutilisable." : "Declared update address is unusable.")
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
        case .unknown:
            // Said once in the scope note ("updates are not checked"), not repeated on every row.
            EmptyView()
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
                        if let evidence = ApplicationAssociationMatcher.evidence(item.url, bundleIdentifier: app.bundleIdentifier, displayName: app.displayName) {
                            associationEvidence[item.url] = evidence
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

    /// A suggested folder: read directly, or — in the App Sandbox — through the panel opened on it.
    private func choose(_ folder: URL) {
        if SandboxAccess.isSandboxed {
            suggestedDirectory = folder
            selectingFolder = true
        } else {
            discover(folder)
        }
    }

    private func discover(_ root: URL) {
        task?.cancel()
        selectedRoot = root
        records = []; issues = []; notice = nil; failures = [:]; flight.landed = 0; scanning = true
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
            measureSizes(report.applications)
            plantingSeed = UUID()
            issues = report.issues
            if report.applications.isEmpty && report.issues.isEmpty { notice = nil }
            else if report.applications.isEmpty { notice = PageNotice(kind: .error, title: copy("apps.failed"), recovery: .chooseAgain) }
        }
    }

    /// Bundle sizes, read in the background one app at a time; the list fills in as they come.
    private func measureSizes(_ apps: [ApplicationRecord]) {
        sizes = [:]
        sizing = true
        Task {
            for app in apps {
                let url = app.url
                let size = await Task.detached(priority: .utility) { ApplicationSizer.allocatedSize(of: url) }.value
                if let size { sizes[app.id] = size }
            }
            sizing = false
        }
    }

    private func copy(_ key: String, count: Int? = nil) -> String {
        if key == "apps.count", let count { return french ? "\(count) applications locales" : "\(count) local applications" }
        if key == "apps.issueCount", let count {
            if french { return count == 1 ? "1 anomalie détectée" : "\(count) anomalies détectées" }
            return count == 1 ? "1 issue found" : "\(count) issues found"
        }
        return ProductCopy.value(for: key, french: french)
    }

    private func issueDescription(_ reason: String) -> String {
        switch reason {
        case "selected_root_missing", "selected_root_access_denied", "selected_root_not_directory",
             "selected_root_symlink", "selected_root_unavailable", "selected_root_unreadable",
             "bundle_contents_unavailable", "bundle_identifier_missing", "bundle_metadata_unavailable":
            copy("apps.issue.\(reason)")
        default:
            copy("apps.issue.unknown")
        }
    }
}
