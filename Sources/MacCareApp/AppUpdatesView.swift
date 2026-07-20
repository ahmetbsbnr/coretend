import SwiftUI
import AppDiscovery
import DesignSystem

/// App update detector. Detection only: reads each app's declared update
/// mechanism (Sparkle feed, App Store receipt) and opens the right place.
/// Never downloads binaries or bypasses code signing.
@MainActor
@Observable
final class AppUpdatesViewModel {
    struct UpdateInfo: Identifiable {
        let id: String
        let app: InstalledApp
        let source: AppUpdateSource
        let feedURL: URL?
    }

    enum Phase: Equatable { case loading, ready, empty }

    var phase: Phase = .loading
    var updates: [UpdateInfo] = []

    func load() async {
        phase = .loading
        let result = await Task.detached(priority: .utility) { () -> [UpdateInfo] in
            let apps = AppDiscovery().discoverApps()
            return apps.map { app in
                let (source, feed) = AppUpdateSource.detect(for: app)
                return UpdateInfo(id: app.id, app: app, source: source, feedURL: feed)
            }
            .sorted { ($0.source == .none ? 1 : 0, $0.app.name) < ($1.source == .none ? 1 : 0, $1.app.name) }
        }.value
        updates = result
        phase = result.isEmpty ? .empty : .ready
    }

    func open(_ info: UpdateInfo) {
        switch info.source {
        case .appStore:
            NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
        case .sparkle:
            // Open the app itself; Sparkle checks are driven by the app's own UI.
            NSWorkspace.shared.open(info.app.path)
        case .none:
            NSWorkspace.shared.activateFileViewerSelecting([info.app.path])
        }
    }
}

struct AppUpdatesView: View {
    @State private var model = AppUpdatesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .loading:
                ProgressView("Reading update mechanisms…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                Text("No applications found").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                List {
                    Section {
                        ForEach(model.updates) { info in
                            HStack {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: info.app.path.path))
                                    .resizable().frame(width: 24, height: 24)
                                VStack(alignment: .leading) {
                                    Text(info.app.name)
                                    Text("v\(info.app.version ?? "?") — \(info.source.rawValue)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(info.source == .appStore ? "Open App Store Updates"
                                       : info.source == .sparkle ? "Open App to Update"
                                       : "Reveal in Finder") {
                                    model.open(info)
                                }
                            }
                        }
                    } footer: {
                        Text("MacCare detects each app's own update channel and sends you there. It never downloads or replaces app binaries itself.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .listStyle(.inset)
            }
        }
        .task { await model.load() }
    }
}
