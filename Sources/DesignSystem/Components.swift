// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

// MARK: - Module identity

/// Stable identity (icon + role color) for every module. Sidebar, rows and
/// page headers all pull from here so iconography stays coherent.
public struct MCModuleIdentity: Sendable {
    public let icon: String
    public let color: Color
    public init(icon: String, color: Color) {
        self.icon = icon
        self.color = color
    }

    public static let smartCare = MCModuleIdentity(icon: "gauge.with.dots.needle.33percent", color: MCColor.teal)
    public static let cleanup = MCModuleIdentity(icon: "sparkles", color: MCColor.storage)
    public static let protection = MCModuleIdentity(icon: "checkmark.shield", color: MCColor.protection)
    public static let performance = MCModuleIdentity(icon: "waveform.path.ecg", color: MCColor.performance)
    public static let applications = MCModuleIdentity(icon: "square.grid.2x2", color: MCColor.protection)
    public static let duplicates = MCModuleIdentity(icon: "doc.on.doc", color: MCColor.storage)
    public static let myClutter = MCModuleIdentity(icon: "square.3.layers.3d", color: MCColor.storage)
    public static let spaceLens = MCModuleIdentity(icon: "square.split.bottomrightquarter", color: MCColor.storage)
    public static let cloudCleanup = MCModuleIdentity(icon: "icloud", color: MCColor.storage)
    public static let myActivity = MCModuleIdentity(icon: "clock.arrow.circlepath", color: MCColor.performance)
    public static let favoritesRecents = MCModuleIdentity(icon: "star", color: MCColor.performance)
    public static let settings = MCModuleIdentity(icon: "gearshape", color: Color.secondary)
}

// MARK: - Section header

/// Monospaced caps label followed by a hairline rule running to the trailing
/// edge — the instrument's way of naming a region without boxing it.
public struct MCSectionHeader<Accessory: View>: View {
    private let title: String
    private let subtitle: String?
    private let accessory: Accessory

    public init(_ title: String, subtitle: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xxs) {
            HStack(spacing: MCSpacing.sm) {
                Text(title)
                    .font(MCFont.eyebrow)
                    .textCase(.uppercase)
                    .kerning(MCTracking.label)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Rectangle()
                    .fill(MCColor.separator)
                    .frame(height: 1)
                    .accessibilityHidden(true)
                accessory
            }
            if let subtitle {
                Text(subtitle).font(MCFont.caption).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

public extension MCSectionHeader where Accessory == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Status tag

public enum MCStatus: Sendable {
    case neutral, active, success, attention, error

    public var color: Color {
        switch self {
        case .neutral: .secondary
        case .active: MCColor.teal
        case .success: MCColor.success
        case .attention: MCColor.attention
        case .error: MCColor.destructive
        }
    }

    public var symbol: String {
        switch self {
        case .neutral: "circle.dashed"
        case .active: "circle.dotted.circle"
        case .success: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
}

/// Compact status tag: glyph + monospaced caps text on a tinted, squared
/// chip. Colour, shape and word all carry the state — readable without colour.
public struct MCStatusBadge: View {
    private let text: String
    private let status: MCStatus

    public init(_ text: String, status: MCStatus) {
        self.text = text
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbol)
                .font(.system(size: 9, weight: .bold))
                .accessibilityHidden(true)
            Text(text)
                .font(MCFont.badge)
                .textCase(.uppercase)
                .kerning(0.4)
                .lineLimit(1)
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.11), in: RoundedRectangle(cornerRadius: MCRadius.small))
        .overlay(RoundedRectangle(cornerRadius: MCRadius.small)
            .strokeBorder(status.color.opacity(0.22), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Metric readout (label + figure + meter)

/// A single live figure: caps label, a large light numeral, a detail line and
/// a segmented meter. Replaces the old ring gauges — a linear meter compares
/// at a glance across a row, and the numeral stays the loudest element.
public struct MCMetricCard: View {
    private let title: String
    private let value: String
    private let detail: String
    private let fraction: Double
    private let color: Color
    /// True once the meter colour has escalated to an attention/destructive
    /// status colour. A warning glyph always accompanies it, so the state
    /// never depends on colour alone.
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
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                HStack(spacing: MCSpacing.xxs) {
                    Text(title)
                        .font(MCFont.eyebrow)
                        .textCase(.uppercase)
                        .kerning(MCTracking.label)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if isElevated {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(color)
                            .accessibilityHidden(true)
                    }
                }
                Text(value)
                    .font(MCFont.readout)
                    .kerning(MCTracking.display / 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                MCMeter(fraction: fraction, tint: color)
                Text(detail)
                    .font(MCFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isElevated && !elevatedLabel.isEmpty
            ? "\(title): \(value), \(detail), \(elevatedLabel)"
            : "\(title): \(value), \(detail)")
    }
}

// MARK: - Empty / error states

/// Quiet, left-weighted placeholder: a squared icon tile, a title, one line
/// of guidance and at most one action. Used when a list or panel has nothing
/// to show yet — never as a full-bleed hero.
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
            // The tile scales with the requested glyph size so prominent
            // module states still read larger than nested ones.
            let tile = max(44, iconSize * 1.25)
            Image(systemName: icon)
                .font(.system(size: iconSize * 0.5, weight: .regular))
                .foregroundStyle(iconColor)
                .frame(width: tile, height: tile)
                .background(MCColor.sunken, in: RoundedRectangle(cornerRadius: MCRadius.hero))
                .overlay(RoundedRectangle(cornerRadius: MCRadius.hero)
                    .strokeBorder(MCColor.separator, lineWidth: 1))
                .accessibilityHidden(true)
                .padding(.bottom, MCSpacing.xxs)
            Text(title)
                .font(MCFont.cardTitle)
                .multilineTextAlignment(.center)
            if !message.isEmpty {
                Text(message)
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.mcPrimary)
                    .padding(.top, MCSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MCSpacing.xl)
    }
}

/// Shared "the cleanup finished" state. One consistent, quietly confident
/// moment across every module that moves things to the Trash — a check in a
/// squared tile with a single one-shot ring flourish (transform + opacity
/// only). Under Reduce Motion it simply appears.
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
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(MCColor.success.opacity(0.4 * Double(1 - flourish)), lineWidth: 1.5)
                        .frame(width: 72, height: 72)
                        .scaleEffect(1 + flourish * 0.6)
                }
                RoundedRectangle(cornerRadius: 16)
                    .fill(MCColor.success.opacity(0.12))
                    .frame(width: 72, height: 72)
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(MCColor.success.opacity(0.35), lineWidth: 1)
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(MCColor.success)
            }
            .scaleEffect(popped || reduceMotion ? 1 : 0.8)
            .opacity(popped || reduceMotion ? 1 : 0)
            .accessibilityHidden(true)

            Text(title)
                .font(MCFont.pageTitle)
                .kerning(MCTracking.title)
                .multilineTextAlignment(.center)
            if let message, !message.isEmpty {
                Text(message)
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.mcSecondary)
                    .padding(.top, MCSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MCSpacing.xl)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { popped = true }
            withAnimation(.easeOut(duration: 0.8)) { flourish = 1 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.map { $0.isEmpty ? title : "\(title). \($0)" } ?? title)
    }
}

// MARK: - Canvas

/// The app's shared canvas: a flat graphite/porcelain field. Deliberately no
/// gradient or light source — the panels on top carry the structure.
public struct MCCanvasBackground: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        content.background(MCColor.background)
    }
}

public extension View {
    /// Sits the view on the app's canvas (see `MCCanvasBackground`).
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
            .offset(y: shown || reduceMotion ? 0 : 6)
            .onAppear {
                guard !reduceMotion, !shown else { return }
                withAnimation(.smooth(duration: 0.32).delay(delay)) { shown = true }
            }
    }
}

public extension View {
    /// Fade-and-rise this view in when it appears. See `MCAppear`.
    func mcAppear(delay: Double = 0) -> some View { modifier(MCAppear(delay: delay)) }
}

// MARK: - Scan command

/// The primary "start" command for a module's landing state. A wide,
/// squared teal command bar — icon tile, label, and a ↩ keycap that tells
/// the user Return runs it. It is the one filled surface on the screen, so it
/// needs no glow or oversized disc to be found.
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
            HStack(spacing: MCSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(MCColor.onAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: MCRadius.small))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: MCSpacing.md)
                Text(verbatim: "↩")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .frame(width: 24, height: 20)
                    .overlay(RoundedRectangle(cornerRadius: MCRadius.small)
                        .strokeBorder(MCColor.onAccent.opacity(0.4), lineWidth: 1))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(MCColor.onAccent)
            .padding(.leading, MCSpacing.sm)
            .padding(.trailing, MCSpacing.md)
            .frame(minWidth: 260, maxWidth: 360, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: MCRadius.hero)
                .fill(MCColor.teal.opacity(hovering ? 0.9 : 1)))
            .offset(y: hovering && !reduceMotion ? -1 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: MCRadius.hero))
        }
        .buttonStyle(MCPressStyle())
        .onHover { h in
            withAnimation(reduceMotion ? nil : .easeOut(duration: MCMotion.quick)) { hovering = h }
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Feature row (module landing states)

/// A capability row for module landing states — squared icon tile, title and
/// optional detail. Lists what a module examines before the user commits.
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
            MCIconTile(icon, tint: iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(MCFont.secondaryBody.weight(.medium))
                if let subtitle {
                    Text(subtitle)
                        .font(MCFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
