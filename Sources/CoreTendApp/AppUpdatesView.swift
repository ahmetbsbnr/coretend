// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

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
    }

    enum Phase: Equatable { case loading, ready, empty }

    var phase: Phase = .loading
    var updates: [UpdateInfo] = []

    func load() async {
        phase = .loading
        let discovery = ApplicationInventoryLocations.resolve(
            environment: ProcessInfo.processInfo.environment
        ).discovery
        let result = await Task.detached(priority: .utility) { () -> [UpdateInfo] in
            let apps = discovery.discoverApps()
            return apps.map { app in
                let (source, _) = AppUpdateSource.detect(for: app)
                return UpdateInfo(id: app.id, app: app, source: source)
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
        case .homebrew, .none:
            // Homebrew updates run from the user's own terminal (`brew upgrade`);
            // we never shell out to brew, so reveal the app rather than overpromise.
            NSWorkspace.shared.activateFileViewerSelecting([info.app.path])
        }
    }
}

struct AppUpdatesView: ModuleSubScreen {
    /// Reached from applications's sub-navigation, which already owns
    /// the window title — so this view deliberately sets none.
    static let parent = ModuleID.applications
    static let labelKey = "apps.tab.updates"

    @State private var model = AppUpdatesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .loading:
                ProgressView(L("updates.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                Text(L("apps.empty")).foregroundStyle(MCColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                List {
                    Section {
                        ForEach(model.updates) { info in
                            HStack(spacing: MCSpacing.xs) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: info.app.path.path))
                                    .resizable().frame(width: 16, height: 16)
                                    .accessibilityHidden(true)
                                Text(info.app.name).lineLimit(1)
                                Text(L("updates.version_source", info.app.version ?? "?", info.source.rawValue))
                                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: MCSpacing.xs)
                                Button(info.source == .appStore ? L("updates.open_app_store")
                                       : info.source == .sparkle ? L("updates.open_app")
                                       : L("common.reveal_in_finder")) {
                                    model.open(info)
                                }
                                .buttonStyle(.bordered).controlSize(.small)
                                .accessibilityHint(L("updates.action_hint", info.app.name))
                            }
                            .accessibilityElement(children: .contain)
                        }
                    } footer: {
                        Text(L("updates.footer"))
                            .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 28)
            }
        }
        .task { await model.load() }
    }
}
