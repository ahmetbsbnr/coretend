import SwiftUI
import Persistence

struct SavedFilesView: View {
    let french: Bool
    @State private var records: [SavedFileRecord] = []
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(french ? "Favoris et récents" : "Favorites and recent files")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel(french ? "Actualiser favoris et récents" : "Refresh favorites and recent files")
            }
            if records.isEmpty {
                ContentUnavailableView(french ? "Aucun fichier enregistré" : "No saved files",
                                       systemImage: "star", description: Text(french
                                           ? "Ajoutez un favori dans Explorer ou activez l’historique récent dans Réglages."
                                           : "Add a favorite in Explore or enable recent history in Settings."))
                    .frame(minHeight: 130)
            } else {
                ForEach(records, id: \.path) { record in
                    HStack(spacing: 10) {
                        Image(systemName: record.isFavorite ? "star.fill" : "clock")
                            .foregroundStyle(record.isFavorite ? .yellow : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(URL(fileURLWithPath: record.path).lastPathComponent).lineLimit(1)
                            Text(record.path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                            Text(FileManager.default.fileExists(atPath: record.path)
                                 ? (french ? "Présent (accès actuel non garanti)" : "Present (current access not verified)")
                                 : (french ? "Absent ou inaccessible" : "Missing or inaccessible"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(record.logicalBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
                             ?? (french ? "Taille inconnue" : "Size unknown"))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            Task { await remove(record) }
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(french ? "Retirer de la liste" : "Remove from list")
                    }
                    .padding(.vertical, 5)
                    Divider()
                }
            }
            if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
            Text(french ? "Les chemins sont conservés localement. L’état et la taille reflètent la dernière observation; choisissez à nouveau un dossier pour vérifier son contenu." : "Paths stay local. Status and size reflect the last observation; choose a folder again to verify its contents.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task { await load() }
    }

    @MainActor private func load() async {
        do { records = try await LocalStoreAccess.open().savedFiles(); status = nil }
        catch { status = french ? "Données locales indisponibles." : "Local data unavailable." }
    }

    @MainActor private func remove(_ record: SavedFileRecord) async {
        do {
            let store = try await LocalStoreAccess.open()
            try await store.removeSavedFile(path: record.path)
            records = try await store.savedFiles(); status = nil
        } catch { status = french ? "Élément non retiré." : "Item was not removed." }
    }
}
