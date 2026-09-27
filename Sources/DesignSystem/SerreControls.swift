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
/// Corbeille"): it drifts sideways with sap while it drops with the falling curve, which bends
/// its path, and turns as it goes (500 ms). Its owner removes it after `duration`. It is only
/// shown for a file that has actually been moved; under Reduce Motion it is never shown.
public struct FallingLeaf: View {
    public static let duration = 0.5

    let from: CGPoint
    let to: CGPoint
    @State private var landed = false

    public init(from: CGPoint, to: CGPoint) {
        self.from = from
        self.to = to
    }

    public var body: some View {
        RiskLeafShape(level: .low)
            .fill(Palette.accent.color)
            .frame(width: 16, height: 16)
            .rotationEffect(.degrees(landed ? 150 : 0))
            .scaleEffect(landed ? 0.6 : 1)
            .opacity(landed ? 0.2 : 1)
            .animation(MotionCurve.sap.animation(duration: Self.duration)) {
                $0.offset(x: landed ? to.x - from.x : 0)
            }
            .animation(MotionCurve.fall.animation(duration: Self.duration)) {
                $0.offset(y: landed ? to.y - from.y : 0)
            }
            .position(from)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(MotionCurve.fall.animation(duration: Self.duration)) { landed = true }
            }
    }
}
