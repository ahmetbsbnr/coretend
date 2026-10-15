import SwiftUI

// Decision 0009: Serre motion, always with a cause, drawn in the Serre materials only.

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

/// A small deterministic random source, so a drawing is the same on every frame and launch.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }
}

/// Leaves that fall from a control when `trigger` changes: a short scatter, then gravity and a
/// slow spin, like leaves shaken from a stem. Flat leaves in the accent; nothing glows.
public struct LeafFall: View {
    let trigger: Int
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?

    public init(trigger: Int, tint: Color) { self.trigger = trigger; self.tint = tint }

    public var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let age = timeline.date.timeIntervalSince(start)
                guard age < 1.1 else { return }
                var random = SeededRandom(seed: UInt64(trigger + 3))
                let origin = CGPoint(x: size.width / 2, y: size.height / 2)
                for _ in 0..<9 {
                    let angle = -Double.pi / 2 + (random.next() - 0.5) * 2.4
                    let speed = 55 + random.next() * 70
                    let sway = (random.next() - 0.5) * 30
                    let x = origin.x + cos(angle) * speed * age + sin(age * 7 + random.next() * 6) * sway * age
                    let y = origin.y + sin(angle) * speed * age + 190 * age * age
                    var leaf = context
                    leaf.translateBy(x: x, y: y)
                    leaf.rotate(by: .radians(angle + (random.next() - 0.5) * 9 * age))
                    leaf.opacity = max(0, 1 - age / 1.1)
                    var path = Path()
                    path.move(to: .zero)
                    path.addQuadCurve(to: CGPoint(x: 10, y: 0), control: CGPoint(x: 5, y: -4.5))
                    path.addQuadCurve(to: .zero, control: CGPoint(x: 5, y: 3))
                    leaf.fill(path, with: .color(tint))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            start = .now
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1150))
                start = nil
            }
        }
        .accessibilityHidden(true)
    }
}

/// A stem measuring one share against the largest: it grows from the soil when it appears and
/// takes the accent while its group is ticked.
public struct StemMeasure: View {
    let fraction: Double
    let lit: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    public init(fraction: Double, lit: Bool) {
        self.fraction = min(max(fraction, 0), 1)
        self.lit = lit
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = max(8, proxy.size.width * fraction * (grown ? 1 : 0))
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.separator.color.opacity(0.55)).frame(height: 2)
                Capsule().fill(lit ? Palette.accent.color : Palette.strongSeparator.color)
                    .frame(width: width, height: 4)
                // A leaf at the tip of the stem.
                RiskLeafShape(level: .low)
                    .fill(lit ? Palette.accent.color : Palette.strongSeparator.color)
                    .frame(width: 9, height: 9)
                    .rotationEffect(.degrees(-35))
                    .offset(x: width - 3, y: -4)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 12)
        .animation(MotionToken.quick.animation(reduceMotion: reduceMotion), value: lit)
        .onAppear {
            if reduceMotion { grown = true } else {
                withAnimation(MotionCurve.sprout.animation(duration: 0.9).delay(0.2)) { grown = true }
            }
        }
        .accessibilityHidden(true)
    }
}
