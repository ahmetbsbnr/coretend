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
                Text(french ? "Favoris et récents" : "Favorites and recent files")
                    .font(CoreTendTypography.sectionTitle)
                    .foregroundStyle(Palette.ink.color)
                Spacer()
                Button { Task { await load() } } label: {
                    Label(french ? "Actualiser" : "Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(loading)
            }
            if loading && records.isEmpty {
                ProgressView(french ? "Chargement des fichiers enregistrés" : "Loading saved files")
            } else if records.isEmpty && status == nil {
                SerreParcel {
                    SerreEmptyState(title: french ? "Aucun fichier enregistré" : "No saved files",
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
                        // In the App Sandbox a path outside the chosen folders cannot be checked: say nothing
                        // rather than call a present file missing.
                        if !SandboxAccess.isSandboxed {
                            Text(ProductCopy.savedFileAvailability(
                                isPresent: FileManager.default.fileExists(atPath: record.path),
                                french: french
                            ))
                                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                        }
                        Text((french ? "Dernière observation : " : "Last observed: ") +
                             record.lastSeenAt.formatted(.dateTime.day().month().year().hour().minute()))
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                        Text(record.isFavorite ? (french ? "Favori" : "Favorite") : (french ? "Récent" : "Recent"))
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.accent.color)
                        Text(record.logicalBytes.map { ProductFormat.bytes($0, french: french) }
                             ?? (french ? "Taille inconnue" : "Size unknown"))
                            .font(CoreTendTypography.secondary.monospacedDigit())
                            .foregroundStyle(Palette.secondaryInk.color)
                        Button(role: .destructive) {
                            Task { await remove(record) }
                        } label: { Label(french ? "Retirer" : "Remove", systemImage: "trash") }
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
            Text(french ? "Les chemins sont conservés localement. L’état et la taille reflètent la dernière observation; choisissez à nouveau un dossier pour vérifier son contenu." : "Paths stay local. Status and size reflect the last observation; choose a folder again to verify its contents.")
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
