// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import IntegrityCore
import DesignSystem
import Persistence

/// Resolves every filesystem location read by Integrity. A normal launch uses
/// the real macOS locations. A test launch may only use a validated temporary
/// store root; if that validation fails, Integrity reads nothing rather than
/// silently falling back to personal Downloads or login items.
struct IntegrityScanLocations {
    let downloads: URL?
    let loginItems: [(URL, LoginItem.Scope)]

    static func resolve(
        environment: [String: String],
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> IntegrityScanLocations {
        if TestStoreOverride.isTestMarkerSet(environment: environment) {
            guard let temporaryRoot = TestStoreOverride.resolve(environment: environment).directory else {
                return IntegrityScanLocations(downloads: nil, loginItems: [])
            }
            let fixtures = temporaryRoot.appendingPathComponent("IntegrityFixtures", isDirectory: true)
            return IntegrityScanLocations(
                downloads: fixtures.appendingPathComponent("Downloads", isDirectory: true),
                loginItems: [
                    (fixtures.appendingPathComponent("UserLaunchAgents", isDirectory: true), .userAgent),
                    (fixtures.appendingPathComponent("GlobalLaunchAgents", isDirectory: true), .globalAgent),
                    (fixtures.appendingPathComponent("GlobalLaunchDaemons", isDirectory: true), .globalDaemon),
                ]
            )
        }

        return IntegrityScanLocations(
            downloads: home.appendingPathComponent("Downloads", isDirectory: true),
            loginItems: [
                (home.appendingPathComponent("Library/LaunchAgents", isDirectory: true), .userAgent),
                (URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true), .globalAgent),
                (URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true), .globalDaemon),
            ]
        )
    }
}

@MainActor
@Observable
final class IntegrityViewModel {
    var downloads: [DownloadProvenance] = []
    var loginItems: [LoginItem] = []
    var isLoading = false
    var inspectedApp: (url: URL, info: CodeSignInfo)?

    func refresh() async {
        isLoading = true
        let locations = IntegrityScanLocations.resolve(environment: ProcessInfo.processInfo.environment)
        downloads = locations.downloads.map { ProvenanceScanner.scan(folder: $0) } ?? []
        loginItems = LoginItemScanner.scan(locations: locations.loginItems)
        isLoading = false
    }

    func inspect(_ url: URL) {
        inspectedApp = (url, CodeSignInspector.inspect(at: url))
    }
}

struct ProtectionView: View {
    @State private var tab = 0

    var body: some View {
        ModuleSubNav(sections: [
            .init(0, L("protection.tab.integrity")),
            .init(1, L("protection.tab.startup")),
        ], selection: $tab) { tab in
            if tab == 0 { IntegrityView() } else { StartupItemsView() }
        }
        .navigationTitle(L("module.protection"))
        .accessibilityIdentifier("integrity.root")
    }
}

/// Native macOS integrity signals: where downloads came from, whether an app
/// is signed and by whom, and what launches automatically. No scanning
/// engine, no signature database, no third-party binary — everything here
/// reads metadata macOS itself already recorded. See
/// The compatibility shell does not claim malware detection; current
/// integrity checks are local and informational.
struct IntegrityView: ModuleSubScreen {
    static let parent = ModuleID.protection
    static let labelKey = "protection.tab.integrity"

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Evidence lines wrap instead of truncating once text is large enough
    /// that a single line would cut them short. Typed explicitly: an inline
    /// `? nil : 1` inside a view builder leaves the compiler unable to infer
    /// the surrounding ForEach.
    private var evidenceLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }
    @State private var model = IntegrityViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.md) {
                explainerCard
                downloadsCard
                inspectorCard
                loginItemsCard
            }
            .padding(MCSpacing.page)
        }
        .task { await model.refresh() }
    }

    private var explainerCard: some View {
        MCCard {
            HStack(alignment: .top, spacing: MCSpacing.md) {
                Image(systemName: "info.circle").font(MCFont.pageTitle).foregroundStyle(MCTheme.accent)
                VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                    Text(L("integrity.explainer.title")).font(MCFont.cardTitle)
                    Text(L("integrity.explainer.body")).foregroundStyle(MCColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var downloadsCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                HStack {
                    Text(L("integrity.downloads.title")).font(MCFont.cardTitle)
                    Spacer()
                    if model.isLoading { ProgressView().controlSize(.small) }
                }
                if model.downloads.isEmpty && !model.isLoading {
                    Text(L("integrity.downloads.empty")).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                }
                ForEach(model.downloads.prefix(25)) { item in
                    HStack(alignment: .top) {
                        Image(systemName: item.isQuarantined ? "shield.checkerboard" : "doc")
                            .foregroundStyle(item.isQuarantined ? MCTheme.accent : .secondary)
                        VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                            Text(item.name).font(MCFont.rowTitle).lineLimit(1)
                            if let location = ProvenanceSummary.location(for: item) {
                                Text(location).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                            // Which app brought the file in and when. macOS
                            // records this for almost everything, and the list
                            // showed none of it — see ProvenanceSummary.
                            if let acquisition = ProvenanceSummary.acquisition(for: item) {
                                Text(acquisition).font(MCFont.micro).foregroundStyle(MCColor.textTertiary)
                                    // Wraps rather than truncates at
                                    // accessibility sizes — see CleanupView.
                                    .lineLimit(evidenceLineLimit)
                            }
                            if ProvenanceSummary.isUnknown(item) {
                                Text(L("integrity.downloads.no_provenance"))
                                    .font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
                            }
                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                        } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(L("common.reveal_in_finder"))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("integrity.downloads")
    }

    private var inspectorCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                Text(L("integrity.inspector.title")).font(MCFont.cardTitle)
                Text(L("integrity.inspector.subtitle")).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                Button(L("integrity.inspector.choose")) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.application]
                    panel.directoryURL = URL(fileURLWithPath: "/Applications")
                    if panel.runModal() == .OK, let url = panel.url {
                        model.inspect(url)
                    }
                }
                .accessibilityIdentifier("integrity.inspect.choose")
                if let inspected = model.inspectedApp {
                    signatureRow(name: inspected.url.lastPathComponent, info: inspected.info)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("integrity.inspector")
    }

    @ViewBuilder
    private func signatureRow(name: String, info: CodeSignInfo) -> some View {
        let (icon, color, label): (String, Color, String) = switch info.tier {
        case .appleSigned: ("checkmark.seal.fill", MCTheme.success, L("integrity.tier.apple"))
        case .teamSigned: ("checkmark.seal.fill", MCTheme.success, L("integrity.tier.team", info.teamIdentifier ?? "?"))
        case .adHocOrUnsigned: ("exclamationmark.triangle.fill", MCTheme.warning, L("integrity.tier.unsigned"))
        }
        HStack(alignment: .top) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(name).font(MCFont.rowTitle)
                Text(label).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                if !info.signatureValid {
                    Text(L("integrity.tier.invalid")).font(MCFont.caption).foregroundStyle(MCTheme.danger)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var loginItemsCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                Text(L("integrity.login_items.title")).font(MCFont.cardTitle)
                Text(L("integrity.login_items.subtitle")).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                if model.loginItems.isEmpty && !model.isLoading {
                    Text(L("integrity.login_items.empty")).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                }
                ForEach(model.loginItems) { item in
                    HStack {
                        Image(systemName: "power").foregroundStyle(MCColor.textSecondary)
                        VStack(alignment: .leading) {
                            Text(item.label).font(MCFont.rowTitle).lineLimit(1)
                            if let program = item.programPath {
                                Text(program).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                        }
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("integrity.login_items")
    }
}
