import SwiftUI

// MARK: - Module identity

/// Stable identity (icon + role color) for every module. Sidebar, cards and
/// module headers all pull from here so iconography stays coherent.
public struct MCModuleIdentity: Sendable {
    public let icon: String
    public let color: Color
    public init(icon: String, color: Color) {
        self.icon = icon
        self.color = color
    }

    public static let smartCare = MCModuleIdentity(icon: "circle.hexagonpath", color: MCColor.coreMint)
    public static let cleanup = MCModuleIdentity(icon: "sparkles", color: MCColor.storage)
    public static let protection = MCModuleIdentity(icon: "checkerboard.shield", color: MCColor.protection)
    public static let performance = MCModuleIdentity(icon: "waveform.path.ecg", color: MCColor.performance)
    public static let applications = MCModuleIdentity(icon: "square.grid.2x2", color: MCColor.protection)
    public static let myClutter = MCModuleIdentity(icon: "square.3.layers.3d", color: MCColor.storage)
    public static let spaceLens = MCModuleIdentity(icon: "map", color: MCColor.storage)
    public static let cloudCleanup = MCModuleIdentity(icon: "cloud", color: MCColor.storage)
    public static let myActivity = MCModuleIdentity(icon: "clock.arrow.circlepath", color: MCColor.performance)
    public static let settings = MCModuleIdentity(icon: "gearshape", color: Color.secondary)
}

// MARK: - Section header

public struct MCSectionHeader: View {
    private let title: String
    private let subtitle: String?

    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xxs) {
            Text(title).font(MCFont.sectionTitle).foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
            if let subtitle {
                Text(subtitle).font(MCFont.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Status badge

public enum MCStatus {
    case neutral, active, success, attention, error

    var color: Color {
        switch self {
        case .neutral: .secondary
        case .active: MCColor.coreMint
        case .success: MCColor.success
        case .attention: MCColor.attention
        case .error: MCColor.destructive
        }
    }

    var symbol: String {
        switch self {
        case .neutral: "circle.dashed"
        case .active: "circle.dotted.circle"
        case .success: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
}

/// Color + symbol + text: readable without color.
public struct MCStatusBadge: View {
    private let text: String
    private let status: MCStatus

    public init(_ text: String, status: MCStatus) {
        self.text = text
        self.status = status
    }

    public var body: some View {
        Label(text, systemImage: status.symbol)
            .font(MCFont.badge)
            .foregroundStyle(status.color)
            .padding(.horizontal, MCSpacing.xs)
            .padding(.vertical, MCSpacing.xxs)
            .background(status.color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Metric card (ring + value + caption)

public struct MCMetricCard: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private let title: String
    private let value: String
    private let detail: String
    private let fraction: Double
    private let color: Color
    /// True once the ring color has escalated to an "attention"/"destructive"
    /// status color — the ring color alone is the only signal of that today,
    /// so under Differentiate Without Color a small glyph is added too.
    /// `elevatedLabel` is a caller-supplied, already-localized word (e.g.
    /// "elevated") appended to the accessibility label in that state —
    /// DesignSystem has no localization table of its own.
    private let isElevated: Bool
    private let elevatedLabel: String

    public init(title: String, value: String, detail: String, fraction: Double, color: Color,
                isElevated: Bool = false, elevatedLabel: String = "") {
        self.title = title
        self.value = value
        self.detail = detail
        self.fraction = min(max(fraction, 0), 1)
        self.color = color
        self.isElevated = isElevated
        self.elevatedLabel = elevatedLabel
    }

    public var body: some View {
        MCCard {
            VStack(spacing: MCSpacing.xs) {
                ZStack {
                    Circle().stroke(color.opacity(MCOpacity.orbitTrack), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(value)
                        .font(MCFont.metric)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(MCSpacing.xs)
                    if isElevated && differentiateWithoutColor {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(color)
                            .offset(x: MCSize.metricRing * 0.32, y: -MCSize.metricRing * 0.32)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: MCSize.metricRing, height: MCSize.metricRing)
                Text(title).font(MCFont.cardTitle)
                Text(detail).font(MCFont.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isElevated && !elevatedLabel.isEmpty
            ? "\(title): \(value), \(detail), \(elevatedLabel)"
            : "\(title): \(value), \(detail)")
    }
}

// MARK: - Empty / error states

public struct MCEmptyState: View {
    private let icon: String
    private let title: String
    private let message: String

    public init(icon: String, title: String, message: String) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: MCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(MCFont.cardTitle)
            Text(message)
                .font(MCFont.secondaryBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MCSpacing.xl)
    }
}

public struct MCErrorState: View {
    private let title: String
    private let message: String
    private let retryTitle: String?
    private let retry: (() -> Void)?

    public init(title: String, message: String, retryTitle: String? = nil, retry: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: MCSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(MCColor.attention)
            Text(title).font(MCFont.cardTitle)
            Text(message)
                .font(MCFont.secondaryBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let retry, let retryTitle {
                Button(retryTitle, action: retry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MCSpacing.xl)
    }
}
