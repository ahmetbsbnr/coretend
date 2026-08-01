import SwiftUI
import IntegrityCore
import DesignSystem

@MainActor
@Observable
final class IntegrityViewModel {
    var downloads: [DownloadProvenance] = []
    var loginItems: [LoginItem] = []
    var isLoading = false
    var inspectedApp: (url: URL, info: CodeSignInfo)?

    func refresh() async {
        isLoading = true
        let home = FileManager.default.homeDirectoryForCurrentUser
        downloads = ProvenanceScanner.scan(folder: home.appendingPathComponent("Downloads"))
        loginItems = LoginItemScanner.scan()
        isLoading = false
    }

    func inspect(_ url: URL) {
        inspectedApp = (url, CodeSignInspector.inspect(at: url))
    }
}

struct ProtectionView: View {
    var body: some View {
        TabView {
            IntegrityView()
                .tabItem { Label(L("protection.tab.integrity"), systemImage: "checkmark.seal") }
            PrivacyCleanerView()
                .tabItem { Label(L("protection.tab.privacy"), systemImage: "hand.raised") }
        }
        .padding(8)
        .navigationTitle(L("module.protection"))
        .accessibilityIdentifier("integrity.root")
    }
}

/// Native macOS integrity signals: where downloads came from, whether an app
/// is signed and by whom, and what launches automatically. No scanning
/// engine, no signature database, no third-party binary — everything here
/// reads metadata macOS itself already recorded. See
/// `Documentation/CLAMAV_DECISION.md` for why this replaced the prior
/// ClamAV-based malware tab.
struct IntegrityView: View {
    @State private var model = IntegrityViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                explainerCard
                downloadsCard
                inspectorCard
                loginItemsCard
            }
            .padding(24)
        }
        .task { await model.refresh() }
    }

    private var explainerCard: some View {
        MCCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "info.circle").font(.title2).foregroundStyle(MCTheme.accent)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("integrity.explainer.title")).font(MCFont.cardTitle)
                    Text(L("integrity.explainer.body")).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var downloadsCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: 10) {
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
                        VStack(alignment: .leading, spacing: 2) {
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
    }

    private var inspectorCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: 10) {
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
                if let inspected = model.inspectedApp {
                    signatureRow(name: inspected.url.lastPathComponent, info: inspected.info)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            VStack(alignment: .leading, spacing: 2) {
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
            VStack(alignment: .leading, spacing: 8) {
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
    }
}
