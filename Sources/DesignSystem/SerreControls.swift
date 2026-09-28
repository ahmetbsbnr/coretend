import SwiftUI

/// A risk badge (UI guide § 7): the risk leaf, its literal label, a tint of the leaf's colour.
public struct SerreRiskBadge: View {
    let level: RiskLevel
    let label: String

    public init(_ level: RiskLevel, label: String) {
        self.level = level
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 5) {
            RiskLeaf(level, size: 11)
            Text(label)
        }
        .font(CoreTendTypography.caption.weight(.semibold))
        .foregroundStyle(Palette.ink.color)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(tone.opacity(0.14), in: LeafCorner.control.shape)
        .accessibilityElement(children: .combine)
    }

    private var tone: Color {
        switch level {
        case .low: Palette.accent.color
        case .medium: Palette.caution.color
        case .high: Palette.danger.color
        }
    }
}

/// The selection mark of a list row (UI guide § 7, "Case / sélection"): an open circle that
/// takes the accent on hover, and fills with a small leaf when chosen. Purely visual; the row's
/// button carries the action and the accessibility state.
public struct SerreCheck: View {
    let isOn: Bool
    @Environment(\.serreHover) private var hovered

    public init(isOn: Bool) { self.isOn = isOn }

    public var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn || hovered ? Palette.accent.color : Palette.strongSeparator.color, lineWidth: 1.5)
            if isOn {
                Circle().fill(Palette.accent.color)
                RiskLeafShape(level: .low)
                    .fill(Palette.onAccent.color)
                    .frame(width: 9, height: 9)
                    .rotationEffect(.degrees(35))
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

/// A leaf that falls from a row to the Trash indicator (UI guide § 8, "Déplacement vers la
/// Corbeille"): the row's file first becomes a leaf (it opens with a small spring), then the leaf
/// falls, drifting sideways with sap while it drops with the falling curve, which bends its path,
/// and turning as it goes. It stays opaque until it reaches the Trash; its owner removes it after
/// `duration`. It is only shown for a file that has actually been moved; under Reduce Motion it is
/// never shown.
public struct FallingLeaf: View {
    /// Opening, then falling.
    public static let opening = 0.14
    public static let fall = 0.5
    public static let duration = opening + fall

    let from: CGPoint
    let to: CGPoint
    @State private var opened = false
    @State private var landed = false

    public init(from: CGPoint, to: CGPoint) {
        self.from = from
        self.to = to
    }

    public var body: some View {
        RiskLeafShape(level: .low)
            .fill(Palette.accent.color)
            .overlay(RiskLeafShape(level: .low).stroke(Palette.onAccent.color.opacity(0.5), lineWidth: 1))
            .frame(width: 22, height: 22)
            .shadow(color: Palette.deep.color.opacity(0.5), radius: 4, y: 2)
            .scaleEffect(landed ? 0.7 : (opened ? 1 : 0.3))
            .rotationEffect(.degrees(landed ? 140 : -20))
            .animation(MotionCurve.sap.animation(duration: Self.fall)) {
                $0.offset(x: landed ? to.x - from.x : 0)
            }
            .animation(MotionCurve.fall.animation(duration: Self.fall)) {
                $0.offset(y: landed ? to.y - from.y : 0)
            }
            .position(from)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(MotionCurve.sprout.animation(duration: Self.opening)) { opened = true }
                withAnimation(MotionCurve.fall.animation(duration: Self.fall).delay(Self.opening)) { landed = true }
            }
    }
}
