import SwiftUI
import DesignSystem
import IntegrityCore
import Persistence
import SystemMetrics

struct DashboardView: View {
    @State private var snapshot: MetricsSnapshot?
    @State private var activity: [ActivityRecord] = []
    @State private var exclusions: [String] = []
    @State private var signature = CodeSignInspector.inspect(at: Bundle.main.bundleURL)
    @State private var collector = MetricsCollector()
    @State private var revealed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Secondary tools sit in a tighter, denser grid; Storage gets the hero.
    private let toolColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 320), spacing: MCSpacing.sm, alignment: .top),
    ]
    private let statusColumns = [
        GridItem(.adaptive(minimum: 168, maximum: 260), spacing: MCSpacing.sm, alignment: .top),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.xl) {
                hero
                    .modifier(Reveal(revealed: revealed, index: 0, reduceMotion: reduceMotion))
                statusStrip
                    .modifier(Reveal(revealed: revealed, index: 1, reduceMotion: reduceMotion))
                storageHeroTile
                    .modifier(Reveal(revealed: revealed, index: 2, reduceMotion: reduceMotion))
                VStack(alignment: .leading, spacing: MCSpacing.sm) {
                    MCSectionHeader(L("sidebar.more"))
                    LazyVGrid(columns: toolColumns, alignment: .leading, spacing: MCSpacing.sm) {
                        toolTile("dashboard.spacelens", L("dashboard.spacelens.title"),
                                 L("dashboard.spacelens.detail"), ModuleID.spaceLens.systemImage, .spaceLens)
                        toolTile("dashboard.duplicates", L("dashboard.duplicates.title"),
                                 L("dashboard.duplicates.detail"), ModuleID.duplicates.systemImage, .duplicates)
                        toolTile("dashboard.applications", L("dashboard.applications.title"),
                                 L("dashboard.applications.detail"), ModuleID.applications.systemImage, .applications)
                        toolTile("dashboard.integrity", L("dashboard.integrity.title"),
                                 signatureStatusText, ModuleID.protection.systemImage, .protection,
                                 attention: signature.tier == .adHocOrUnsigned || !signature.signatureValid)
                        toolTile("dashboard.activity", L("dashboard.activity.title"),
                                 latestActivityText, ModuleID.myActivity.systemImage, .myActivity)
                    }
                }
                .modifier(Reveal(revealed: revealed, index: 3, reduceMotion: reduceMotion))
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MCColor.background)
        .navigationTitle(L("module.dashboard"))
        .accessibilityIdentifier("dashboard.root")
        .task {
            await refresh()
            if reduceMotion { revealed = true }
            else { withAnimation(.smooth(duration: 0.45)) { revealed = true } }
        }
    }

    // MARK: - Hero: brand geometry + identity + primary call to action

    private var hero: some View {
        HStack(alignment: .center, spacing: MCSpacing.lg) {
            CoreBloomMark(tint: [MCColor.storage, MCColor.protection, MCColor.performance],
                          lineWidthFraction: 0.08)
                .frame(width: 68, height: 68)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(L("dashboard.title"))
                    .font(MCFont.heroTitle)
                Text(L("dashboard.subtitle"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: MCSpacing.md)
            Button {
                navigate(.cleanup)
            } label: {
                ViewThatFits(in: .horizontal) {
                    Label(L("dashboard.primary_action"), systemImage: "sparkles")
                    Image(systemName: "sparkles")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel(L("dashboard.primary_action"))
        }
    }

    // MARK: - Status strip

    private var statusStrip: some View {
        LazyVGrid(columns: statusColumns, alignment: .leading, spacing: MCSpacing.sm) {
            statusPill(L("dashboard.status.free_space"),
                       value: snapshot.map { mcFormatBytes($0.diskFreeBytes) } ?? L("dashboard.status.loading"),
                       icon: "internaldrive",
                       attention: (snapshot?.diskFreeBytes ?? 20_000_000_000) < 20_000_000_000)
            statusPill(L("dashboard.status.signature"),
                       value: signatureStatusText,
                       icon: "checkmark.seal",
                       attention: signature.tier == .adHocOrUnsigned || !signature.signatureValid)
            statusPill(L("dashboard.status.safety"),
                       value: L("dashboard.status.trash_enabled"),
                       icon: "trash",
                       attention: false)
            statusPill(L("dashboard.status.exclusions"),
                       value: L("dashboard.status.exclusion_count", exclusions.count),
                       icon: "line.3.horizontal.decrease.circle",
                       attention: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Storage hero tile — the one action the dashboard is built around

    private var storageHeroTile: some View {
        Button {
            navigate(.cleanup)
        } label: {
            MCCard {
                HStack(alignment: .center, spacing: MCSpacing.lg) {
                    ZStack {
                        Circle()
                            .stroke(MCColor.storage.opacity(MCOpacity.orbitTrack), lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: freeSpaceFraction)
                            .stroke(MCColor.storage, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: freeSpaceFraction)
                        Image(systemName: ModuleID.cleanup.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(MCColor.storage)
                    }
                    .frame(width: MCSize.metricRing, height: MCSize.metricRing)

                    VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                        Text(L("dashboard.storage.title"))
                            .font(MCFont.cardTitle)
                        Text(L("dashboard.storage.detail"))
                            .font(MCFont.secondaryBody)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: MCSpacing.sm)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: MCRadius.card)
                .strokeBorder(MCColor.storage.opacity(0.55), lineWidth: 1.5))
        .accessibilityIdentifier("dashboard.storage")
        .accessibilityLabel("\(L("dashboard.storage.title")). \(L("dashboard.storage.detail"))")
        .accessibilityAddTraits(.isButton)
    }

    private var freeSpaceFraction: CGFloat {
        guard let snap = snapshot, snap.diskTotalBytes > 0 else { return 0 }
        return CGFloat(Double(snap.diskFreeBytes) / Double(snap.diskTotalBytes))
    }

    // MARK: - Secondary tool tiles

    private func toolTile(_ id: String, _ title: String, _ detail: String, _ icon: String,
                          _ module: ModuleID, attention: Bool = false) -> some View {
        Button {
            navigate(module)
        } label: {
            MCCard {
                VStack(alignment: .leading, spacing: MCSpacing.xs) {
                    HStack(spacing: MCSpacing.xs) {
                        Image(systemName: attention ? "exclamationmark.triangle.fill" : icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(attention ? MCColor.attention : .secondary)
                            .frame(width: 20)
                        Text(title).font(MCFont.cardTitle)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    Text(detail)
                        .font(MCFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityAddTraits(.isButton)
    }

    private func statusPill(_ title: String, value: String, icon: String, attention: Bool) -> some View {
        HStack(spacing: MCSpacing.xs) {
            Image(systemName: attention ? "exclamationmark.triangle.fill" : icon)
                .foregroundStyle(attention ? MCColor.attention : MCColor.teal)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(MCFont.badge)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.4)
                Text(value)
                    .font(MCFont.secondaryBody)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .contentTransition(.opacity)
            }
        }
        .padding(.horizontal, MCSpacing.sm)
        .padding(.vertical, MCSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MCColor.elevatedBackground, in: RoundedRectangle(cornerRadius: MCRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: MCRadius.small)
                .strokeBorder(MCColor.separator.opacity(0.8), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Derived text

    private var signatureStatusText: String {
        switch signature.tier {
        case .appleSigned: return L("dashboard.signature.apple")
        case .teamSigned: return L("dashboard.signature.team", signature.teamIdentifier ?? "?")
        case .adHocOrUnsigned: return L("dashboard.signature.unsigned")
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
        }
        snapshot = await latestSnapshot
        signature = CodeSignInspector.inspect(at: Bundle.main.bundleURL)
    }

    private func navigate(_ module: ModuleID) {
        NotificationCenter.default.post(name: .mcNavigate, object: module)
    }
}

/// Load-time staggered reveal. Transform/opacity only; a no-op under Reduce
/// Motion, where `revealed` is set without an animation.
private struct Reveal: ViewModifier {
    let revealed: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed || reduceMotion ? 0 : 10)
            .animation(reduceMotion ? nil : .smooth(duration: 0.4).delay(Double(index) * 0.06),
                       value: revealed)
    }
}
