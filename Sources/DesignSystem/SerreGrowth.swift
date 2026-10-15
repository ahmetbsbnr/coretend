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

/// The soil band of the Overview (UI guide § 1, "strates du sol"): the used part of a volume as
/// soil, the free part as open, green ground, with a sprout at the boundary. It only draws what
/// was measured; the free part grows once when it appears.
public struct SoilBand: View {
    let used: Double
    let free: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    public init(used: Double, free: Double) {
        self.used = min(max(used, 0), 1)
        self.free = min(max(free, 0), 1)
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let freeWidth = width * free * (grown ? 1 : 0)
            ZStack(alignment: .leading) {
                // The used part: soil with a few strata lines.
                LeafCorner.control.shape.fill(Palette.deep.color)
                Canvas { context, size in
                    let usedWidth = size.width * used
                    for (index, y) in [0.3, 0.55, 0.78].enumerated() {
                        var line = Path()
                        line.move(to: CGPoint(x: 6, y: size.height * y))
                        line.addQuadCurve(to: CGPoint(x: max(usedWidth - 6, 6), y: size.height * y),
                                          control: CGPoint(x: usedWidth / 2, y: size.height * y + (index.isMultiple(of: 2) ? 2 : -2)))
                        context.stroke(line, with: .color(Palette.strongSeparator.color.opacity(0.55)), lineWidth: 1)
                    }
                }
                .clipShape(LeafCorner.control.shape)
                // The free part, from the trailing edge.
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LeafCorner.control.shape
                        .fill(Palette.accent.color.opacity(0.85))
                        .frame(width: freeWidth)
                }
                SerreIcon(.overview, size: 16)
                    .foregroundStyle(Palette.accent.color)
                    .offset(x: width - freeWidth - 8, y: -18)
                    .opacity(grown ? 1 : 0)
            }
        }
        .frame(height: 26)
        .padding(.top, 18)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion { grown = true } else {
                withAnimation(MotionCurve.sap.animation(duration: MotionToken.grow.duration).delay(0.15)) { grown = true }
            }
        }
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
