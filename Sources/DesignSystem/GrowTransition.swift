import SwiftUI

/// The "pousse" reveal (UI guide § 8): a view grows as an ellipse opening from `origin`, the
/// point in the view level with the sidebar row that was chosen, until it covers the whole view.
public struct GrowMask: ViewModifier, Animatable {
    public var progress: Double
    let origin: CGPoint

    public nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    public nonisolated init(progress: Double, origin: CGPoint) {
        self.progress = progress
        self.origin = origin
    }

    /// Distance from `origin` to the farthest corner of a view of `size`: a circle of this radius
    /// covers the view.
    public nonisolated static func radius(origin: CGPoint, in size: CGSize) -> Double {
        [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            .map { hypot(Double($0.x - origin.x), Double($0.y - origin.y)) }
            .max() ?? 0
    }

    public func body(content: Content) -> some View {
        content.mask {
            GeometryReader { proxy in
                let radius = Self.radius(origin: origin, in: proxy.size) * progress
                Ellipse()
                    .frame(width: radius * 2, height: radius * 2 * 0.92)
                    .position(origin)
            }
        }
    }
}

public extension AnyTransition {
    /// A view that grows from `origin` as it arrives and settles away as it leaves.
    /// Under Reduce Motion, a 120 ms crossfade.
    static func grow(from origin: CGPoint, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity.animation(.easeOut(duration: 0.12)) }
        let arrive = AnyTransition.modifier(active: GrowMask(progress: 0, origin: origin), identity: GrowMask(progress: 1, origin: origin))
            .combined(with: .offset(y: 12))
            .animation(MotionCurve.sap.animation(duration: MotionToken.grow.duration))
        let leave = AnyTransition.opacity.combined(with: .offset(y: 6))
            .animation(MotionCurve.retreat.animation(duration: 0.18))
        return .asymmetric(insertion: arrive, removal: leave)
    }
}
