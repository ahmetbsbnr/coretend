import SwiftUI
import UniformTypeIdentifiers
import Persistence
import AppShell

struct SettingsView: View {
    let french: Bool
    @Binding var language: String
    @State private var store: SQLiteStore?
    @State private var exclusions: [String] = []
    @State private var chooseExclusion = false
    @State private var chooseLegacy = false
    @State private var legacyPreview: LegacyPreferencesPreview?
    @State private var importing = false
    @State private var exporting = false
    @State private var diagnosticPreview = false
    @State private var diagnosticDocument: SettingsJSONDocument?
    @State private var diagnosticSummary = ""
    @State private var status: String?

    var body: some View {
        Form {
            Section(french ? "Langue" : "Language") {
                Picker(ProductCopy.value(for: "settings.language", french: french), selection: $language) {
                    Text(ProductCopy.value(for: "settings.system", french: french)).tag("system")
                    Text("Français").tag("fr")
                    Text("English").tag("en")
                }
                .onChange(of: language) { _, value in Task { try? await store?.saveLanguagePreference(value) } }
            }

            Section(french ? "Exclusions locales" : "Local exclusions") {
                Text(french ? "Les scans ignoreront ces dossiers lors des prochains parcours. Rien n’est supprimé." : "Scans will skip these folders in future scans. Nothing is deleted.")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach(exclusions, id: \.self) { path in
                    HStack {
                        Text(URL(fileURLWithPath: path).lastPathComponent).lineLimit(1)
                        Text(path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Button(role: .destructive) { Task { await removeExclusion(path) } } label: { Image(systemName: "minus.circle") }
                            .accessibilityLabel(french ? "Retirer \(path) des exclusions" : "Remove \(path) from exclusions")
                    }
                }
                Button { chooseExclusion = true } label: {
                    Label(french ? "Ajouter un dossier exclu…" : "Add excluded folder…", systemImage: "folder.badge.plus")
                }
            }

            Section(french ? "Données héritées" : "Legacy data") {
                Text(french ? "Import opt-in des préférences v1 reconnues. Le fichier source reste intact." : "Opt-in import for recognized v1 preferences. Source file remains unchanged.")
                    .font(.callout).foregroundStyle(.secondary)
                Button { chooseLegacy = true } label: { Label(french ? "Choisir le fichier d’origine…" : "Choose source file…", systemImage: "arrow.down.doc") }
                    .disabled(importing)
                if importing { ProgressView() }
            }

            Section(french ? "Conservation des données" : "Data retention") {
                Text(french ? "L’activité reste dans la base locale jusqu’à son effacement explicite dans Historique. Les préférences et exclusions restent jusqu’à leur modification ou au retrait de la base." : "Activity stays in the local database until you explicitly clear it in Record. Preferences and exclusions remain until changed or the database is removed.")
                Text(french ? "Les relevés Performance sont conservés 30 jours et limités à 500. Vous pouvez les effacer dans Performances; une nouvelle ouverture de cette vue créera un nouveau relevé." : "Performance readings are kept for 30 days and capped at 500. You can clear them in Performance; reopening that view creates a new reading.")
            }

            Section(french ? "Diagnostic privé" : "Private diagnostics") {
                Text(french ? "Aperçu contient version, schéma et compteurs d’événements. Aucun chemin, nom de fichier ni détail d’événement." : "Preview includes app version, schema and event counts. No paths, file names or event details.")
                    .font(.callout).foregroundStyle(.secondary)
                Button(french ? "Prévisualiser l’export…" : "Preview export…") { Task { await buildDiagnosticPreview() } }
            }
            if let status { Text(status).foregroundStyle(.secondary) }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 520)
        .task { await load() }
        .fileImporter(isPresented: $chooseExclusion, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await addExclusion(url) }
        }
        .fileImporter(isPresented: $chooseLegacy, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let hasScope = url.startAccessingSecurityScopedResource()
            defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
            do { legacyPreview = try LegacyPreferencesImporter().preview(sourceURL: url) }
            catch { status = french ? "Format non reconnu; aucune donnée importée." : "Unrecognized format; no data imported." }
        }
        .confirmationDialog(french ? "Importer ces préférences ?" : "Import these preferences?", isPresented: Binding(get: { legacyPreview != nil }, set: { if !$0 { legacyPreview = nil } }), titleVisibility: .visible) {
            Button(french ? "Importer les préférences" : "Import preferences") { Task { await importLegacy() } }
            Button(ProductCopy.value(for: "common.cancel", french: french), role: .cancel) { legacyPreview = nil }
        } message: {
            Text(legacyMessage)
        }
        .alert(french ? "Aperçu du diagnostic" : "Diagnostic preview", isPresented: $diagnosticPreview) {
            Button(ProductCopy.value(for: "common.cancel", french: french), role: .cancel) { diagnosticDocument = nil }
            Button(french ? "Choisir la destination…" : "Choose destination…") { exporting = true }
        } message: { Text(diagnosticSummary + "\n" + (french ? "Aucun chemin personnel ni détail d’événement exporté. Vous choisissez la destination." : "No personal paths or event details exported. You choose the destination.")) }
        .fileExporter(isPresented: $exporting, document: diagnosticDocument, contentType: .json,
                      defaultFilename: "coretend-diagnostic") { result in
            if case .failure = result { status = french ? "Export impossible." : "Export failed." }
        }
    }

    private var legacyMessage: String {
        guard let legacyPreview else { return "" }
        let count = legacyPreview.excludedPaths.count
        let lang = legacyPreview.language ?? (french ? "langue absente" : "language absent")
        return french ? "\(count) exclusion(s), langue \(lang). Source conservée; import réessayable." : "\(count) exclusion(s), language \(lang). Source preserved; import can be retried."
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
            diagnosticSummary = french ? "Schéma \(schema); \(events.count) événements." : "Schema \(schema); \(events.count) events."
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
