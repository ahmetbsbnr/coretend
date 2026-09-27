import SwiftUI

/// Serre buttons (Documentation/Design/UI-guide.md § 7). Every kind has rest, hover, pressed,
/// focus and disabled states; the whole shape is clickable.
public enum SerreButtonKind: Equatable, Sendable {
    /// The one main action of a view: chlorophyll fill.
    case primary
    /// Every other action: outlined leaf.
    case secondary
    /// An action that cannot be undone, labelled literally: terracotta fill.
    case destructive
    /// A full-width row: hover draws a vein under it from the leading edge.
    case row(selected: Bool)
    /// A small icon-only control.
    case icon
    /// A thumbnail or other content that is itself the button: outline on hover.
    case tile
}

public struct SerreButtonStyle: ButtonStyle {
    let kind: SerreButtonKind

    public init(_ kind: SerreButtonKind) { self.kind = kind }

    public func makeBody(configuration: Configuration) -> some View {
        SerreButtonBody(kind: kind, configuration: configuration)
    }
}

public extension ButtonStyle where Self == SerreButtonStyle {
    static func serre(_ kind: SerreButtonKind) -> SerreButtonStyle { SerreButtonStyle(kind) }
}

/// Whether the enclosing Serre control is hovered; SerreIcon tilts when it is.
private struct SerreHoverKey: EnvironmentKey { static let defaultValue = false }

/// Whether Serre buttons draw their own focus ring. A focusable container whose selection is
/// its focus indicator (the sidebar) turns it off: its descendants all read as focused.
private struct SerreFocusRingKey: EnvironmentKey { static let defaultValue = true }

public extension EnvironmentValues {
    var serreHover: Bool {
        get { self[SerreHoverKey.self] }
        set { self[SerreHoverKey.self] = newValue }
    }

    var serreFocusRing: Bool {
        get { self[SerreFocusRingKey.self] }
        set { self[SerreFocusRingKey.self] = newValue }
    }
}

private struct SerreButtonBody: View {
    let kind: SerreButtonKind
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.serreFocusRing) private var focusRing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    var body: some View {
        SerreButtonChrome(kind: kind, state: .init(hovered: hovered, pressed: configuration.isPressed, focused: isFocused && focusRing, enabled: isEnabled)) {
            configuration.label
        }
        .onHover { inside in
            withAnimation(MotionToken.quick.animation(reduceMotion: reduceMotion)) { hovered = inside && isEnabled }
        }
        .animation(MotionToken.press.animation(reduceMotion: reduceMotion), value: configuration.isPressed)
        .focusEffectDisabled()
    }
}

public struct SerreControlState: Equatable, Sendable {
    public var hovered = false
    public var pressed = false
    public var focused = false
    public var enabled = true

    public init(hovered: Bool = false, pressed: Bool = false, focused: Bool = false, enabled: Bool = true) {
        self.hovered = hovered
        self.pressed = pressed
        self.focused = focused
        self.enabled = enabled
    }
}

/// The drawing of a Serre button in a given state, separate from interaction so every state
/// can be rendered and checked.
public struct SerreButtonChrome<Label: View>: View {
    let kind: SerreButtonKind
    let state: SerreControlState
    let label: Label

    public init(kind: SerreButtonKind, state: SerreControlState, @ViewBuilder label: () -> Label) {
        self.kind = kind
        self.state = state
        self.label = label()
    }

    public var body: some View {
        let shape = LeafCorner.control.shape
        content
            .environment(\.serreHover, state.hovered)
            .contentShape(shape)
            .overlay { if state.focused { shape.inset(by: -3).stroke(Palette.focus.color, lineWidth: 2) } }
            .scaleEffect(state.pressed ? 0.97 : 1)
            .opacity(state.enabled ? 1 : 0.4)
    }

    @ViewBuilder private var content: some View {
        let shape = LeafCorner.control.shape
        switch kind {
        case .primary:
            label.font(CoreTendTypography.body.weight(.semibold))
                .foregroundStyle(Palette.onAccent.color)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Palette.accent.color, in: shape)
                // Hover lightens by about 8 % in both appearances.
                .brightness(state.hovered ? 0.08 : 0)
        case .secondary:
            label.font(CoreTendTypography.body.weight(.medium))
                .foregroundStyle(Palette.ink.color)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(state.hovered ? Palette.accent.color.opacity(0.08) : Color.clear, in: shape)
                .overlay(shape.strokeBorder(state.hovered ? Palette.accent.color : Palette.strongSeparator.color, lineWidth: 1))
        case .destructive:
            label.font(CoreTendTypography.body.weight(.semibold))
                .foregroundStyle(Palette.onAccent.color)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Palette.danger.color, in: shape)
                .brightness(state.hovered ? 0.08 : 0)
        case .row(let selected):
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(rowFill(selected: selected), in: shape)
                .overlay(alignment: .bottom) { Vein(progress: state.hovered ? 1 : 0).padding(.horizontal, 12) }
        case .icon:
            label.foregroundStyle(state.hovered ? Palette.accent.color : Palette.secondaryInk.color)
                .frame(minWidth: 28, minHeight: 28)
                .background(state.hovered ? Palette.accent.color.opacity(0.1) : Color.clear, in: shape)
        case .tile:
            label.overlay(shape.strokeBorder(state.hovered ? Palette.accent.color : Color.clear, lineWidth: 2))
                .offset(y: state.hovered ? -1 : 0)
        }
    }

    private func rowFill(selected: Bool) -> Color {
        if state.pressed { return Palette.accent.color.opacity(0.14) }
        if selected { return Palette.accent.color.opacity(0.16) }
        return state.hovered ? Palette.accent.color.opacity(0.06) : Color.clear
    }
}

/// The leaf vein drawn under a hovered row, from the leading edge; animatable so it grows.
private struct Vein: View {
    let progress: Double

    var body: some View {
        VeinShape(progress: progress)
            .stroke(Palette.accent.color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(height: 1.5)
            .accessibilityHidden(true)
    }
}

struct VeinShape: Shape {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0 else { return path }
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * min(progress, 1), y: rect.midY))
        return path
    }
}
