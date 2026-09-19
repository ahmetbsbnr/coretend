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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead
                checksBand
                IntegrityRule()
                findingsSection
                IntegrityRule()
                verifiedSection
            }
        }
        .task { await model.refresh() }
        .accessibilityIdentifier("integrity.report")
    }

    // MARK: Masthead

    /// What this module is allowed to claim, stated once and plainly. The
    /// previous version put the same sentence in caption grey above a list and
    /// left the rest of an 800-point window empty.
    private var masthead: some View {
        HStack(alignment: .center, spacing: MCSpacing.lg) {
            // Same as Overview: the module name is already in the toolbar.
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(L("integrity.explainer.body"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(MCColor.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: MCSpacing.md)
            Button(L("integrity.inspector.choose")) { chooseAppToInspect() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("integrity.inspect.choose")
        }
        .padding(.horizontal, MCSpacing.page)
        .padding(.top, MCSpacing.md)
        .padding(.bottom, MCSpacing.sm)
    }

    // MARK: Checks

    /// What was checked, and — the part that was missing entirely — what could
    /// not be checked and why. An integrity screen that only lists what it
    /// managed to read invites the reader to assume the rest is fine.
    private var checksBand: some View {
        HStack(spacing: 0) {
            ForEach(Array(checks.enumerated()), id: \.element.title) { index, check in
                if index > 0 {
                    Rectangle().fill(MCColor.separator.opacity(MCOpacity.hairline))
                        .frame(width: 1, height: 56)
                }
                VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                    HStack(spacing: MCSpacing.xxs) {
                        Image(systemName: check.icon)
                            .font(MCFont.caption.weight(.medium))
                            .foregroundStyle(check.unverified > 0 ? MCTheme.warning : MCColor.teal)
                        Text(check.title.uppercased())
                            .font(MCFont.groupHeader)
                            .foregroundStyle(MCColor.textSecondary)
                            .lineLimit(1)
                    }
                    Text(check.value)
                        .font(MCFont.displaySecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(MCColor.textPrimary)
                    // Amber on the glyph and on the figure that is actually a
                    // problem — not on the sentence explaining it. An
                    // integrity screen whose body text is amber reads as a
                    // permanent alert, which is the opposite of the calm,
                    // precise impression it should give.
                    Text(check.detail)
                        .font(MCFont.caption)
                        .foregroundStyle(MCColor.textSecondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, MCSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, MCSpacing.page - MCSpacing.sm)
        .padding(.vertical, MCSpacing.md)
        .background(MCColor.secondaryBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(MCColor.separator.opacity(MCOpacity.hairline)).frame(height: 1)
        }
    }

    private struct Check {
        let title: String
        let icon: String
        /// The headline figure, already formatted. A string rather than an Int
        /// because not every check counts things: reach is a state, and
        /// rendering it as "0" made a permission look like a tally of zero
        /// items rather than an answer to "how much of the disk did you see".
        let value: String
        let unverified: Int
        let detail: String
    }

    private var checks: [Check] {
        let noOrigin = model.downloads.filter { ProvenanceSummary.isUnknown($0) }.count
        let brokenItems = model.loginItems.filter { Self.isBroken($0) }.count
        let fullDisk = SystemAuthorization.probeLive().grant(for: .fullDisk) == .granted
        return [
            Check(title: L("integrity.check.downloads"), icon: "arrow.down.circle",
                  value: "\(model.downloads.count)", unverified: noOrigin,
                  detail: noOrigin > 0
                    ? L("integrity.check.downloads_unverified", noOrigin)
                    : L("integrity.check.all_have_origin")),
            Check(title: L("integrity.check.login_items"), icon: "power",
                  value: "\(model.loginItems.count)", unverified: brokenItems,
                  detail: brokenItems > 0
                    ? L("integrity.check.login_broken", brokenItems)
                    : L("integrity.check.login_ok")),
            Check(title: L("integrity.check.reach"), icon: "lock",
                  value: fullDisk ? L("integrity.reach.full") : L("integrity.reach.partial"),
                  unverified: fullDisk ? 0 : 1,
                  detail: fullDisk ? L("integrity.check.reach_full")
                                   : L("integrity.check.reach_limited")),
        ]
    }

    /// A login item whose program is gone. macOS still tries to start it.
    private static func isBroken(_ item: LoginItem) -> Bool {
        guard let path = item.programPath else { return false }
        return !FileManager.default.fileExists(atPath: path)
    }

    // MARK: Findings

    /// Only what is actually wrong. No score, no gauge, no invented overall
    /// status — an empty findings list says everything CoreTend looked at was
    /// in order, and says it by being empty rather than by printing a green
    /// badge that means nothing.
    private var findingsSection: some View {
        let noOrigin = model.downloads.filter { ProvenanceSummary.isUnknown($0) }
        let broken = model.loginItems.filter { Self.isBroken($0) }
        return VStack(alignment: .leading, spacing: MCSpacing.sm) {
            IntegritySectionTitle(title: L("integrity.section.findings"),
                                  subtitle: L("integrity.section.findings_detail"))
            if noOrigin.isEmpty && broken.isEmpty {
                Text(L("integrity.section.findings_none"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(MCColor.textSecondary)
                    .padding(.vertical, MCSpacing.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(broken) { item in
                        IntegrityFindingRow(
                            icon: "power",
                            title: item.label,
                            reason: L("integrity.finding.login_missing_program"),
                            evidence: item.programPath ?? item.plistPath,
                            revealPath: item.plistPath)
                    }
                    ForEach(noOrigin) { item in
                        IntegrityFindingRow(
                            icon: "questionmark.circle",
                            title: item.name,
                            reason: L("integrity.finding.no_origin"),
                            evidence: PathDisplay.folder(of: URL(fileURLWithPath: item.path)),
                            revealPath: item.path)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: MCRadius.card, style: .continuous))
            }
        }
        .padding(.horizontal, MCSpacing.page)
        .padding(.vertical, MCSpacing.lg)
    }

    // MARK: Verified

    /// The evidence behind the counts above: what CoreTend read and what it
    /// found. Kept below the findings, because "here is everything that is
    /// fine" is reference material, not the answer to the question.
    private var verifiedSection: some View {
        let known = model.downloads.filter { !ProvenanceSummary.isUnknown($0) }
        return VStack(alignment: .leading, spacing: MCSpacing.sm) {
            IntegritySectionTitle(title: L("integrity.section.verified"),
                                  subtitle: L("integrity.section.verified_detail"))
            if let inspected = model.inspectedApp {
                signatureRow(name: inspected.url.lastPathComponent, info: inspected.info)
                    .padding(.vertical, MCSpacing.xs)
            }
            VStack(spacing: 0) {
                ForEach(Array(known.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: MCSpacing.sm) {
                        Image(systemName: item.isQuarantined ? "checkmark.shield" : "doc")
                            .font(MCFont.caption)
                            .foregroundStyle(item.isQuarantined ? MCTheme.success : MCColor.textTertiary)
                            .frame(width: 16).accessibilityHidden(true)
                        Text(item.name).font(MCFont.rowTitle).lineLimit(1)
                        Spacer(minLength: MCSpacing.sm)
                        Text(ProvenanceSummary.acquisition(for: item) ?? "")
                            .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                            .lineLimit(evidenceLineLimit)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, MCSpacing.sm)
                    .padding(.vertical, MCSpacing.xs)
                    .background(index.isMultiple(of: 2)
                                ? MCColor.secondaryBackground.opacity(0.6) : Color.clear)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L("integrity.row_a11y", item.name,
                                          ProvenanceSummary.acquisition(for: item) ?? L("integrity.downloads.no_provenance"),
                                          item.isQuarantined ? L("integrity.a11y.quarantined") : L("integrity.a11y.not_quarantined")))
                    .contextMenu {
                        Button(L("common.reveal_in_finder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                        }
                        // Restored: the rebuild dropped this with the old list,
                        // which quietly removed the only way to inspect a
                        // downloaded app's signature without the file picker.
                        if item.path.hasSuffix(".app") {
                            Button(L("integrity.inspect_this")) {
                                model.inspect(URL(fileURLWithPath: item.path))
                            }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: MCRadius.card, style: .continuous))
        }
        .padding(.horizontal, MCSpacing.page)
        .padding(.bottom, MCSpacing.xl)
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

private struct IntegrityRule: View {
    var body: some View {
        Rectangle().fill(MCColor.separator.opacity(MCOpacity.hairline)).frame(height: 1)
    }
}

private struct IntegritySectionTitle: View {
    let title: String
    let subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(MCFont.sectionTitle).foregroundStyle(MCColor.textPrimary)
            if let subtitle {
                Text(subtitle).font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One concrete problem: what it is, why it is a problem, and the evidence.
/// Never a severity score — the reason is the severity.
private struct IntegrityFindingRow: View {
    let icon: String
    let title: String
    let reason: String
    let evidence: String
    let revealPath: String
    @State private var hovered = false

    var body: some View {
        HStack(alignment: .top, spacing: MCSpacing.sm) {
            Image(systemName: icon)
                .font(MCFont.caption.weight(.medium))
                .foregroundStyle(MCTheme.warning)
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(MCFont.rowTitle).lineLimit(1)
                Text(reason).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                Text(evidence).font(MCFont.monoCaption)
                    .foregroundStyle(MCColor.textTertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: MCSpacing.sm)
            // A real button, always present. Hover is never the only way to
            // reach an action.
            Button(L("common.reveal_in_finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: revealPath)])
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, MCSpacing.sm)
        .padding(.vertical, MCSpacing.xs)
        // A neutral surface with an amber edge, not an amber wash.
        //
        // Comparing Light and Dark side by side: amber at 0.07 over the dark
        // ground read as a tint, and over the light ground read as nothing at
        // all — the findings block was indistinguishable from the page. A
        // colour whose visibility depends on which appearance it lands in is
        // not carrying the meaning it was chosen for. The edge does, in both.
        .background(hovered ? MCColor.textPrimary.opacity(MCOpacity.hoverWash) : MCColor.secondaryBackground)
        .overlay(alignment: .leading) {
            Rectangle().fill(MCTheme.warning).frame(width: 3)
        }
        .onHover { hovered = $0 }
        .accessibilityElement(children: .contain)
    }
}
