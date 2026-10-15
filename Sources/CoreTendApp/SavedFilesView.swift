import SwiftUI
import Persistence
import AppShell
import DesignSystem

struct SavedFilesView: View {
    let french: Bool
    @State private var records: [SavedFileRecord] = []
    @State private var status: String?
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(ProductCopy.inline("Favoris et récents", "Favorites and recent files", french: french))
                    .font(CoreTendTypography.sectionTitle)
                    .foregroundStyle(Palette.ink.color)
                Spacer()
                Button { Task { await load() } } label: {
                    Label(ProductCopy.inline("Actualiser", "Refresh", french: french), systemImage: "arrow.clockwise")
                }
                .disabled(loading)
            }
            if loading && records.isEmpty {
                ProgressView(ProductCopy.inline("Chargement des fichiers enregistrés", "Loading saved files", french: french))
            } else if records.isEmpty && status == nil {
                SerreParcel {
                    SerreEmptyState(title: ProductCopy.inline("Aucun fichier enregistré", "No saved files", french: french),
                                    message: french
                                        ? "Ajoutez un favori dans Explorer ou activez l’historique récent dans Réglages."
                                        : "Add a favorite in Explore or enable recent history in Settings.")
                }
            } else if records.isEmpty, let status {
                SerreBanner(.error, title: status)
            } else {
                ForEach(records, id: \.path) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(URL(fileURLWithPath: record.path).lastPathComponent,
                              systemImage: record.isFavorite ? "star.fill" : "clock")
                            .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                        Text(record.path)
                            .font(CoreTendTypography.secondary.monospaced())
                            .foregroundStyle(Palette.secondaryInk.color)
                            .textSelection(.enabled)
                        Text(ProductCopy.savedFileAvailability(
                            isPresent: FileManager.default.fileExists(atPath: record.path),
                            french: french
                        ))
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                        Text((ProductCopy.inline("Dernière observation : ", "Last observed: ", french: french)) +
                             record.lastSeenAt.formatted(.dateTime.day().month().year().hour().minute()))
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                        Text(record.isFavorite ? (ProductCopy.inline("Favori", "Favorite", french: french)) : (ProductCopy.inline("Récent", "Recent", french: french)))
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.accent.color)
                        Text(record.logicalBytes.map { ProductFormat.bytes($0, french: french) }
                             ?? (ProductCopy.inline("Taille inconnue", "Size unknown", french: french)))
                            .font(CoreTendTypography.secondary.monospacedDigit())
                            .foregroundStyle(Palette.secondaryInk.color)
                        Button(role: .destructive) {
                            Task { await remove(record) }
                        } label: { Label(ProductCopy.inline("Retirer", "Remove", french: french), systemImage: "trash") }
                            .buttonStyle(.borderless)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface.color, in: LeafCorner.parcel.shape)
                }
            }
            if let status, !records.isEmpty {
                SerreBanner(.partial, title: status)
            }
            Text(ProductCopy.inline("Les chemins sont conservés localement. L’état et la taille reflètent la dernière observation; choisissez à nouveau un dossier pour vérifier son contenu.", "Paths stay local. Status and size reflect the last observation; choose a folder again to verify its contents.", french: french))
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .motion(.standard, value: records)
        .task { await load() }
    }

    @MainActor private func load() async {
        loading = true
        defer { loading = false }
        do { records = try await LocalStoreAccess.open().savedFiles(); status = nil }
        catch { status = ProductCopy.inline("Données locales indisponibles.", "Local data unavailable.", french: french) }
    }

    @MainActor private func remove(_ record: SavedFileRecord) async {
        do {
            let store = try await LocalStoreAccess.open()
            try await store.removeSavedFile(path: record.path)
            records = try await store.savedFiles(); status = nil
        } catch { status = ProductCopy.inline("Élément non retiré.", "Item was not removed.", french: french) }
    }
}
