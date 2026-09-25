// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

// MARK: - Buttons

/// The app's one button language. Four kinds, two sizes — every button in the
/// product resolves to one of these instead of mixing `.borderedProminent`,
/// `.bordered`, `.link` and ad-hoc styling.
///
/// - `primary`: the single filled teal command on a surface.
/// - `secondary`: hairline-outlined panel button for alternatives.
/// - `quiet`: text-only until hovered; toolbar and inline actions.
/// - `destructive`: coral outline, fills on hover — irreversible or Trash.
public struct MCButtonStyle: ButtonStyle {
    public enum Kind: Sendable { case primary, secondary, quiet, destructive }
    public enum Size: Sendable { case regular, large }

    private let kind: Kind
    private let size: Size

    public init(_ kind: Kind = .secondary, size: Size = .regular) {
        self.kind = kind
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        MCButtonBody(configuration: configuration, kind: kind, size: size)
    }
}

private struct MCButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: MCButtonStyle.Kind
    let size: MCButtonStyle.Size

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MCRadius.control)
        configuration.label
            .font(size == .large ? .system(size: 13.5, weight: .semibold) : .system(size: 12.5, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, size == .large ? 16 : 10)
            .frame(minHeight: size == .large ? 34 : 26)
            .foregroundStyle(foreground)
            .background(shape.fill(background))
            .overlay(shape.strokeBorder(border, lineWidth: 1))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.42)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: MCMotion.quick), value: configuration.isPressed)
            .animation(.easeOut(duration: MCMotion.quick), value: hovering)
            .onHover { hovering = $0 && isEnabled }
    }

    private var foreground: Color {
        switch kind {
        case .primary: MCColor.onAccent
        case .secondary: .primary
        case .quiet: hovering ? .primary : .secondary
        case .destructive: hovering ? MCColor.onAccent : MCColor.coral
        }
    }

    private var background: Color {
        switch kind {
        case .primary: MCColor.teal.opacity(configuration.isPressed ? 0.82 : hovering ? 0.9 : 1)
        case .secondary: hovering ? MCColor.sunken : MCColor.elevatedBackground
        case .quiet: hovering ? MCColor.sunken : .clear
        case .destructive: hovering ? MCColor.coral : MCColor.coral.opacity(0.08)
        }
    }

    private var border: Color {
        switch kind {
        case .primary: .clear
        case .secondary: hovering ? MCColor.rule : MCColor.separator
        case .quiet: .clear
        case .destructive: MCColor.coral.opacity(0.45)
        }
    }
}

public extension ButtonStyle where Self == MCButtonStyle {
    static var mcPrimary: MCButtonStyle { MCButtonStyle(.primary) }
    static var mcPrimaryLarge: MCButtonStyle { MCButtonStyle(.primary, size: .large) }
    static var mcSecondary: MCButtonStyle { MCButtonStyle(.secondary) }
    static var mcSecondaryLarge: MCButtonStyle { MCButtonStyle(.secondary, size: .large) }
    static var mcQuiet: MCButtonStyle { MCButtonStyle(.quiet) }
    static var mcDestructive: MCButtonStyle { MCButtonStyle(.destructive) }
    static var mcDestructiveLarge: MCButtonStyle { MCButtonStyle(.destructive, size: .large) }
}

/// Square, glyph-only row action (reveal in Finder, remove, more…). Hover
/// shows a well so the hit target is discoverable without permanent chrome.
public struct MCIconButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        MCIconButtonBody(configuration: configuration)
    }
}

private struct MCIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(hovering ? Color.primary : Color.secondary)
            .frame(width: 24, height: 24)
            .background(RoundedRectangle(cornerRadius: MCRadius.small)
                .fill(hovering || configuration.isPressed ? MCColor.sunken : .clear))
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovering = $0 }
    }
}

public extension ButtonStyle where Self == MCIconButtonStyle {
    static var mcIcon: MCIconButtonStyle { MCIconButtonStyle() }
}

/// Pressed feedback only — for custom-drawn buttons (scan command, rows)
/// that own their resting appearance.
public struct MCPressStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: MCMotion.quick), value: configuration.isPressed)
    }
}

/// Full-width navigable row (dashboard tool list, settings links): hover
/// wash, pressed dip, no chrome at rest.
public struct MCRowButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        MCRowButtonBody(configuration: configuration)
    }
}

private struct MCRowButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false

    var body: some View {
        configuration.label
            .contentShape(Rectangle())
            .background(hovering || configuration.isPressed ? MCColor.sunken.opacity(0.7) : .clear)
            .animation(.easeOut(duration: MCMotion.quick), value: hovering)
            .onHover { hovering = $0 }
    }
}

public extension ButtonStyle where Self == MCRowButtonStyle {
    static var mcRow: MCRowButtonStyle { MCRowButtonStyle() }
}

// MARK: - Structural primitives

/// A one-point rule in the separator colour.
public struct MCHairline: View {
    private let vertical: Bool
    public init(vertical: Bool = false) { self.vertical = vertical }
    public var body: some View {
        Rectangle()
            .fill(MCColor.separator)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
            .accessibilityHidden(true)
    }
}

/// Squared icon tile used by rows, feature lists and empty states.
public struct MCIconTile: View {
    private let icon: String
    private let tint: Color
    private let size: CGFloat
    private let filled: Bool

    public init(_ icon: String, tint: Color = MCColor.teal, size: CGFloat = MCSize.iconTile, filled: Bool = false) {
        self.icon = icon
        self.tint = tint
        self.size = size
        self.filled = filled
    }

    public var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(filled ? MCColor.onAccent : tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: MCRadius.small + 1)
                .fill(filled ? tint : tint.opacity(0.10)))
            .accessibilityHidden(true)
    }
}

/// Monospaced caps label — the instrument's labelling voice.
public struct MCEyebrow: View {
    private let text: String
    private let tint: Color
    public init(_ text: String, tint: Color = .secondary) {
        self.text = text
        self.tint = tint
    }
    public var body: some View {
        Text(text)
            .font(MCFont.eyebrow)
            .textCase(.uppercase)
            .kerning(MCTracking.label)
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}

/// Keyboard shortcut hint, drawn as a small keycap.
public struct MCKeycap: View {
    private let key: String
    public init(_ key: String) { self.key = key }
    public var body: some View {
        Text(verbatim: key)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(MCColor.sunken, in: RoundedRectangle(cornerRadius: MCRadius.small))
            .overlay(RoundedRectangle(cornerRadius: MCRadius.small).strokeBorder(MCColor.separator, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

// MARK: - Meter

/// Segmented linear meter — the product's signature gauge. Discrete cells
/// read as a measured quantity (an instrument) rather than a decorative
/// progress bar, and compare cleanly when stacked in rows.
public struct MCMeter: View {
    private let fraction: Double
    private let tint: Color
    private let segments: Int
    private let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(fraction: Double, tint: Color = MCColor.teal, segments: Int = 36, height: CGFloat = 6) {
        self.fraction = min(max(fraction.isFinite ? fraction : 0, 0), 1)
        self.tint = tint
        self.segments = max(segments, 1)
        self.height = height
    }

    public var body: some View {
        let lit = Int((fraction * Double(segments)).rounded(.up))
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < lit ? tint : MCColor.sunken)
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : .easeOut(duration: MCMotion.standard), value: lit)
        .accessibilityHidden(true)
    }
}

// MARK: - Page header

/// The header every module page shares: a monospaced eyebrow naming the area,
/// the page title, one line of context, and the page's actions on the
/// trailing edge. A hairline closes it off from the content below.
///
/// On a narrow window the actions drop beneath the title rather than
/// squeezing it (`ViewThatFits`).
public struct MCPageHeader<Actions: View>: View {
    private let title: String
    private let eyebrow: String?
    private let subtitle: String?
    private let icon: String?
    private let actions: Actions

    public init(_ title: String, eyebrow: String? = nil, subtitle: String? = nil, icon: String? = nil,
                @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.eyebrow = eyebrow
        self.subtitle = subtitle
        self.icon = icon
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: MCSpacing.lg) {
                    titleBlock
                    Spacer(minLength: MCSpacing.md)
                    HStack(spacing: MCSpacing.xs) { actions }
                }
                VStack(alignment: .leading, spacing: MCSpacing.sm) {
                    titleBlock
                    HStack(spacing: MCSpacing.xs) { actions }
                }
            }
            .padding(.horizontal, MCSpacing.page)
            .padding(.top, MCSpacing.lg)
            .padding(.bottom, MCSpacing.md)
            MCHairline()
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .top, spacing: MCSpacing.sm) {
            if let icon {
                MCIconTile(icon, size: 36)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow {
                    MCEyebrow(eyebrow, tint: MCColor.teal)
                }
                Text(title)
                    .font(MCFont.pageTitle)
                    .kerning(MCTracking.title)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(MCFont.secondaryBody)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 560, alignment: .leading)
                }
            }
        }
    }
}

public extension MCPageHeader where Actions == EmptyView {
    init(_ title: String, eyebrow: String? = nil, subtitle: String? = nil, icon: String? = nil) {
        self.init(title, eyebrow: eyebrow, subtitle: subtitle, icon: icon) { EmptyView() }
    }
}

// MARK: - Panel

/// A titled panel: caps label + optional accessory in a header strip, a
/// hairline, then content. Use for any grouped region that needs a name;
/// `MCCard` stays the untitled surface.
public struct MCPanel<Content: View, Accessory: View>: View {
    private let title: String?
    private let padded: Bool
    private let accessory: Accessory
    private let content: Content

    public init(_ title: String? = nil, padded: Bool = true,
                @ViewBuilder accessory: () -> Accessory,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.padded = padded
        self.accessory = accessory()
        self.content = content()
    }

    public var body: some View {
        let increaseContrast = MCAccessibilityState.shared.increaseContrast
        let shape = RoundedRectangle(cornerRadius: MCRadius.card)
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                HStack(spacing: MCSpacing.xs) {
                    MCEyebrow(title)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: MCSpacing.xs)
                    accessory
                }
                .padding(.horizontal, MCSpacing.md)
                .frame(minHeight: 36)
                MCHairline()
            }
            content
                .padding(padded ? MCSpacing.md : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(shape.fill(MCColor.elevatedBackground))
        .clipShape(shape)
        .overlay(shape.strokeBorder(increaseContrast ? MCColor.rule : MCColor.separator,
                                     lineWidth: increaseContrast ? 1.5 : 1))
    }
}

public extension MCPanel where Accessory == EmptyView {
    init(_ title: String? = nil, padded: Bool = true, @ViewBuilder content: () -> Content) {
        self.init(title, padded: padded, accessory: { EmptyView() }, content: content)
    }
}

// MARK: - Readout & key/value

/// Caps label over a large, light figure, with an optional detail line.
public struct MCReadout: View {
    private let label: String
    private let value: String
    private let detail: String?
    private let large: Bool

    public init(_ label: String, value: String, detail: String? = nil, large: Bool = false) {
        self.label = label
        self.value = value
        self.detail = detail
        self.large = large
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            MCEyebrow(label)
            Text(value)
                .font(large ? MCFont.displayMetric : MCFont.readout)
                .kerning(large ? MCTracking.display : MCTracking.display / 2)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.numericText())
            if let detail {
                Text(detail)
                    .font(MCFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Label/value row for fact lists. Values are tabular and trailing-aligned.
public struct MCKeyValueRow: View {
    private let label: String
    private let value: String
    private let icon: String?
    private let status: MCStatus?

    public init(_ label: String, value: String, icon: String? = nil, status: MCStatus? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
        self.status = status
    }

    public var body: some View {
        HStack(spacing: MCSpacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                    .accessibilityHidden(true)
            }
            Text(label)
                .font(MCFont.secondaryBody)
                .foregroundStyle(.secondary)
            Spacer(minLength: MCSpacing.sm)
            if let status, status != .neutral {
                Image(systemName: status.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(status.color)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(MCFont.secondaryBody.weight(.medium))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(minHeight: 30)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Action bar

/// A review screen's commit strip: what is selected on the leading edge, the
/// actions on the trailing edge. Pinned to the bottom of review lists so the
/// consequential action is always one glance away and never scrolls off.
public struct MCActionBar<Summary: View, Actions: View>: View {
    private let summary: Summary
    private let actions: Actions

    public init(@ViewBuilder summary: () -> Summary, @ViewBuilder actions: () -> Actions) {
        self.summary = summary()
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: 0) {
            MCHairline()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: MCSpacing.md) {
                    summary
                    Spacer(minLength: MCSpacing.md)
                    HStack(spacing: MCSpacing.xs) { actions }
                }
                VStack(alignment: .leading, spacing: MCSpacing.xs) {
                    summary
                    HStack(spacing: MCSpacing.xs) { actions }
                }
            }
            .padding(.horizontal, MCSpacing.page)
            .padding(.vertical, MCSpacing.sm)
        }
        .background(MCColor.elevatedBackground)
    }
}

// MARK: - Briefing (module landing layout)

/// The landing state every scanning module shares: a left-aligned column
/// with a title, one paragraph of context and the start command, then an
/// optional detail region (what will be examined, options) beside it on wide
/// windows and beneath it on narrow ones.
public struct MCBriefing<Action: View, Detail: View>: View {
    private let title: String
    private let message: String?
    private let action: Action
    private let detail: Detail

    public init(title: String, message: String? = nil,
                @ViewBuilder action: () -> Action,
                @ViewBuilder detail: () -> Detail) {
        self.title = title
        self.message = message
        self.action = action()
        self.detail = detail()
    }

    public var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: MCSpacing.xl) {
                    lead.frame(width: 340, alignment: .leading)
                    detail
                        .frame(maxWidth: MCSize.columnMax, alignment: .leading)
                        .mcAppear(delay: 0.05)
                }
                VStack(alignment: .leading, spacing: MCSpacing.lg) {
                    lead
                    detail.mcAppear(delay: 0.05)
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: MCSize.contentMax, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var lead: some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            Text(title)
                .font(MCFont.heroTitle)
                .kerning(MCTracking.title)
                .fixedSize(horizontal: false, vertical: true)
            if let message {
                Text(message)
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            action
                .padding(.top, MCSpacing.xxs)
        }
        .mcAppear()
    }
}

public extension MCBriefing where Detail == EmptyView {
    init(title: String, message: String? = nil, @ViewBuilder action: () -> Action) {
        self.init(title: title, message: message, action: action, detail: { EmptyView() })
    }
}

// MARK: - Tag

/// Free-colour sibling of `MCStatusBadge` for labels that aren't a status
/// (a suggested keeper, a best-resolution pick, an update channel). Same
/// squared chip and monospaced caps, so every tag in the app looks alike.
public struct MCTag: View {
    private let text: String
    private let tint: Color

    public init(_ text: String, tint: Color = MCColor.teal) {
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        Text(text)
            .font(MCFont.badge)
            .textCase(.uppercase)
            .kerning(0.4)
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: MCRadius.small))
            .overlay(RoundedRectangle(cornerRadius: MCRadius.small).strokeBorder(tint.opacity(0.22), lineWidth: 1))
    }
}
