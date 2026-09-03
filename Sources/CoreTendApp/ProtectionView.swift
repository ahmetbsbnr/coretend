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

    // Plain segmented sub-nav rather than a TabView: a TabView as a
    // NavigationSplitView detail can intermittently blank the split view's
    // sidebar on macOS.
    var body: some View {
        Group {
            if tab == 0 { IntegrityView() } else { PrivacyCleanerView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text(L("protection.tab.integrity")).tag(0)
                    Text(L("protection.tab.privacy")).tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
                .padding(.vertical, MCSpacing.sm)
                Divider()
            }
            .frame(maxWidth: .infinity)
            .background(.bar)
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
struct IntegrityView: View {
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
                Image(systemName: "info.circle").font(.title2).foregroundStyle(MCTheme.accent)
                VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                    Text(L("integrity.explainer.title")).font(MCFont.cardTitle)
                    Text(L("integrity.explainer.body")).foregroundStyle(.secondary)
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
                    Text(L("integrity.downloads.empty")).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.downloads.prefix(25)) { item in
                    HStack(alignment: .top) {
                        Image(systemName: item.isQuarantined ? "shield.checkerboard" : "doc")
                            .foregroundStyle(item.isQuarantined ? MCTheme.accent : .secondary)
                        VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                            Text(item.name).font(.callout.weight(.medium)).lineLimit(1)
                            if let source = item.sourceURL {
                                Text(source).font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            } else {
                                Text(L("integrity.downloads.no_provenance"))
                                    .font(.caption).foregroundStyle(.tertiary)
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
                Text(L("integrity.inspector.subtitle")).font(.caption).foregroundStyle(.secondary)
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
                Text(name).font(.callout.weight(.medium))
                Text(label).font(.caption).foregroundStyle(.secondary)
                if !info.signatureValid {
                    Text(L("integrity.tier.invalid")).font(.caption).foregroundStyle(MCTheme.danger)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var loginItemsCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                Text(L("integrity.login_items.title")).font(MCFont.cardTitle)
                Text(L("integrity.login_items.subtitle")).font(.caption).foregroundStyle(.secondary)
                if model.loginItems.isEmpty && !model.isLoading {
                    Text(L("integrity.login_items.empty")).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.loginItems) { item in
                    HStack {
                        Image(systemName: "power").foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(item.label).font(.callout.weight(.medium)).lineLimit(1)
                            if let program = item.programPath {
                                Text(program).font(.caption).foregroundStyle(.secondary)
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
