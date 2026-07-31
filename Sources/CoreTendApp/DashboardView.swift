import SwiftUI
import DesignSystem
import IntegrityCore
import Persistence
import SystemMetrics

struct DashboardView: View {
    @State private var snapshot: MetricsSnapshot?
    @State private var activity: [ActivityRecord] = []
    @State private var exclusions: [String] = []
    @State private var dryRunDefault = true
    @State private var signature = CodeSignInspector.inspect(at: Bundle.main.bundleURL)
    @State private var collector = MetricsCollector()

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 360), spacing: MCSpacing.md, alignment: .top),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                header
                statusStrip
                LazyVGrid(columns: columns, alignment: .leading, spacing: MCSpacing.md) {
                    actionTile(
                        id: "dashboard.storage",
                        title: L("dashboard.storage.title"),
                        detail: L("dashboard.storage.detail"),
                        icon: ModuleID.cleanup.systemImage,
                        module: .cleanup,
                        primary: true)
                    actionTile(
                        id: "dashboard.spacelens",
                        title: L("dashboard.spacelens.title"),
                        detail: L("dashboard.spacelens.detail"),
                        icon: ModuleID.spaceLens.systemImage,
                        module: .spaceLens)
                    actionTile(
                        id: "dashboard.duplicates",
                        title: L("dashboard.duplicates.title"),
                        detail: L("dashboard.duplicates.detail"),
                        icon: ModuleID.duplicates.systemImage,
                        module: .duplicates)
                    actionTile(
                        id: "dashboard.applications",
                        title: L("dashboard.applications.title"),
                        detail: L("dashboard.applications.detail"),
                        icon: ModuleID.applications.systemImage,
                        module: .applications)
                    actionTile(
                        id: "dashboard.integrity",
                        title: L("dashboard.integrity.title"),
                        detail: signatureStatusText,
                        icon: ModuleID.protection.systemImage,
                        module: .protection)
                    actionTile(
                        id: "dashboard.activity",
                        title: L("dashboard.activity.title"),
                        detail: latestActivityText,
                        icon: ModuleID.myActivity.systemImage,
                        module: .myActivity)
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MCColor.background)
        .navigationTitle(L("module.dashboard"))
        .accessibilityIdentifier("dashboard.root")
        .task { await refresh() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: MCSpacing.lg) {
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                Text(L("dashboard.title"))
                    .font(MCFont.pageTitle)
                Text(L("dashboard.subtitle"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: MCSpacing.md)
            HStack(spacing: MCSpacing.xs) {
                Button {
                    navigate(.cleanup)
                } label: {
                    Label(L("dashboard.primary_action"), systemImage: "internaldrive")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                Button {
                    navigate(.spaceLens)
                } label: {
                    Label(L("dashboard.secondary_action"), systemImage: "map")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }

    private var statusStrip: some View {
        HStack(spacing: MCSpacing.sm) {
            statusPill(
                L("dashboard.status.signature"),
                value: signatureStatusText,
                icon: "checkmark.seal",
                attention: signature.tier == .adHocOrUnsigned || !signature.signatureValid)
            statusPill(
                L("dashboard.status.safety"),
                value: dryRunDefault ? L("dashboard.status.dry_run") : L("dashboard.status.trash_enabled"),
                icon: dryRunDefault ? "eye" : "trash",
                attention: !dryRunDefault)
            statusPill(
                L("dashboard.status.exclusions"),
                value: L("dashboard.status.exclusion_count", exclusions.count),
                icon: "line.3.horizontal.decrease.circle",
                attention: false)
            statusPill(
                L("dashboard.status.free_space"),
                value: snapshot.map { mcFormatBytes($0.diskFreeBytes) } ?? L("dashboard.status.loading"),
                icon: "internaldrive",
                attention: (snapshot?.diskFreeBytes ?? 20_000_000_000) < 20_000_000_000)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionTile(id: String, title: String, detail: String, icon: String,
                            module: ModuleID, primary: Bool = false) -> some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(primary ? MCColor.coreMint : .secondary)
                        .frame(width: 24)
                    Text(title)
                        .font(MCFont.cardTitle)
                    Spacer()
                    Button {
                        navigate(module)
                    } label: {
                        Image(systemName: "arrow.right")
                    }
                    .buttonStyle(.borderless)
                    .help(L("dashboard.open_module", module.label))
                    .accessibilityLabel(L("dashboard.open_module", module.label))
                }
                Text(detail)
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        }
        .accessibilityIdentifier(id)
    }

    private func statusPill(_ title: String, value: String, icon: String, attention: Bool) -> some View {
        HStack(spacing: MCSpacing.xs) {
            Image(systemName: attention ? "exclamationmark.triangle.fill" : icon)
                .foregroundStyle(attention ? MCTheme.warning : MCColor.coreMint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(MCFont.badge)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(value)
                    .font(MCFont.secondaryBody)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .padding(.horizontal, MCSpacing.sm)
        .padding(.vertical, MCSpacing.xs)
        .background(MCColor.elevatedBackground, in: RoundedRectangle(cornerRadius: MCRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: MCRadius.small)
                .strokeBorder(MCColor.separator.opacity(0.8), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var signatureStatusText: String {
        switch signature.tier {
        case .appleSigned:
            return L("dashboard.signature.apple")
        case .teamSigned:
            return L("dashboard.signature.team", signature.teamIdentifier ?? "?")
        case .adHocOrUnsigned:
            return L("dashboard.signature.unsigned")
        }
    }

    private var latestActivityText: String {
        guard let record = activity.first else { return L("dashboard.activity.empty") }
        return "\(record.summary) · \(record.date.formatted(date: .abbreviated, time: .shortened))"
    }

    private func refresh() async {
        async let latestSnapshot = collector.snapshot()
        if let store = AppEnvironment.shared.store {
            activity = (try? await store.activity(limit: 5)) ?? []
            exclusions = (try? await store.exclusions()) ?? []
            dryRunDefault = AppEnvironment.dryRunEnabled(fromSetting: try? await store.setting("dryRunDefault"))
        }
        snapshot = await latestSnapshot
        signature = CodeSignInspector.inspect(at: Bundle.main.bundleURL)
    }

    private func navigate(_ module: ModuleID) {
        NotificationCenter.default.post(name: .mcNavigate, object: module)
    }
}
