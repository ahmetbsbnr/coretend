import SwiftUI
import Persistence
import DesignSystem

extension Notification.Name {
    /// Carries a `URL` (the folder to scan) as `object`. Distinct from
    /// `.mcNavigate` (which only ever carries a `ModuleID`) so Space Lens can
    /// tell "switch to me" apart from "switch to me and start scanning this".
    static let mcOpenSpaceLensAt = Notification.Name("mc.openSpaceLensAt")
}

/// A folder CoreTend can jump straight into scanning: one of the three fixed
/// quick links (Downloads/Desktop/Documents), a user favorite, or both at
/// once — `isQuickLink`/`record.isFavorite` aren't mutually exclusive.
struct FavoriteLocation: Identifiable {
    let path: String
    let isQuickLink: Bool
    let record: LocationRecord?

    var id: String { path }
    var isFavorite: Bool { record?.isFavorite ?? false }
    var lastScanned: Date? { record?.lastScanned }
    var lastBytes: Int64? { record?.lastBytes }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
    var isReadable: Bool { FileManager.default.isReadableFile(atPath: path) }
    var displayName: String { URL(fileURLWithPath: path).lastPathComponent }
}

@MainActor
@Observable
final class FavoritesRecentsViewModel {
    enum Phase: Equatable { case loading, loaded, failed(String) }

    var phase: Phase = .loading
    private(set) var favorites: [LocationRecord] = []
    private(set) var recents: [LocationRecord] = []

    /// Downloads/Desktop/Documents, shown unconditionally regardless of
    /// favorite status — a genuinely absent one (renamed, on a volume that
    /// never mounted) still renders, just marked unreachable rather than hidden.
    var quickLinks: [FavoriteLocation] {
        [
            FileManager.SearchPathDirectory.downloadsDirectory,
            .desktopDirectory,
            .documentDirectory,
        ].compactMap { dir in
            guard let url = FileManager.default.urls(for: dir, in: .userDomainMask).first else { return nil }
            let path = url.path
            return FavoriteLocation(path: path, isQuickLink: true,
                                     record: favorites.first { $0.path == path })
        }
    }

    var favoriteLocations: [FavoriteLocation] {
        let quickPaths = Set(quickLinks.map(\.path))
        return Self.excludingQuickLinks(favorites, quickLinkPaths: quickPaths)
            .map { FavoriteLocation(path: $0.path, isQuickLink: false, record: $0) }
    }

    /// A quick link the user also favorited already renders (starred) in the
    /// Quick Links section; repeating it under Favorites would just be the
    /// same folder twice on screen. Pure so it's directly testable without
    /// standing up a Store.
    nonisolated static func excludingQuickLinks(_ favorites: [LocationRecord], quickLinkPaths: Set<String>) -> [LocationRecord] {
        favorites.filter { !quickLinkPaths.contains($0.path) }
    }

    var recentLocations: [FavoriteLocation] {
        recents.map { FavoriteLocation(path: $0.path, isQuickLink: false, record: $0) }
    }

    func load() async {
        guard let store = AppEnvironment.shared.store else {
            phase = .failed(L("favrec.error_no_store"))
            return
        }
        do {
            favorites = try await store.favorites()
            recents = try await store.recents(limit: 10)
            phase = .loaded
        } catch {
            phase = .failed("\(error)")
        }
    }

    func addFavorite(_ url: URL) async {
        guard let store = AppEnvironment.shared.store else { return }
        try? await store.addFavorite(path: url.path)
        await load()
    }

    func removeFavorite(_ path: String) async {
        guard let store = AppEnvironment.shared.store else { return }
        try? await store.removeFavorite(path: path)
        await load()
    }

    func removeRecent(_ path: String) async {
        guard let store = AppEnvironment.shared.store else { return }
        try? await store.removeRecent(path: path)
        await load()
    }

    func analyze(_ path: String) {
        NotificationCenter.default.post(name: .mcOpenSpaceLensAt, object: URL(fileURLWithPath: path))
    }
}

struct FavoritesRecentsView: View {
    @State private var model = FavoritesRecentsViewModel()

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                MCEmptyState(icon: "exclamationmark.triangle", title: L("favrec.error_title"), message: message)
            case .loaded:
                loadedView
            }
        }
        .navigationTitle(L("favrec.title"))
        .toolbar {
            Button {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    Task { await model.addFavorite(url) }
                }
            } label: {
                Label(L("favrec.add_favorite"), systemImage: "star")
            }
        }
        .task { await model.load() }
    }

    private var loadedView: some View {
        List {
            Section(L("favrec.section_quicklinks")) {
                ForEach(model.quickLinks) { location in
                    LocationRow(location: location, model: model)
                }
            }
            Section(L("favrec.section_favorites")) {
                if model.favoriteLocations.isEmpty {
                    Text(L("favrec.empty_favorites")).foregroundStyle(.secondary)
                }
                ForEach(model.favoriteLocations) { location in
                    LocationRow(location: location, model: model)
                }
            }
            Section(L("favrec.section_recents")) {
                if model.recentLocations.isEmpty {
                    Text(L("favrec.empty_recents")).foregroundStyle(.secondary)
                }
                ForEach(model.recentLocations) { location in
                    LocationRow(location: location, model: model)
                }
            }
        }
        .listStyle(.inset)
    }
}

private struct LocationRow: View {
    let location: FavoriteLocation
    let model: FavoritesRecentsViewModel

    var body: some View {
        HStack(spacing: MCSpacing.sm) {
            Image(systemName: location.isFavorite ? "star.fill" : "folder")
                .foregroundStyle(location.isFavorite ? MCTheme.warning : MCTheme.accentSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(location.displayName).lineLimit(1)
                Text(location.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                statusLine
            }
            Spacer()
            if location.exists && location.isReadable {
                Button(L("favrec.analyze")) { model.analyze(location.path) }
                    .buttonStyle(.bordered)
            }
            if !location.isQuickLink {
                Button(role: .destructive) {
                    Task {
                        if location.isFavorite { await model.removeFavorite(location.path) }
                        else { await model.removeRecent(location.path) }
                    }
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L("favrec.remove", location.displayName))
            } else if location.isFavorite {
                Button(role: .destructive) {
                    Task { await model.removeFavorite(location.path) }
                } label: {
                    Image(systemName: "star.slash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L("favrec.unfavorite", location.displayName))
            } else {
                Button {
                    Task { await model.addFavorite(URL(fileURLWithPath: location.path)) }
                } label: {
                    Image(systemName: "star")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L("favrec.favorite", location.displayName))
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusLine: some View {
        if !location.exists {
            Text(L("favrec.status_missing")).font(.caption2).foregroundStyle(MCTheme.danger)
        } else if !location.isReadable {
            Text(L("favrec.status_no_access")).font(.caption2).foregroundStyle(MCTheme.warning)
        } else if let date = location.lastScanned, let bytes = location.lastBytes {
            Text(L("favrec.status_last_scanned", date.formatted(date: .abbreviated, time: .shortened), mcFormatBytes(bytes)))
                .font(.caption2).foregroundStyle(.secondary)
        } else {
            Text(L("favrec.status_never_scanned")).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
