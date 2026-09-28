import SwiftUI
import UniformTypeIdentifiers
import Persistence
import AppShell
import Domain
import DesignSystem

struct SettingsView: View {
    let french: Bool
    @Binding var language: String
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
    @State private var exporting = false
    @State private var diagnosticPreview = false
    @State private var exportAfterPreview = false
    @State private var diagnosticDocument: SettingsJSONDocument?
    @State private var diagnosticSummary = ""
    @State private var ownSignature: CodeSignatureReport?
    @State private var status: String?

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
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let status { SerreBanner(.note, title: status) }
                    section(french ? "Langue" : "Language") {
                        choices([("system", ProductCopy.value(for: "settings.system", french: french)), ("fr", "Français"), ("en", "English")],
                                selection: $language)
                            .onChange(of: language) { _, value in Task { try? await store?.saveLanguagePreference(value) } }
                    }
                    section(french ? "Apparence" : "Appearance") {
                        choices([(AppearancePreference.system, french ? "Système" : "System"),
                                 (AppearancePreference.light, french ? "Clair" : "Light"),
                                 (AppearancePreference.dark, french ? "Sombre" : "Dark")], selection: $appearance)
                            .disabled(!CoreTendPreferences().usesPersistentStorage)
                    }
                    section(french ? "Exclusions locales" : "Local exclusions",
                            help: french ? "Les analyses ignoreront ces dossiers lors des prochains parcours. Rien n’est supprimé." : "Scans will skip these folders in future scans. Nothing is deleted.") {
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
                                .accessibilityLabel(french ? "Retirer \(path) des exclusions" : "Remove \(path) from exclusions")
                            }
                        }
                        Button(french ? "Ajouter un dossier exclu…" : "Add excluded folder…") { chooseExclusion = true }
                            .buttonStyle(.serre(.secondary))
                    }
                    section(french ? "Accès aux dossiers" : "Folder access") {
                        note(ProductCopy.value(for: "settings.folderaccess.help", french: french))
                        note(ProductCopy.value(for: "settings.fulldiskaccess.help", french: french))
                    }
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
                    section(french ? "Données héritées" : "Legacy data",
                            help: french ? "Import sur demande des préférences 1.x reconnues. Le fichier source reste intact." : "Opt-in import for recognized 1.x preferences. The source file remains unchanged.") {
                        Button(importing ? (french ? "Import…" : "Importing…") : (french ? "Choisir le fichier d’origine…" : "Choose source file…")) { chooseLegacy = true }
                            .buttonStyle(.serre(.secondary))
                            .disabled(importing)
                    }
                    section(french ? "Conservation des données" : "Data retention") {
                        note(french ? "L’activité reste dans la base locale jusqu’à son effacement explicite dans Historique. Les préférences et exclusions restent jusqu’à leur modification ou au retrait de la base." : "Activity stays in the local database until you explicitly clear it in Record. Preferences and exclusions remain until changed or the database is removed.")
                        note(french ? "Les relevés Performances sont conservés 30 jours et limités à 500. Vous pouvez les effacer dans Performances ; une nouvelle ouverture de cette vue créera un nouveau relevé." : "Performance readings are kept for 30 days and capped at 500. You can clear them in Performance; reopening that view creates a new reading.")
                        Toggle(french ? "Enregistrer les fichiers récents dans Explorer" : "Save recent files from Explore", isOn: $recentFilesEnabled)
                            .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                        note(french ? "Désactivé par défaut. Activé, la dernière analyse Explorer mémorise jusqu’à 100 chemins locaux et leur dernière taille connue. Désactivez-le pour arrêter cet enregistrement ; effacez les éléments dans Vue d’ensemble." : "Off by default. When enabled, the latest Explore scan stores up to 100 local paths and their last known size. Turn it off to stop recording; remove entries in Overview.")
                    }
                    section(french ? "Barre des menus" : "Menu bar") {
                        Toggle(ProductCopy.value(for: "settings.menubar.title", french: french), isOn: $menuBarEnabled)
                            .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                        note(ProductCopy.value(for: "settings.menubar.help", french: french))
                    }
                    section(french ? "Diagnostic privé" : "Private diagnostics",
                            help: french ? "L’aperçu contient version, schéma et compteurs d’événements. Aucun chemin, nom de fichier ni détail d’événement." : "Preview includes app version, schema and event counts. No paths, file names or event details.") {
                        Button(french ? "Prévisualiser l’export…" : "Preview export…") { Task { await buildDiagnosticPreview() } }
                            .buttonStyle(.serre(.secondary))
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
                Button(french ? "Terminé" : "Done") { close() }.buttonStyle(.serre(.primary))
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(minWidth: 600, idealWidth: 660, minHeight: 440, idealHeight: 620, maxHeight: 720)
        .background(Palette.canvas.color)
        .task {
            await load()
            ownSignature = MacOSCodeSignatureInspector().inspect(at: Bundle.main.bundleURL)
        }
        .fileImporter(isPresented: $chooseExclusion, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await addExclusion(url) }
        }
        .fileImporter(isPresented: $chooseLegacy, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let hasScope = url.startAccessingSecurityScopedResource()
            defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
            do { legacyPreview = try LegacyPreferencesImporter().preview(sourceURL: url) }
            catch { status = french ? "Format non reconnu ; aucune donnée importée." : "Unrecognized format; no data imported." }
        }
        .confirmationDialog(french ? "Importer ces préférences ?" : "Import these preferences?", isPresented: Binding(get: { legacyPreview != nil }, set: { if !$0 { legacyPreview = nil } }), titleVisibility: .visible) {
            Button(french ? "Importer les préférences" : "Import preferences") { Task { await importLegacy() } }
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
                Text(french ? "Aperçu exact du diagnostic" : "Exact diagnostic preview")
                    .font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                Text(diagnosticSummary + " · " + (french ? "Aucun chemin personnel ni détail d’événement." : "No personal paths or event details."))
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
                    Button(french ? "Choisir la destination…" : "Choose destination…") {
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
            if case .failure = result { status = french ? "Export impossible." : "Export failed." }
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
        let lang = legacyPreview.language ?? (french ? "langue absente" : "language absent")
        let number = ProductFormat.count(count, french: french)
        let noun = french ? "exclusion\(ProductFormat.frenchPlural(count))" : (count == 1 ? "exclusion" : "exclusions")
        return french ? "\(number) \(noun), langue \(lang). Source conservée ; import réessayable." : "\(number) \(noun), language \(lang). Source preserved; import can be retried."
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
        } catch { status = french ? "Réglages locaux indisponibles." : "Local settings unavailable." }
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
        } catch { status = french ? "Exclusion non enregistrée." : "Exclusion was not saved." }
    }

    @MainActor private func removeExclusion(_ path: String) async {
        guard let store else { return }
        do {
            let next = exclusions.filter { $0 != path }
            try await store.saveExclusions(next); exclusions = next
        } catch { status = french ? "Exclusion non retirée." : "Exclusion was not removed." }
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
            if let importedLanguage = preview.language { language = importedLanguage }
            status = french ? (outcome == .imported ? "Préférences importées; source conservée." : "Déjà importées; aucune copie répétée.") : (outcome == .imported ? "Preferences imported; source preserved." : "Already imported; no duplicate copy.")
        } catch { status = french ? "Import échoué; source conservée." : "Import failed; source preserved." }
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
            diagnosticSummary = french ? "Schéma \(version) ; \(count) événement\(ProductFormat.frenchPlural(events.count))." : "Schema \(version); \(count) \(events.count == 1 ? "event" : "events")."
            diagnosticPreview = true
        } catch { status = french ? "Diagnostic indisponible." : "Diagnostic unavailable." }
    }
}

private struct SettingsJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
