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

    /// Provenance: where recent downloads came from, and what an app's
    /// signature says. One dense list, one sentence of explanation, one
    /// button to inspect any app. Login items moved to the "Starts at login"
    /// tab, where they sit beside launch agents — the same question asked of
    /// two mechanisms.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: MCSpacing.md) {
                // No .fixedSize here. Phase 1 bisected a blank sidebar to a
                // .fixedSize in a detail column, and this header reproduced it
                // exactly: the split view starved the sidebar to nothing.
                Text(L("integrity.explainer.body")).font(MCFont.caption)
                    .foregroundStyle(MCColor.textSecondary)
                    .lineLimit(2)
                Spacer()
                Button(L("integrity.inspector.choose")) { chooseAppToInspect() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("integrity.inspect.choose")
            }
            .padding(.horizontal, MCSpacing.page).padding(.vertical, MCSpacing.sm)
            if let inspected = model.inspectedApp {
                Divider()
                signatureRow(name: inspected.url.lastPathComponent, info: inspected.info)
                    .padding(.horizontal, MCSpacing.page).padding(.vertical, MCSpacing.xs)
            }
            Divider()
            if model.downloads.isEmpty && !model.isLoading {
                MCEmptyState(icon: "arrow.down.circle", title: L("integrity.downloads.title"),
                             message: L("integrity.downloads.empty"))
            } else {
                List(model.downloads) { item in
                    HStack(spacing: MCSpacing.xs) {
                        Image(systemName: item.isQuarantined ? "checkmark.shield" : "doc")
                            .foregroundStyle(item.isQuarantined ? MCTheme.success : MCColor.textTertiary)
                            .frame(width: 16).accessibilityHidden(true)
                        Text(item.name).lineLimit(1)
                        if let location = ProvenanceSummary.location(for: item) {
                            Text(location).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        Spacer(minLength: MCSpacing.xs)
                        Text(ProvenanceSummary.acquisition(for: item)
                             ?? (ProvenanceSummary.isUnknown(item) ? L("integrity.downloads.no_provenance") : ""))
                            .font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
                            .lineLimit(evidenceLineLimit)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L("integrity.row_a11y", item.name,
                                          ProvenanceSummary.acquisition(for: item) ?? L("integrity.downloads.no_provenance"),
                                          item.isQuarantined ? L("integrity.a11y.quarantined") : L("integrity.a11y.not_quarantined")))
                    .contextMenu {
                        Button(L("common.reveal_in_finder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                        }
                        if item.path.hasSuffix(".app") {
                            Button(L("integrity.inspect_this")) { model.inspect(URL(fileURLWithPath: item.path)) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 28)
                .accessibilityIdentifier("integrity.downloads")
            }
        }
        .task { await model.refresh() }
    }

    private func chooseAppToInspect() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url { model.inspect(url) }
    }

    @ViewBuilder
    private func signatureRow(name: String, info: CodeSignInfo) -> some View {
        let (icon, color, label): (String, Color, String) = switch info.tier {
        case .appleSigned: ("checkmark.seal.fill", MCTheme.success, L("integrity.tier.apple"))
        case .teamSigned: ("checkmark.seal.fill", MCTheme.success, L("integrity.tier.team", info.teamIdentifier ?? "?"))
        case .adHocOrUnsigned: ("exclamationmark.triangle.fill", MCTheme.warning, L("integrity.tier.unsigned"))
        }
        HStack(alignment: .top) {
            Image(systemName: icon).foregroundStyle(color).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(name).font(MCFont.rowTitle)
                Text(label).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                if !info.signatureValid {
                    Text(L("integrity.tier.invalid")).font(MCFont.caption).foregroundStyle(MCTheme.danger)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(label)\(info.signatureValid ? "" : ", " + L("integrity.tier.invalid"))")
    }

}
