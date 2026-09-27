import SwiftUI

/// Motion tokens for immediate feedback and short, interruptible content transitions.
public enum MotionToken: CaseIterable, Sendable {
    case quick, standard, gentle

    public var duration: Double {
        switch self {
        case .quick: 0.15
        case .standard: 0.24
        case .gentle: 0.28
        }
    }

    /// Returns nil under Reduce Motion so changes apply immediately.
    public func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .smooth(duration: duration)
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
