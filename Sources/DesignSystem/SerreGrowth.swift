import SwiftUI

/// The blocks of a view rise one after another when it appears (UI guide § 8: 12 pt,
/// `standard`, 35 ms apart, 240 ms at most). Under Reduce Motion they are simply there.
public struct SerreRise: ViewModifier {
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    public func body(content: Content) -> some View {
        content
            .offset(y: shown ? 0 : 12)
            .opacity(shown ? 1 : 0)
            .onAppear {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                let delay = min(Double(order) * 0.035, 0.24)
                withAnimation(MotionCurve.sap.animation(duration: MotionToken.standard.duration).delay(delay)) { shown = true }
            }
    }
}

public extension View {
    /// Rises into place as the `order`-th block of its view.
    func serreRise(_ order: Int) -> some View { modifier(SerreRise(order: order)) }
}

/// The capacity of a volume (decision 0008): the used part as a deep, slowly shimmering band, the
/// free part as a glowing green that fills in when it appears. It only draws what was measured.
public struct SoilBand: View {
    let used: Double
    let free: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.serreAmbientAllowed) private var allowed
    @State private var grown = false

    public init(used: Double, free: Double) {
        self.used = min(max(used, 0), 1)
        self.free = min(max(free, 0), 1)
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !allowed)) { timeline in
            let t = allowed ? timeline.date.timeIntervalSinceReferenceDate : 0
            GeometryReader { proxy in
                let width = proxy.size.width
                let usedWidth = width * used * (grown ? 1 : 0)
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.accent.color.opacity(0.18))
                        .overlay(Capsule().strokeBorder(Palette.accent.color.opacity(0.35), lineWidth: 1))
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.ink.color.opacity(0.85), Palette.ink.color.opacity(0.55)], startPoint: .leading, endPoint: .trailing))
                        .overlay {
                            // A slow band of light travelling over the used part.
                            let x = (t * 0.12).truncatingRemainder(dividingBy: 1.4) - 0.2
                            LinearGradient(stops: [.init(color: .clear, location: max(0, x - 0.08)), .init(color: .white.opacity(0.22), location: max(0, x)),
                                                   .init(color: .clear, location: min(1, x + 0.08))], startPoint: .leading, endPoint: .trailing)
                        }
                        .clipShape(Capsule())
                        .frame(width: max(usedWidth, 0))
                    Circle().fill(Palette.accent.color)
                        .frame(width: 10, height: 10)
                        .shadow(color: Palette.accent.color, radius: 8)
                        .offset(x: max(usedWidth - 5, 0))
                        .opacity(grown ? 1 : 0)
                }
            }
        }
        .frame(height: 18)
        .onAppear {
            if reduceMotion { grown = true } else { withAnimation(.spring(response: 1.3, dampingFraction: 0.8).delay(0.15)) { grown = true } }
        }
        .accessibilityHidden(true)
    }
}

/// Draws its content from left to right once, when it appears (UI guide § 8, Performance: "la
/// courbe de sève se trace de gauche à droite à l'apparition"). Under Reduce Motion it is drawn
/// at once.
public struct TraceReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    public func body(content: Content) -> some View {
        content
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle().frame(width: proxy.size.width * (revealed ? 1 : 0))
                }
            }
            .onAppear {
                guard !revealed else { return }
                if reduceMotion { revealed = true; return }
                withAnimation(MotionCurve.sap.animation(duration: MotionToken.bloom.duration)) { revealed = true }
            }
    }
}

public extension View {
    /// Traces the view from left to right once when it appears.
    func traceReveal() -> some View { modifier(TraceReveal()) }
}

/// A ring that swells and fades once, around a new point (UI guide § 8: "un nouveau point pulse
/// une fois"). It never repeats; under Reduce Motion it is not drawn.
public struct OncePulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spread = false

    public init() {}

    public var body: some View {
        Circle()
            .stroke(Palette.accent.color, lineWidth: 2)
            .frame(width: 14, height: 14)
            .scaleEffect(spread ? 2.6 : 1)
            .opacity(reduceMotion ? 0 : (spread ? 0 : 0.9))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(MotionCurve.sap.animation(duration: 0.9)) { spread = true }
            }
    }
}

/// A herbarium entry pressed into its page when the page appears (UI guide § 8, Record: scale
/// 1.02 → 1, 200 ms), `order` entries after the first (35 ms apart, 240 ms at most). Under Reduce
/// Motion it is simply there.
public struct SerrePress: ViewModifier {
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 1 : 1.02, anchor: .leading)
            .opacity(pressed ? 1 : 0)
            .onAppear {
                guard !pressed else { return }
                if reduceMotion { pressed = true; return }
                withAnimation(MotionCurve.sap.animation(duration: 0.2).delay(min(Double(order) * 0.035, 0.24))) { pressed = true }
            }
    }
}

public extension View {
    /// Presses the view into place as the `order`-th entry of its page.
    func serrePress(_ order: Int) -> some View { modifier(SerrePress(order: order)) }
}
