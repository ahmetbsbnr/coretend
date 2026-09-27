import SwiftUI

/// Motion durations (Documentation/Design/UI-guide.md § 8).
public enum MotionToken: CaseIterable, Sendable {
    /// Pressing a control.
    case press
    /// Hover, focus, the vein under a row.
    case quick
    /// Search opening, panels, banners.
    case standard
    /// Changing destination, revealing a view.
    case grow
    /// Logo germination, the bloom at the end of a scan.
    case bloom

    public var duration: Double {
        switch self {
        case .press: 0.09
        case .quick: 0.16
        case .standard: 0.28
        case .grow: 0.48
        case .bloom: 1.2
        }
    }

    /// Returns nil under Reduce Motion so changes apply immediately.
    public func animation(_ curve: MotionCurve = .sap, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : curve.animation(duration: duration)
    }

    /// Default sap curve; kept for existing call sites.
    public func animation(reduceMotion: Bool) -> Animation? {
        animation(.sap, reduceMotion: reduceMotion)
    }
}

/// How things move in the greenhouse.
public enum MotionCurve: CaseIterable, Sendable {
    /// Default: a lively start and a soft arrival.
    case sap
    /// A small spring with a little overshoot. Small elements only, never a whole view.
    case sprout
    /// Something falling, such as a leaf dropping into the Trash.
    case fall
    /// Something retracting or disappearing.
    case retreat

    public func animation(duration: Double) -> Animation {
        switch self {
        case .sap: .timingCurve(0.2, 0.8, 0.2, 1, duration: duration)
        case .sprout: .spring(response: max(duration, 0.2), dampingFraction: 0.72)
        case .fall: .timingCurve(0.55, 0, 0.8, 0.4, duration: duration)
        case .retreat: .timingCurve(0.4, 0, 1, 1, duration: duration)
        }
    }
}

private struct MotionAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let token: MotionToken
    let value: Value

    func body(content: Content) -> some View {
        content.animation(token.animation(reduceMotion: reduceMotion), value: value)
    }
}

public extension View {
    /// Animates changes to `value` with a motion token, or not at all under Reduce Motion.
    func motion<Value: Equatable>(_ token: MotionToken, value: Value) -> some View {
        modifier(MotionAnimationModifier(token: token, value: value))
    }
}

/// Runs a state change with a motion token, or without animation under Reduce Motion.
@MainActor
public func withMotion(_ token: MotionToken, reduceMotion: Bool, _ change: () -> Void) {
    if let animation = token.animation(reduceMotion: reduceMotion) {
        withAnimation(animation, change)
    } else {
        change()
    }
}
