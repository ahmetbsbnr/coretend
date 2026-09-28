import SwiftUI

// Decision 0003, "la serre vivante": ambient motion is allowed only while the window is active
// and in front, the Mac is not in Low Power Mode, Reduce Motion is off and the person has not
// turned "Living greenhouse" off. Everything here goes still, in its final state, otherwise.

public extension EnvironmentValues {
    /// Set by the app: the window is active and in front, and the setting is on.
    @Entry var serreAmbientAllowed: Bool = false
}

/// Whether ambient motion may run now, all conditions of decision 0003 combined.
public struct AmbientLife {
    public static func isAlive(allowed: Bool, reduceMotion: Bool,
                               lowPower: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled) -> Bool {
        allowed && !reduceMotion && !lowPower
    }

    /// Low cadence: the greenhouse breathes, it does not flicker.
    public static let frameInterval = 1.0 / 15.0
}

/// The light of the greenhouse at a given hour: a warm dawn, a clear noon, a deep evening.
public enum GreenhouseLight: Equatable, Sendable {
    case dawn, day, dusk, night

    public static func at(hour: Int) -> GreenhouseLight {
        switch hour {
        case 5..<9: .dawn
        case 9..<18: .day
        case 18..<22: .dusk
        default: .night
        }
    }
}

/// What the greenhouse shows, all from measurements: how much ground is free, whether the last
/// action failed, whether something was recently moved to the Trash.
public struct GreenhouseState: Equatable, Sendable {
    public var freeFraction: Double?
    public var lastActionFailed: Bool
    public var recentlyPruned: Bool

    public init(freeFraction: Double?, lastActionFailed: Bool, recentlyPruned: Bool) {
        self.freeFraction = freeFraction.map { min(max($0, 0), 1) }
        self.lastActionFailed = lastActionFailed
        self.recentlyPruned = recentlyPruned
    }

    /// How tall the shoots stand (0…1): free ground lets them grow. Unknown free space: a
    /// middle height, never a guess drawn as fact (the figure beside it says "unknown").
    public var growth: Double { freeFraction.map { 0.35 + $0 * 0.65 } ?? 0.5 }
}

/// A glasshouse scene: arched panes, a soil bed, a row of shoots whose height follows the free
/// ground, a wilted shoot when the last action failed, a cut stem when something was pruned.
/// The leaves sway slowly while ambient life is allowed; otherwise the scene is still.
public struct GreenhouseScene: View {
    let state: GreenhouseState
    @Environment(\.serreAmbientAllowed) private var allowed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    public init(state: GreenhouseState) { self.state = state }

    public var body: some View {
        let alive = AmbientLife.isAlive(allowed: allowed, reduceMotion: reduceMotion)
        TimelineView(.animation(minimumInterval: AmbientLife.frameInterval, paused: !alive)) { context in
            let time = alive ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { canvas, size in draw(&canvas, size: size, time: time) }
        }
        .frame(height: 150)
        .background(sky, in: LeafCorner.parcel.shape)
        .clipShape(LeafCorner.parcel.shape)
        .overlay(LeafCorner.parcel.shape.strokeBorder(Palette.separator.color, lineWidth: 1))
        .scaleEffect(y: grown ? 1 : 0.96, anchor: .bottom)
        .opacity(grown ? 1 : 0)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion { grown = true } else {
                withAnimation(MotionCurve.sap.animation(duration: MotionToken.grow.duration)) { grown = true }
            }
        }
    }

    private var sky: LinearGradient {
        let hour = Calendar.current.component(.hour, from: .now)
        let top: Color
        switch GreenhouseLight.at(hour: hour) {
        case .dawn: top = Palette.caution.color.opacity(0.18)
        case .day: top = Palette.accent.color.opacity(0.14)
        case .dusk: top = Palette.danger.color.opacity(0.12)
        case .night: top = Palette.deep.color
        }
        return LinearGradient(colors: [top, Palette.surface.color], startPoint: .top, endPoint: .bottom)
    }

    private func draw(_ canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let w = size.width, h = size.height
        let soilTop = h * 0.78
        // Glass panes: three arches.
        for index in 0..<3 {
            let x0 = w * (0.04 + Double(index) * 0.32), x1 = x0 + w * 0.3
            var arch = Path()
            arch.move(to: CGPoint(x: x0, y: soilTop))
            arch.addQuadCurve(to: CGPoint(x: x1, y: soilTop), control: CGPoint(x: (x0 + x1) / 2, y: h * 0.02))
            canvas.stroke(arch, with: .color(Palette.strongSeparator.color.opacity(0.55)), lineWidth: 1)
            var mullion = Path()
            mullion.move(to: CGPoint(x: (x0 + x1) / 2, y: soilTop))
            mullion.addLine(to: CGPoint(x: (x0 + x1) / 2, y: h * 0.4))
            canvas.stroke(mullion, with: .color(Palette.strongSeparator.color.opacity(0.3)), lineWidth: 1)
        }
        // Soil bed.
        canvas.fill(Path(CGRect(x: 0, y: soilTop, width: w, height: h - soilTop)), with: .color(Palette.deep.color))
        // Shoots.
        let count = 13
        for index in 0..<count {
            let x = w * (0.08 + Double(index) * 0.84 / Double(count - 1))
            let wilted = state.lastActionFailed && index == count - 2
            let cut = state.recentlyPruned && index == 2
            let height = (h * 0.72) * state.growth * (0.75 + 0.25 * sin(Double(index) * 1.7 + 1))
            let sway = sin(time * 0.7 + Double(index) * 0.9) * 0.05
            shoot(&canvas, base: CGPoint(x: x, y: soilTop), height: cut ? height * 0.35 : height,
                  sway: wilted ? 0.55 : sway, wilted: wilted, cut: cut)
        }
    }

    private func shoot(_ canvas: inout GraphicsContext, base: CGPoint, height: Double, sway: Double,
                       wilted: Bool, cut: Bool) {
        let tip = CGPoint(x: base.x + sin(sway) * height, y: base.y - cos(sway) * height)
        var stem = Path()
        stem.move(to: base)
        stem.addQuadCurve(to: tip, control: CGPoint(x: base.x + sin(sway) * height * 0.3, y: base.y - height * 0.6))
        let tone = wilted ? Palette.danger.color : Palette.accent.color
        canvas.stroke(stem, with: .color(tone), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        guard !cut else { return }
        for (fraction, side) in [(0.4, -1.0), (0.62, 1.0), (0.85, -1.0)] {
            let at = CGPoint(x: base.x + (tip.x - base.x) * fraction, y: base.y + (tip.y - base.y) * fraction)
            let angle = side * (wilted ? 1.9 : 0.9) + sway * 2
            let length = 9.0 + height * 0.12
            var leaf = Path()
            leaf.move(to: at)
            let end = CGPoint(x: at.x + sin(angle) * length, y: at.y - cos(angle) * length)
            let control = CGPoint(x: at.x + sin(angle + 0.6 * side) * length * 0.7, y: at.y - cos(angle + 0.6 * side) * length * 0.7)
            leaf.addQuadCurve(to: end, control: control)
            leaf.addQuadCurve(to: at, control: CGPoint(x: at.x + sin(angle - 0.6 * side) * length * 0.7,
                                                      y: at.y - cos(angle - 0.6 * side) * length * 0.7))
            canvas.fill(leaf, with: .color(tone.opacity(0.85)))
        }
    }
}
