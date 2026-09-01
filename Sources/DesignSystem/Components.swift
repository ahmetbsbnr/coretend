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

    public static let smartCare = MCModuleIdentity(icon: "circle.hexagonpath", color: MCColor.teal)
    public static let cleanup = MCModuleIdentity(icon: "sparkles", color: MCColor.storage)
    public static let protection = MCModuleIdentity(icon: "checkerboard.shield", color: MCColor.protection)
    public static let performance = MCModuleIdentity(icon: "waveform.path.ecg", color: MCColor.performance)
    public static let applications = MCModuleIdentity(icon: "square.grid.2x2", color: MCColor.protection)
    public static let duplicates = MCModuleIdentity(icon: "doc.on.doc", color: MCColor.storage)
    public static let myClutter = MCModuleIdentity(icon: "square.3.layers.3d", color: MCColor.storage)
    public static let spaceLens = MCModuleIdentity(icon: "map", color: MCColor.storage)
    public static let cloudCleanup = MCModuleIdentity(icon: "cloud", color: MCColor.storage)
    public static let myActivity = MCModuleIdentity(icon: "clock.arrow.circlepath", color: MCColor.performance)
    public static let favoritesRecents = MCModuleIdentity(icon: "star", color: MCColor.performance)
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
        case .active: MCColor.teal
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
    private let iconColor: Color
    private let iconSize: CGFloat
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        icon: String, title: String, message: String,
        iconColor: Color = .secondary, iconSize: CGFloat = MCIconSize.compactState,
        actionTitle: String? = nil, action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.iconColor = iconColor
        self.iconSize = iconSize
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: MCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
            Text(title).font(MCFont.cardTitle)
            Text(message)
                .font(MCFont.secondaryBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
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
                .font(.system(size: MCIconSize.errorState, weight: .light))
                .foregroundStyle(MCColor.attention)
                .accessibilityHidden(true)
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

/// Shared "the cleanup finished" state. One consistent, quietly celebratory
/// moment across every module that moves things to the Trash — a sealed
/// checkmark that pops in with a single expanding ring flourish (transform +
/// opacity only, one-shot, no loop). Under Reduce Motion it simply appears.
///
/// Before this, each module hand-rolled its finish screen — some reused
/// `MCEmptyState` with a green tint, some an ad-hoc `VStack` — so "done"
/// looked different depending on where you were.
public struct MCSuccessState: View {
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false
    @State private var flourish: CGFloat = 0

    public init(title: String, message: String? = nil,
                actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: MCSpacing.md) {
            ZStack {
                if !reduceMotion {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .stroke(MCColor.success.opacity(0.35 * Double(1 - flourish)), lineWidth: 2)
                            .frame(width: 76, height: 76)
                            .scaleEffect(0.55 + flourish * (1.3 + CGFloat(i) * 0.55))
                    }
                }
                Circle().fill(MCColor.success.opacity(0.14)).frame(width: 76, height: 76)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(MCColor.success)
            }
            .scaleEffect(popped || reduceMotion ? 1 : 0.7)
            .opacity(popped || reduceMotion ? 1 : 0)
            .accessibilityHidden(true)

            Text(title)
                .font(MCFont.pageTitle)
                .multilineTextAlignment(.center)
            if let message, !message.isEmpty {
                Text(message)
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MCSpacing.xl)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { popped = true }
            withAnimation(.easeOut(duration: 0.9)) { flourish = 1 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.map { $0.isEmpty ? title : "\(title). \($0)" } ?? title)
    }
}

// MARK: - Lit canvas

/// The app's shared canvas: the Slate/Porcelain base with a single faint
/// teal light source in the top-leading corner. No imagery, no second hue —
/// just enough gradient that the window never reads as a dead flat field.
/// Applied once to the module container so every screen sits on it.
public struct MCCanvasBackground: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        content.background(
            ZStack {
                MCColor.background
                RadialGradient(colors: [MCColor.teal.opacity(0.06), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 680)
            }
            .ignoresSafeArea()
        )
    }
}

public extension View {
    /// Sits the view on the app's lit canvas (see `MCCanvasBackground`).
    func mcCanvasBackground() -> some View { modifier(MCCanvasBackground()) }
}

// MARK: - Entrance

/// A quiet fade-and-rise on first appearance — transform + opacity only, a
/// no-op under Reduce Motion. Re-runs when the view re-appears (e.g. the
/// module is navigated back to), which is the intent.
public struct MCAppear: ViewModifier {
    private let delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(delay: Double = 0) { self.delay = delay }

    public func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.smooth(duration: 0.4).delay(delay)) { shown = true }
            }
            .onDisappear { shown = false }
    }
}

public extension View {
    /// Fade-and-rise this view in when it appears. See `MCAppear`.
    func mcAppear(delay: Double = 0) -> some View { modifier(MCAppear(delay: delay)) }
}

// MARK: - Scan button

/// The large circular "start" control for a module's landing state — the one
/// unmistakable focal action on the screen. A filled teal disc with an icon
/// over a short label, a soft teal glow, and a small hover lift (transform +
/// shadow only; still under Reduce Motion). Not decoration: it is the primary
/// button, sized to match its importance.
public struct MCScanButton: View {
    private let title: String
    private let systemImage: String
    private let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    public init(_ title: String, systemImage: String = "sparkles", action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: MCSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(MCSpacing.md)
            .frame(width: 136, height: 136)
            .background(
                Circle().fill(
                    RadialGradient(
                        colors: [MCColor.teal, MCColor.teal.opacity(0.82)],
                        center: UnitPoint(x: 0.4, y: 0.32), startRadius: 2, endRadius: 118)))
            .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
            .shadow(color: MCColor.teal.opacity(hovering ? 0.5 : 0.34),
                    radius: hovering ? 26 : 18, x: 0, y: 6)
            .scaleEffect(hovering && !reduceMotion ? 1.03 : 1)
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { hovering = h }
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Feature row (module landing states)

/// A feature/capability row for module idle states — icon + title + optional subtitle.
/// Used to list what a module scans or surfaces, giving users context before they act.
public struct MCFeatureRow: View {
    private let title: String
    private let subtitle: String?
    private let icon: String
    private let iconColor: Color

    public init(_ title: String, subtitle: String? = nil, icon: String,
                iconColor: Color = MCColor.teal) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
    }

    public var body: some View {
        HStack(alignment: subtitle != nil ? .top : .center, spacing: MCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(title).font(MCFont.secondaryBody)
                if let subtitle {
                    Text(subtitle)
                        .font(MCFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
