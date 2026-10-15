import SwiftUI
import UniformTypeIdentifiers
import Persistence
import AppShell
import Domain
import DesignSystem

struct SettingsView: View {
    let french: Bool
    @Binding var appearance: AppearancePreference
    @Binding var recentFilesEnabled: Bool
    @Binding var menuBarEnabled: Bool
    let close: () -> Void
    @State private var store: SQLiteStore?
    @State private var exclusions: [String] = []
    @State private var chooseExclusion = false
    @State private var chooseLegacy = false
    @State private var legacyPreview: LegacyPreferencesPreview?
    @State private var importing = false
    @State private var readingLegacy = false
    @State private var exporting = false
    @State private var diagnosticPreview = false
    @State private var exportAfterPreview = false
    @State private var diagnosticDocument: SettingsJSONDocument?
    @State private var diagnosticSummary = ""
    @State private var ownSignature: CodeSignatureReport?
    @State private var status: String?
    @AppStorage("coretend.livingGreenhouse") private var livingGreenhouse = true
    @State private var soundsEnabled = CoreTendPreferences().soundsEnabled
    @State private var alertsEnabled = CoreTendPreferences().alertsEnabled
    @State private var alertsDenied = false
    @Environment(AppUpdater.self) private var updater
    @State private var tab = "general"
    @Namespace private var tabMarker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SerreIcon(.settings, size: 22).foregroundStyle(Palette.accent.color)
                Text(ProductCopy.value(for: "settings.title", french: french))
                    .font(CoreTendTypography.pageTitle)
                    .foregroundStyle(Palette.ink.color)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 12)
            HStack(spacing: 8) {
                ForEach([("general", ProductCopy.inline("Général", "General", french: french), SerreGlyph.settings),
                         ("access", ProductCopy.inline("Accès", "Access", french: french), SerreGlyph.explore),
                         ("privacy", ProductCopy.inline("Confidentialité", "Privacy", french: french), SerreGlyph.integrity),
                         ("data", ProductCopy.inline("Données", "Data", french: french), SerreGlyph.record),
                         ("system", ProductCopy.inline("Système", "System", french: french), SerreGlyph.cleanup)], id: \.0) { item in
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74)) { tab = item.0 }
                    } label: {
                        Label { Text(item.1) } icon: { SerreIcon(item.2, size: 15) }
                            .font(CoreTendTypography.body.weight(tab == item.0 ? .semibold : .regular))
                            .foregroundStyle(tab == item.0 ? Palette.onAccent.color : Palette.secondaryInk.color)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background {
                                // Decision 0009: a leaf marker slides to the chosen tab.
                                if tab == item.0 {
                                    LeafCorner.control.shape.fill(Palette.accent.color).matchedGeometryEffect(id: "tab", in: tabMarker)
                                }
                            }
                            .contentShape(LeafCorner.control.shape)
                    }
                    .buttonStyle(.serre(.bare))
                    .fixedSize()
                    .accessibilityAddTraits(tab == item.0 ? .isSelected : [])
                }
                Spacer()
            }
            .padding(.horizontal, 24).padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let status { SerreBanner(.note, title: status) }
                    if tab == "general" {
                    section(ProductCopy.inline("Apparence", "Appearance", french: french)) {
                        choices([(AppearancePreference.system, ProductCopy.inline("Système", "System", french: french)),
                                 (AppearancePreference.light, ProductCopy.inline("Clair", "Light", french: french)),
                                 (AppearancePreference.dark, ProductCopy.inline("Sombre", "Dark", french: french))], selection: $appearance)
                            .disabled(!CoreTendPreferences().usesPersistentStorage)
                    }
                    section(ProductCopy.inline("Serre vivante", "Living greenhouse", french: french),
                            help: ProductCopy.inline("Les feuilles bougent doucement quand la fenêtre est active. Tout s’arrête fenêtre inactive ou cachée, en mode économie d’énergie et avec « Réduire les animations ».", "Leaves move gently while the window is active. Everything stops when the window is inactive or hidden, in Low Power Mode and with Reduce Motion.", french: french)) {
                        Toggle(ProductCopy.inline("Laisser la serre vivre", "Let the greenhouse live", french: french), isOn: $livingGreenhouse)
                            .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                            .accessibilityLabel(ProductCopy.inline("Laisser la serre vivre", "Let the greenhouse live", french: french))
                    }
                    if updater.isAvailable {
                    section(ProductCopy.value(for: "updates.title", french: french), help: ProductCopy.value(for: "updates.help", french: french)) {
                        @Bindable var updater = updater
                        Toggle(ProductCopy.value(for: "updates.automatic", french: french), isOn: $updater.automaticChecks)
                            .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                        Button(ProductCopy.value(for: "updates.check", french: french)) { updater.checkForUpdates() }
                            .buttonStyle(.serre(.secondary))
                    }
                    }
                    section(ProductCopy.value(for: "settings.sound.title", french: french), help: ProductCopy.value(for: "settings.sound.help", french: french)) {
                        Toggle(ProductCopy.value(for: "settings.sound.toggle", french: french), isOn: $soundsEnabled)
                            .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                            .onChange(of: soundsEnabled) { _, value in CoreTendPreferences().saveSoundsEnabled(value) }
                    }
                    section(ProductCopy.value(for: "settings.alerts.title", french: french), help: ProductCopy.value(for: "settings.alerts.help", french: french)) {
                        Toggle(ProductCopy.value(for: "settings.alerts.toggle", french: french), isOn: $alertsEnabled)
                            .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                            .disabled(!CoreTendPreferences().usesPersistentStorage)
                            .onChange(of: alertsEnabled) { _, value in
                                Task { @MainActor in
                                    if value, !(await CareAlertMonitor.shared.requestPermission()) {
                                        alertsDenied = true; alertsEnabled = false; return
                                    }
                                    alertsDenied = false
                                    CoreTendPreferences().saveAlertsEnabled(value)
                                    if value { await CareAlertMonitor.shared.check() }
                                }
                            }
                        if alertsDenied { note(ProductCopy.value(for: "settings.alerts.denied", french: french)) }
                    }
                    section(ProductCopy.inline("Barre des menus", "Menu bar", french: french)) {
                        Toggle(ProductCopy.value(for: "settings.menubar.title", french: french), isOn: $menuBarEnabled)
                            .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                            .accessibilityLabel(ProductCopy.value(for: "settings.menubar.title", french: french))
                        note(ProductCopy.value(for: "settings.menubar.help", french: french))
                    }
                    }
                    if tab == "access" {
                    section(ProductCopy.inline("Exclusions locales", "Local exclusions", french: french),
                            help: ProductCopy.inline("Les analyses ignoreront ces dossiers lors des prochains parcours. Rien n’est supprimé.", "Scans will skip these folders in future scans. Nothing is deleted.", french: french)) {
                        ForEach(exclusions, id: \.self) { path in
                            HStack(spacing: 10) {
                                SerreIcon(.explore, size: 14).foregroundStyle(Palette.secondaryInk.color)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(URL(fileURLWithPath: path).lastPathComponent).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                                    Text(path).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                Button { Task { await removeExclusion(path) } } label: {
                                    Image(systemName: "minus.circle").foregroundStyle(Palette.secondaryInk.color)
                                }
                                .buttonStyle(.serre(.icon))
                                .accessibilityLabel(ProductCopy.inline("Retirer %1$@ des exclusions", "Remove %1$@ from exclusions", french: french, "\(path)"))
                            }
                        }
                        Button(ProductCopy.inline("Ajouter un dossier exclu…", "Add excluded folder…", french: french)) { chooseExclusion = true }
                            .buttonStyle(.serre(.secondary))
                    }
                    section(ProductCopy.inline("Accès aux dossiers", "Folder access", french: french)) {
                        note(ProductCopy.value(for: "settings.folderaccess.help", french: french))
                        note(ProductCopy.value(for: "settings.fulldiskaccess.help", french: french))
                    }
                    }
                    if tab == "privacy" {
                    section(ProductCopy.value(for: "settings.signature.title", french: french)) {
                        SerreSignalTag(signatureTone(ownSignature?.state), title: ownSignature.map { signatureText($0.state) }
                                        ?? ProductCopy.value(for: "settings.signature.unavailable", french: french)) {
                            VStack(alignment: .leading, spacing: 3) {
                                if let identifier = ownSignature?.identifier {
                                    fact(ProductCopy.value(for: "integrity.identifier", french: french), identifier)
                                }
                                if let team = ownSignature?.teamIdentifier {
                                    fact(ProductCopy.value(for: "integrity.team", french: french), team)
                                }
                                note(ProductCopy.value(for: "settings.signature.limit", french: french))
                            }
                        }
                    }
                    section(ProductCopy.inline("Diagnostic privé", "Private diagnostics", french: french),
                            help: ProductCopy.inline("L’aperçu contient version, schéma et compteurs d’événements. Aucun chemin, nom de fichier ni détail d’événement.", "Preview includes app version, schema and event counts. No paths, file names or event details.", french: french)) {
                        Button(ProductCopy.inline("Prévisualiser l’export…", "Preview export…", french: french)) { Task { await buildDiagnosticPreview() } }
                            .buttonStyle(.serre(.secondary))
                    }
                    }
                    if tab == "system" {
                        SystemToolsView(french: french) { title, help, content in section(title, help: help) { content } }
                    }
                    if tab == "data" {
                    section(ProductCopy.inline("Conservation des données", "Data retention", french: french)) {
                        note(ProductCopy.inline("L’activité reste dans la base locale jusqu’à son effacement explicite dans Historique. Les préférences et exclusions restent jusqu’à leur modification ou au retrait de la base.", "Activity stays in the local database until you explicitly clear it in Record. Preferences and exclusions remain until changed or the database is removed.", french: french))
                        note(ProductCopy.inline("Les relevés Performances sont conservés 30 jours et limités à 500. Vous pouvez les effacer dans Performances ; une nouvelle ouverture de cette vue créera un nouveau relevé.", "Performance readings are kept for 30 days and capped at 500. You can clear them in Performance; reopening that view creates a new reading.", french: french))
                        Toggle(ProductCopy.inline("Enregistrer les fichiers récents dans Explorer", "Save recent files from Explore", french: french), isOn: $recentFilesEnabled)
                            .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                            .accessibilityLabel(ProductCopy.inline("Enregistrer les fichiers récents dans Explorer", "Save recent files from Explore", french: french))
                        note(ProductCopy.inline("Désactivé par défaut. Activé, la dernière analyse Explorer mémorise jusqu’à 100 chemins locaux et leur dernière taille connue. Désactivez-le pour arrêter cet enregistrement ; effacez les éléments dans Vue d’ensemble.", "Off by default. When enabled, the latest Explore scan stores up to 100 local paths and their last known size. Turn it off to stop recording; remove entries in Overview.", french: french))
                    }
                    section(ProductCopy.inline("Données héritées", "Legacy data", french: french),
                            help: ProductCopy.inline("Copie SQLite 1.x : exclusions uniquement. JSON v1 : exclusions et langue. Le fichier source reste intact.", "SQLite 1.x copy: exclusions only. JSON v1: exclusions and language. The source file remains unchanged.", french: french)) {
                        Button(readingLegacy ? (ProductCopy.inline("Lecture…", "Reading…", french: french)) : importing ? (ProductCopy.inline("Import…", "Importing…", french: french)) : (ProductCopy.inline("Choisir une copie 1.x…", "Choose a 1.x copy…", french: french))) { chooseLegacy = true }
                            .buttonStyle(.serre(.secondary))
                            .disabled(importing || readingLegacy)
                    }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 20)
                .toggleStyle(.switch)
                .tint(Palette.accent.color)
            }
            Palette.separator.color.frame(height: 1)
            // Settings is a sheet with no window close control; this is its visible exit.
            HStack {
                Spacer()
                Button(ProductCopy.inline("Terminé", "Done", french: french)) { close() }.buttonStyle(.serre(.primary))
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(minWidth: 760, idealWidth: 880, minHeight: 600, idealHeight: 720, maxHeight: 860)
        .background(Palette.canvas.color)
        .task {
            await load()
            ownSignature = MacOSCodeSignatureInspector().inspect(at: Bundle.main.bundleURL)
        }
        .fileImporter(isPresented: $chooseExclusion, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await addExclusion(url) }
        }
        .fileImporter(isPresented: $chooseLegacy, allowedContentTypes: [.json, UTType(filenameExtension: "sqlite") ?? .data], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let hasScope = url.startAccessingSecurityScopedResource()
            readingLegacy = true
            Task {
                defer { readingLegacy = false; if hasScope { url.stopAccessingSecurityScopedResource() } }
                do {
                    legacyPreview = try await Task.detached(priority: .utility) {
                        try LegacyPreferencesImporter().preview(sourceURL: url)
                    }.value
                } catch {
                    status = ProductCopy.inline("Copie non reconnue ou incomplète ; aucune donnée importée.", "Unrecognized or incomplete copy; no data imported.", french: french)
                }
            }
        }
        .confirmationDialog(ProductCopy.inline("Importer ces préférences ?", "Import these preferences?", french: french), isPresented: Binding(get: { legacyPreview != nil }, set: { if !$0 { legacyPreview = nil } }), titleVisibility: .visible) {
            Button(ProductCopy.inline("Importer les préférences", "Import preferences", french: french)) { Task { await importLegacy() } }
            Button(ProductCopy.value(for: "common.cancel", french: french), role: .cancel) { legacyPreview = nil }
        } message: {
            Text(legacyMessage)
        }
        .sheet(isPresented: $diagnosticPreview, onDismiss: {
            guard exportAfterPreview else { return }
            exportAfterPreview = false
            exporting = true
        }) {
            VStack(alignment: .leading, spacing: 14) {
                Text(ProductCopy.inline("Aperçu exact du diagnostic", "Exact diagnostic preview", french: french))
                    .font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                Text(diagnosticSummary + " · " + (ProductCopy.inline("Aucun chemin personnel ni détail d’événement.", "No personal paths or event details.", french: french)))
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                ScrollView {
                    // The exact bytes that would be written, as they are.
                    Text(diagnosticPreviewText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.ink.color)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .background(Palette.raisedSurface.color, in: LeafCorner.parcel.shape)
                HStack {
                    Spacer()
                    Button(ProductCopy.value(for: "common.cancel", french: french)) {
                        diagnosticDocument = nil
                        diagnosticPreview = false
                    }
                    .buttonStyle(.serre(.secondary))
                    Button(ProductCopy.inline("Choisir la destination…", "Choose destination…", french: french)) {
                        exportAfterPreview = true
                        diagnosticPreview = false
                    }
                    .buttonStyle(.serre(.primary))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(22)
            .frame(minWidth: 520, minHeight: 440)
            .background(Palette.surface.color)
        }
        .fileExporter(isPresented: $exporting, document: diagnosticDocument, contentType: .json,
                      defaultFilename: "coretend-diagnostic") { result in
            if case .failure = result { status = ProductCopy.inline("Export impossible.", "Export failed.", french: french) }
        }
    }

    // MARK: - Pieces

    private func section<Content: View>(_ title: String, help: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                    .accessibilityAddTraits(.isHeader)
                if let help { note(help) }
                content()
            }
        }
        // Each section of a tab rises into place when the tab opens (decision 0009).
        .serreRise(1)
    }

    /// A choice among a few values, as Serre rows side by side.
    private func choices<Value: Hashable>(_ options: [(Value, String)], selection: Binding<Value>) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let selected = selection.wrappedValue == option.0
                Button { selection.wrappedValue = option.0 } label: {
                    HStack(spacing: 8) {
                        SerreCheck(isOn: selected)
                        Text(option.1).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                    }
                }
                .buttonStyle(.serre(.row(selected: selected)))
                .fixedSize()
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func fact(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
            Text(value).font(CoreTendTypography.caption.weight(.semibold)).foregroundStyle(Palette.ink.color).textSelection(.enabled)
        }
    }

    private func signatureTone(_ state: CodeSignatureState?) -> SerreSignalTone {
        switch state {
        case .valid: .good
        case .invalid: .bad
        case .unavailable, nil: .caution
        }
    }

    private var legacyMessage: String {
        guard let legacyPreview else { return "" }
        let count = legacyPreview.excludedPaths.count
        let lang = legacyPreview.language ?? (ProductCopy.inline("langue absente", "language absent", french: french))
        let number = ProductFormat.count(count, french: french)
        return count == 1 || (french && count == 0)
            ? ProductCopy.inline("%1$@ exclusion, langue %2$@. Source conservée ; import réessayable.", "%1$@ exclusion, language %2$@. Source preserved; import can be retried.", french: french, number, lang)
            : ProductCopy.inline("%1$@ exclusions, langue %2$@. Source conservée ; import réessayable.", "%1$@ exclusions, language %2$@. Source preserved; import can be retried.", french: french, number, lang)
    }

    private var diagnosticPreviewText: String {
        guard let data = diagnosticDocument?.data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private func signatureText(_ state: CodeSignatureState) -> String {
        let key: String
        switch state {
        case .valid: key = "settings.signature.valid"
        case .invalid: key = "settings.signature.invalid"
        case .unavailable: key = "settings.signature.unavailable"
        }
        return ProductCopy.value(for: key, french: french)
    }

    @MainActor private func load() async {
        do {
            let local = try await LocalStoreAccess.open()
            store = local; exclusions = try await local.exclusions()
        } catch { status = ProductCopy.inline("Réglages locaux indisponibles.", "Local settings unavailable.", french: french) }
    }

    @MainActor private func resolvedStore() async throws -> SQLiteStore {
        if let store { return store }
        return try await LocalStoreAccess.open()
    }

    @MainActor private func addExclusion(_ url: URL) async {
        do {
            let local = try await resolvedStore()
            store = local
            let path = url.standardizedFileURL.path
            guard !exclusions.contains(path) else { return }
            let next = (exclusions + [path]).sorted()
            try await local.saveExclusions(next); exclusions = next
        } catch { status = ProductCopy.inline("Exclusion non enregistrée.", "Exclusion was not saved.", french: french) }
    }

    @MainActor private func removeExclusion(_ path: String) async {
        guard let store else { return }
        do {
            let next = exclusions.filter { $0 != path }
            try await store.saveExclusions(next); exclusions = next
        } catch { status = ProductCopy.inline("Exclusion non retirée.", "Exclusion was not removed.", french: french) }
    }

    @MainActor private func importLegacy() async {
        guard let preview = legacyPreview else { return }
        importing = true
        defer { importing = false; legacyPreview = nil }
        do {
            let local = try await resolvedStore()
            store = local
            let outcome = try await LegacyPreferencesImporter().importCopy(preview, into: local)
            exclusions = try await local.exclusions()
            status = outcome == .imported ? ProductCopy.inline("Préférences importées; source conservée.", "Preferences imported; source preserved.", french: french)
                                          : ProductCopy.inline("Déjà importées; aucune copie répétée.", "Already imported; no duplicate copy.", french: french)
        } catch { status = ProductCopy.inline("Import échoué; source conservée.", "Import failed; source preserved.", french: french) }
    }

    @MainActor private func buildDiagnosticPreview() async {
        do {
            let local = try await resolvedStore()
            store = local
            let events = try await local.events()
            let schema = try await local.schemaVersion()
            let data = try DiagnosticExport.json(schemaVersion: schema, events: events)
            diagnosticDocument = SettingsJSONDocument(data: data)
            let version = ProductFormat.count(schema, french: french)
            let count = ProductFormat.count(events.count, french: french)
            diagnosticSummary = events.count == 1
                ? ProductCopy.inline("Schéma %1$@ ; %2$@ événement.", "Schema %1$@; %2$@ event.", french: french, "\(version)", "\(count)")
                : ProductCopy.inline("Schéma %1$@ ; %2$@ événements.", "Schema %1$@; %2$@ events.", french: french, "\(version)", "\(count)")
            diagnosticPreview = true
        } catch { status = ProductCopy.inline("Diagnostic indisponible.", "Diagnostic unavailable.", french: french) }
    }
}

private struct SettingsJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
