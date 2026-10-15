import SwiftUI

/// The air of the greenhouse (decision 0008): a deep ground with glows that drift, light falling
/// through the glass and a fine grain. It moves only while ambient motion is allowed; otherwise it
/// is drawn once, still.
public struct AtmosphereBackdrop: View {
    @Environment(\.serreAmbientAllowed) private var allowed
    @Environment(\.colorScheme) private var scheme

    public init() {}

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !allowed)) { timeline in
            let t = allowed ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas(rendersAsynchronously: true) { context, size in
                Atmosphere.draw(in: &context, size: size, time: t, dark: scheme == .dark)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

enum Atmosphere {
    struct Glow { let hue: Color; let x: Double; let y: Double; let radius: Double; let speed: Double; let phase: Double }

    static func glows(dark: Bool) -> [Glow] {
        dark ? [
            Glow(hue: Color(red: 0.16, green: 0.62, blue: 0.38), x: 0.18, y: 0.12, radius: 0.55, speed: 0.050, phase: 0),
            Glow(hue: Color(red: 0.05, green: 0.45, blue: 0.47), x: 0.85, y: 0.30, radius: 0.60, speed: 0.037, phase: 2.1),
            Glow(hue: Color(red: 0.55, green: 0.85, blue: 0.30), x: 0.55, y: 0.95, radius: 0.50, speed: 0.044, phase: 4.0),
            Glow(hue: Color(red: 0.10, green: 0.30, blue: 0.20), x: 0.30, y: 0.65, radius: 0.70, speed: 0.029, phase: 1.3),
        ] : [
            Glow(hue: Color(red: 0.66, green: 0.88, blue: 0.62), x: 0.15, y: 0.10, radius: 0.55, speed: 0.050, phase: 0),
            Glow(hue: Color(red: 0.55, green: 0.82, blue: 0.80), x: 0.88, y: 0.25, radius: 0.60, speed: 0.037, phase: 2.1),
            Glow(hue: Color(red: 0.93, green: 0.95, blue: 0.62), x: 0.60, y: 0.95, radius: 0.45, speed: 0.044, phase: 4.0),
            Glow(hue: Color(red: 0.70, green: 0.86, blue: 0.70), x: 0.35, y: 0.60, radius: 0.70, speed: 0.029, phase: 1.3),
        ]
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, time t: Double, dark: Bool) {
        let rect = CGRect(origin: .zero, size: size)
        let top = dark ? Color(red: 0.035, green: 0.09, blue: 0.065) : Color(red: 0.86, green: 0.92, blue: 0.84)
        let bottom = dark ? Color(red: 0.02, green: 0.055, blue: 0.04) : Color(red: 0.78, green: 0.87, blue: 0.76)
        context.fill(Path(rect), with: .linearGradient(Gradient(colors: [top, bottom]), startPoint: .zero, endPoint: CGPoint(x: size.width * 0.3, y: size.height)))

        // Glows drifting slowly on Lissajous paths.
        let side = max(size.width, size.height)
        for glow in glows(dark: dark) {
            let cx = (glow.x + 0.08 * sin(t * glow.speed * 2 + glow.phase)) * size.width
            let cy = (glow.y + 0.06 * cos(t * glow.speed * 3 + glow.phase)) * size.height
            let r = glow.radius * side * (1 + 0.05 * sin(t * glow.speed * 5 + glow.phase))
            let shading = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [glow.hue.opacity(dark ? 0.55 : 0.75), glow.hue.opacity(0)]),
                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r)
            context.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: shading)
        }

        // Light falling through the glass: soft slanted shafts that breathe.
        context.drawLayer { layer in
            layer.blendMode = dark ? .plusLighter : .softLight
            for i in 0..<5 {
                let base = Double(i) / 5
                let x = (0.1 + base * 0.9 + 0.02 * sin(t * 0.07 + Double(i))) * size.width
                let w = size.width * (0.05 + 0.03 * Double(i % 3))
                let alpha = (dark ? 0.05 : 0.18) * (0.6 + 0.4 * sin(t * 0.21 + Double(i) * 1.7))
                var shaft = Path()
                shaft.move(to: CGPoint(x: x, y: -10))
                shaft.addLine(to: CGPoint(x: x + w, y: -10))
                shaft.addLine(to: CGPoint(x: x + w + size.height * 0.45, y: size.height))
                shaft.addLine(to: CGPoint(x: x + size.height * 0.45, y: size.height))
                shaft.closeSubpath()
                layer.fill(shaft, with: .linearGradient(Gradient(colors: [Color.white.opacity(alpha), Color.white.opacity(0)]),
                                                        startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + size.height * 0.3, y: size.height * 0.8)))
            }
        }

        // Grain: a fixed scatter of specks so flat areas never look printed.
        var generator = SeededRandom(seed: 7)
        let specks = Int(min(1400, size.width * size.height / 900))
        for _ in 0..<specks {
            let x = generator.next() * size.width, y = generator.next() * size.height
            let a = generator.next() * (dark ? 0.06 : 0.05)
            context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color((dark ? Color.white : Color.black).opacity(a)))
        }
    }
}

/// A small deterministic random source, so drawings are the same on every frame and launch.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }
}

// MARK: - Glass

/// Tinted glass for every parcel (decision 0008): a material, a green tint, a bright upper edge,
/// a soft shadow, and a glow that follows the pointer while it is over the glass.
public struct SerreGlass: ViewModifier {
    let cornerRadius: CGFloat
    let glow: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.serreAmbientAllowed) private var allowed
    @State private var pointer: CGPoint?

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let dark = scheme == .dark
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(LinearGradient(colors: dark
                        ? [Color(red: 0.10, green: 0.24, blue: 0.17).opacity(0.72), Color(red: 0.05, green: 0.14, blue: 0.10).opacity(0.80)]
                        : [Color(red: 0.97, green: 1.0, blue: 0.95).opacity(0.62), Color(red: 0.86, green: 0.94, blue: 0.84).opacity(0.70)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    if glow, let pointer {
                        GeometryReader { proxy in
                            RadialGradient(colors: [Palette.accent.color.opacity(dark ? 0.24 : 0.18), .clear],
                                           center: UnitPoint(x: pointer.x / max(proxy.size.width, 1), y: pointer.y / max(proxy.size.height, 1)),
                                           startRadius: 0, endRadius: 280)
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: dark
                    ? [Color.white.opacity(0.22), Color(red: 0.6, green: 0.9, blue: 0.5).opacity(0.10), Color.white.opacity(0.04)]
                    : [Color.white.opacity(0.95), Color.white.opacity(0.35), Color(red: 0.4, green: 0.6, blue: 0.45).opacity(0.25)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .clipShape(shape)
            .shadow(color: Color.black.opacity(dark ? 0.45 : 0.10), radius: 18, x: 0, y: 10)
            .onContinuousHover { phase in
                guard glow else { return }
                switch phase {
                case .active(let location): pointer = location
                case .ended: withAnimation(.easeOut(duration: 0.4)) { pointer = nil }
                }
            }
    }
}

public extension View {
    /// The Serre glass (decision 0008).
    func serreGlass(cornerRadius: CGFloat = 22, glow: Bool = true) -> some View {
        modifier(SerreGlass(cornerRadius: cornerRadius, glow: glow))
    }

    /// Enters after `index` steps: rises, sharpens and settles with a spring.
    func cascade(_ index: Int) -> some View { modifier(Cascade(index: index)) }
}

struct Cascade: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 26)
            .blur(radius: shown ? 0 : 10)
            .scaleEffect(shown ? 1 : 0.97, anchor: .top)
            .onAppear {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                withAnimation(.spring(response: 0.7, dampingFraction: 0.78).delay(Double(index) * 0.07)) { shown = true }
            }
    }
}

// MARK: - Figures and calls to action

/// A figure that counts up to its value, formatted on every step.
public struct CountingText: View, Animatable {
    var value: Double
    let format: @Sendable (Double) -> String

    public nonisolated init(value: Double, format: @escaping @Sendable (Double) -> String) {
        self.value = value
        self.format = format
    }

    public nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    public var body: some View { Text(format(value)) }
}

/// The one big button of a space: a glowing seed of light with a breathing halo.
public struct GlowButtonStyle: ButtonStyle {
    @Environment(\.serreAmbientAllowed) private var allowed
    @Environment(\.isEnabled) private var enabled
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        GlowButtonBody(configuration: configuration, allowed: allowed, enabled: enabled)
    }
}

private struct GlowButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let allowed: Bool
    let enabled: Bool
    @State private var hover = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !allowed || !enabled)) { timeline in
            let t = allowed ? timeline.date.timeIntervalSinceReferenceDate : 0
            let breath = 0.5 + 0.5 * sin(t * 2.2)
            configuration.label
                .font(.custom("AvenirNext-DemiBold", size: 16, relativeTo: .headline))
                .foregroundStyle(Palette.onAccent.color)
                .padding(.horizontal, 26).padding(.vertical, 14)
                .background {
                    Capsule().fill(LinearGradient(colors: [Palette.accent.color, Palette.accent.color.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                        .overlay(alignment: .top) {
                            Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                                .frame(height: 18).padding(.horizontal, 6).padding(.top, 2)
                        }
                }
                .background {
                    Capsule().stroke(Palette.accent.color.opacity(enabled ? 0.45 * (1 - breath) : 0), lineWidth: 2)
                        .scaleEffect(1 + 0.18 * breath)
                }
                .shadow(color: Palette.accent.color.opacity(enabled ? (hover ? 0.7 : 0.45) : 0), radius: hover ? 22 : 14, y: 6)
                .scaleEffect(configuration.isPressed ? 0.95 : (hover ? 1.04 : 1))
                .opacity(enabled ? 1 : 0.45)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hover)
        }
        .onHover { hover = $0 }
    }
}
