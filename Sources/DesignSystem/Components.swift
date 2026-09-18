// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

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
            Text(title).font(MCFont.sectionTitle).foregroundStyle(MCColor.textSecondary)
                .textCase(.uppercase)
                .kerning(0.5)
            if let subtitle {
                Text(subtitle).font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
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
                            .font(MCFont.micro)
                            .foregroundStyle(color)
                            .offset(x: MCSize.metricRing * 0.32, y: -MCSize.metricRing * 0.32)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: MCSize.metricRing, height: MCSize.metricRing)
                Text(title).font(MCFont.cardTitle)
                Text(detail).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
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
                .foregroundStyle(MCColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .mcPrimaryButton()
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
                    .font(.system(size: MCIconSize.hero, weight: .semibold))
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
                    .foregroundStyle(MCColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .mcPrimaryButton()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MCSpacing.xl)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(MCMotion.settle) { popped = true }
            // Decorative: a glow blooming behind a finished cleanup. It
            // reports nothing and gates nothing, which is why it is the one
            // thing allowed to take half a second.
            withAnimation(MCMotion.ambient) { flourish = 1 }
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
        )
    }
}

public extension View {
    /// Sits the view on the app's lit canvas (see `MCCanvasBackground`).
    func mcCanvasBackground() -> some View { modifier(MCCanvasBackground()) }
}

// MARK: - Entrance

/// A quiet fade-and-rise on first appearance — transform + opacity only, a
/// no-op under Reduce Motion. Fires once; it deliberately does not reset on
/// disappear (resetting caused animation churn that could stall sibling
/// AppKit-hosted controls like `Picker` in a split-view detail).
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
                guard !reduceMotion, !shown else { return }
                withAnimation(MCMotion.reveal.delay(delay)) { shown = true }
            }
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
                    .font(.system(size: MCIconSize.card, weight: .semibold))
                Text(title)
                    .font(MCFont.cardTitle)
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
            withAnimation(reduceMotion ? nil : MCMotion.response) { hovering = h }
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
                .font(.system(size: MCIconSize.row, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(title).font(MCFont.secondaryBody)
                if let subtitle {
                    Text(subtitle)
                        .font(MCFont.caption)
                        .foregroundStyle(MCColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Buttons

/// The app's primary action.
///
/// Replaces `.buttonStyle(.borderedProminent)`, which pairs the view's tint
/// with a white label and never checks that the two can be read together. With
/// CoreTend's teal that combination measures **1.87:1** — against a 4.5:1 text
/// minimum — and it was the label of the primary action on every screen that
/// had one: Scan Storage, Find Duplicates, Scan Home Folder.
///
/// The same teal with `MCColor.onAccent` measures 9.65:1.
///
/// Pressed and disabled states are explicit rather than inherited, so they
/// cannot be whatever the system decides a tinted button should look like.
public struct MCPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MCFont.actionLabel)
            .foregroundStyle(MCColor.onAccent)
            .padding(.vertical, MCSpacing.sm)
            .padding(.horizontal, MCSpacing.lg)
            .background(fill(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: MCRadius.card))
            // Opacity, not a third fill colour: a disabled control should read
            // as the same control turned down, not as a different one.
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: MCRadius.card))
    }

    private func fill(pressed: Bool) -> Color {
        pressed ? MCColor.tealDeep : MCColor.teal
    }
}

/// A secondary action: real emphasis, but never competing with the primary one
/// on the same screen.
///
/// A tinted outline rather than a filled surface, so that two buttons side by
/// side have an obvious order.
public struct MCSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MCFont.rowTitle)
            .foregroundStyle(MCColor.teal)
            .padding(.vertical, MCSpacing.xs)
            .padding(.horizontal, MCSpacing.md)
            .background(
                configuration.isPressed ? MCColor.tealWash : Color.clear,
                in: RoundedRectangle(cornerRadius: MCRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: MCRadius.card)
                    .stroke(MCColor.teal.opacity(0.55), lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: MCRadius.card))
    }
}

/// An irreversible action.
///
/// Filled, because "Move to Trash" should not be reachable by accident, and
/// filled in coral so it cannot be mistaken for the primary action even at a
/// glance or in greyscale.
public struct MCDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MCFont.rowTitle)
            .foregroundStyle(MCColor.onAccent)
            .padding(.vertical, MCSpacing.xs)
            .padding(.horizontal, MCSpacing.md)
            .background(
                configuration.isPressed ? MCColor.coral.opacity(0.8) : MCColor.coral,
                in: RoundedRectangle(cornerRadius: MCRadius.card))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: MCRadius.card))
    }
}

public extension ButtonStyle where Self == MCPrimaryButtonStyle {
    static var mcPrimary: MCPrimaryButtonStyle { MCPrimaryButtonStyle() }
}

// MARK: - Button roles
//
// ## The system glass styles were measured and rejected
//
// WWDC26 says "for a glass button, you should use `glassButtonStyle` (or
// `glassProminent`) rather than applying a raw `glassEffect`", and CoreTend's
// own styles existed only because `.borderedProminent` paired the tint with a
// white label at 1.87:1. So `.glassProminent` was measured on macOS 27 rather
// than assumed.
//
// **In isolation it passes.** On a flat ground at #14171A with the brand teal
// as tint, in an activated window, it renders a *dark* label and measures
// **11.13:1** — the system picks a legible label for the tint now, and that
// beats the 9.65:1 of the fill below.
//
// **In place it fails.** CoreTend's primary action sits inside the Dashboard's
// feature card, which carries a teal wash. Glass samples what is behind it, so
// the fill resolved to a muddy #5BA0A1, the system then chose a near-white
// label, and the pair measured **2.61:1** — worse than what it replaced, and
// under the 4.5:1 minimum.
//
// That is not a bug in the system style. It is the HIG's own rule arriving as
// a measurement: Liquid Glass belongs to the navigation layer, and "Don't use
// Liquid Glass in the content layer... including it in the content layer can
// result in unnecessary complexity and a confusing visual hierarchy." A button
// on a tinted card is content.
//
// So the styles below stay, and the glass styles stay where they belong — the
// sidebar and the sub-navigation bar, via `mcNavigationGlass`.
//
// The lesson is the method, not the result: a contrast measurement taken
// anywhere but the surface the control actually sits on is a measurement of
// something else.

public extension View {
    /// A screen's primary action.
    func mcPrimaryButton() -> some View { buttonStyle(.mcPrimary) }
    /// A secondary action, never competing with the primary one.
    func mcSecondaryButton() -> some View { buttonStyle(.mcSecondary) }
    /// An irreversible action.
    func mcDestructiveButton() -> some View { buttonStyle(.mcDestructive) }
}

public extension ButtonStyle where Self == MCSecondaryButtonStyle {
    static var mcSecondary: MCSecondaryButtonStyle { MCSecondaryButtonStyle() }
}

public extension ButtonStyle where Self == MCDestructiveButtonStyle {
    static var mcDestructive: MCDestructiveButtonStyle { MCDestructiveButtonStyle() }
}

// MARK: - Surfaces

/// Where a surface sits in the elevation ladder.
///
/// `MCColor` defines four ground-to-raised steps and documents them as a
/// ladder, but views were assembling surfaces by hand — a fill, a stroke, a
/// radius and sometimes a shadow, restated at each site with small differences
/// nobody chose. `MCCard` existed and was used eleven times; the Dashboard
/// alone hand-rolled five more with a different radius and no shadow.
///
/// Naming the level rather than the colour means a view says how far forward
/// something sits, and the ladder stays a ladder.
public enum MCElevation {
    /// Recessed: the sidebar, inset wells.
    case sunken
    /// The default raised surface: cards, rows, popovers.
    case raised
    /// One step further forward: a hovered or selected row inside a card.
    case raisedHigh
    /// Raised, and tinted with the accent — reserved for the one panel a
    /// screen is built around.
    case feature

    var fill: Color {
        switch self {
        case .sunken: MCColor.secondaryBackground
        case .raised: MCColor.elevatedBackground
        case .raisedHigh: MCColor.elevatedHighBackground
        case .feature: MCColor.elevatedBackground
        }
    }

    /// Only the feature surface carries a shadow. A shadow on every card makes
    /// none of them read as raised.
    var shadowOpacity: Double {
        switch self {
        case .feature: 0.22
        case .raised: 0.16
        case .sunken, .raisedHigh: 0
        }
    }

    var strokeColor: Color {
        self == .feature ? MCColor.teal.opacity(0.35) : MCColor.separator
    }
}

public extension View {
    /// Applies one step of the elevation ladder: fill, hairline, and shadow if
    /// the level has one.
    ///
    /// Increase Contrast strengthens the hairline rather than the fill —
    /// brightening surfaces would flatten the ladder, which is the opposite of
    /// what someone turning that setting on is asking for.
    func mcSurface(_ level: MCElevation = .raised,
                   radius: CGFloat = MCRadius.card) -> some View {
        modifier(MCSurfaceModifier(level: level, radius: radius))
    }
}

private struct MCSurfaceModifier: ViewModifier {
    let level: MCElevation
    let radius: CGFloat

    func body(content: Content) -> some View {
        // Read directly rather than via @Environment: macOS SwiftUI has no
        // accessibilityIncreaseContrast environment key. Observation tracks
        // this read and re-renders when the system setting changes.
        let increaseContrast = MCAccessibilityState.shared.increaseContrast
        let shape = RoundedRectangle(cornerRadius: radius)
        return content
            .background {
                shape.fill(level.fill)
                if level == .feature {
                    shape.fill(LinearGradient(
                        colors: [MCColor.teal.opacity(0.12), MCColor.teal.opacity(0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .overlay(shape.strokeBorder(
                level.strokeColor.opacity(increaseContrast ? 1.0 : 0.8),
                lineWidth: increaseContrast ? 1.5 : 1))
            .shadow(color: .black.opacity(level.shadowOpacity), radius: 5, x: 0, y: 2)
    }
}
