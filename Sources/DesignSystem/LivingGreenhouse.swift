import SwiftUI
import AppKit
import QuartzCore

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
    public static let frameInterval = 1.0 / 10.0
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
    static let count = 13
    let state: GreenhouseState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    public init(state: GreenhouseState) { self.state = state }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                Canvas { canvas, size in drawGlass(&canvas, size: size) }
                PollenField(density: 1)
                ForEach(0..<Self.count, id: \.self) { index in
                    ShootView(state: state, index: index, count: Self.count, size: size)
                }
            }
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

    private func drawGlass(_ canvas: inout GraphicsContext, size: CGSize) {
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
    }

}

/// One shoot of the scene, drawn in place and swaying on its own.
private struct ShootView: View {
    let state: GreenhouseState
    let index: Int
    let count: Int
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        let soilTop = h * 0.78
        let x = w * (0.08 + Double(index) * 0.84 / Double(count - 1))
        let wilted = state.lastActionFailed && index == count - 2
        let cut = state.recentlyPruned && index == 2
        let full = (h * 0.72) * state.growth * (0.75 + 0.25 * sin(Double(index) * 1.7 + 1))
        let height = cut ? full * 0.35 : full
        let box = CGSize(width: 44, height: max(height, 4))
        Canvas { canvas, _ in
            shoot(&canvas, base: CGPoint(x: box.width / 2, y: box.height), height: height,
                  lean: wilted ? 0.55 : 0, wilted: wilted, cut: cut)
        }
        .frame(width: box.width, height: box.height)
        .ambientSway(degrees: wilted || cut ? 0 : 6, phase: Double(index) * 0.37)
        .position(x: x, y: soilTop - box.height / 2)
    }

    private func shoot(_ canvas: inout GraphicsContext, base: CGPoint, height: Double, lean: Double,
                       wilted: Bool, cut: Bool) {
        let tip = CGPoint(x: base.x + sin(lean) * height, y: base.y - cos(lean) * height)
        var stem = Path()
        stem.move(to: base)
        stem.addQuadCurve(to: tip, control: CGPoint(x: base.x + sin(lean) * height * 0.3, y: base.y - height * 0.6))
        let tone = wilted ? Palette.danger.color : Palette.accent.color
        canvas.stroke(stem, with: .color(tone), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        guard !cut else { return }
        for (fraction, side) in [(0.4, -1.0), (0.62, 1.0), (0.85, -1.0)] {
            let at = CGPoint(x: base.x + (tip.x - base.x) * fraction, y: base.y + (tip.y - base.y) * fraction)
            let angle = side * (wilted ? 1.9 : 0.9) + lean * 2
            let length = 9.0 + height * 0.12
            var leaf = Path()
            leaf.move(to: at)
            let end = CGPoint(x: at.x + sin(angle) * length, y: at.y - cos(angle) * length)
            leaf.addQuadCurve(to: end, control: CGPoint(x: at.x + sin(angle + 0.6 * side) * length * 0.7, y: at.y - cos(angle + 0.6 * side) * length * 0.7))
            leaf.addQuadCurve(to: at, control: CGPoint(x: at.x + sin(angle - 0.6 * side) * length * 0.7, y: at.y - cos(angle - 0.6 * side) * length * 0.7))
            canvas.fill(leaf, with: .color(tone.opacity(0.85)))
        }
    }
}

/// A slow sway around the bottom of the view, like a stem in still air (decision 0003): only
/// while ambient life is allowed, otherwise upright and still. `phase` keeps neighbours apart.
public struct AmbientSway: ViewModifier {
    let degrees: Double
    let phase: Double
    var period: Double = 2.6
    /// A sway caused by an action (a scan running) runs whenever motion is allowed at all.
    var caused = false
    @Environment(\.serreAmbientAllowed) private var allowed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        LayerSway(content: AnyView(content), degrees: degrees, phase: phase, period: period,
                  alive: caused ? !reduceMotion : AmbientLife.isAlive(allowed: allowed, reduceMotion: reduceMotion))
    }
}

/// Hosts the content in a layer that Core Animation rotates on the render server: the app does
/// no work per frame, so the whole greenhouse can live for almost no CPU. The animation is
/// removed, and the layer set upright, as soon as life is not allowed.
struct LayerSway: NSViewRepresentable {
    let content: AnyView
    let degrees: Double
    let phase: Double
    let period: Double
    let alive: Bool

    func makeNSView(context: Context) -> SwayHost {
        SwayHost(rootView: content)
    }

    func updateNSView(_ view: SwayHost, context: Context) {
        view.rootView = content
        view.update(alive: alive, degrees: degrees, phase: phase, period: period)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: SwayHost, context: Context) -> CGSize? {
        nsView.fittingSize
    }
}

final class SwayHost: NSHostingView<AnyView> {
    private var current: (alive: Bool, degrees: Double, period: Double)?

    required init(rootView: AnyView) {
        super.init(rootView: rootView)
        wantsLayer = true
    }

    @MainActor @preconcurrency required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        // Rotate around the bottom centre, like a stem from the soil.
        guard let layer else { return }
        let frame = layer.frame
        layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        layer.position = CGPoint(x: frame.midX, y: frame.minY)
    }

    func update(alive: Bool, degrees: Double, phase: Double, period: Double) {
        guard let layer else { return }
        if let current, current.alive == alive, current.degrees == degrees, current.period == period { return }
        current = (alive, degrees, period)
        layer.removeAnimation(forKey: "sway")
        guard alive, degrees != 0 else { return }
        let radians = degrees * .pi / 180
        let sway = CABasicAnimation(keyPath: "transform.rotation.z")
        sway.fromValue = -radians
        sway.toValue = radians
        sway.duration = period + phase.truncatingRemainder(dividingBy: period * 0.5)
        sway.beginTime = CACurrentMediaTime() - phase
        sway.autoreverses = true
        sway.repeatCount = .infinity
        sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(sway, forKey: "sway")
    }
}

public extension View {
    /// Sways slowly while the greenhouse is alive.
    func ambientSway(degrees: Double = 3, phase: Double = 0, period: Double = 2.6, caused: Bool = false) -> some View {
        modifier(AmbientSway(degrees: degrees, phase: phase, period: period, caused: caused))
    }
}

/// What the page is doing, as its plant shows it.
public enum PlantActivity: Equatable, Sendable {
    case resting, growing, blooming
}

/// Lets a page tell its header plant what it is doing (a scan running, a scan finished).
public struct PlantActivityKey: PreferenceKey {
    public static let defaultValue = PlantActivity.resting
    public static func reduce(value: inout PlantActivity, nextValue: () -> PlantActivity) {
        let next = nextValue()
        if next != .resting { value = next }
    }
}

/// The plant of a destination, beside its title: its glyph grown large on a line of soil. It
/// grows once when the page opens, sways while the greenhouse is alive, bends hard while the
/// page works (a scan running) and blooms when the work is done.
public struct DestinationPlant: View {
    let glyph: SerreGlyph
    let activity: PlantActivity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    public init(_ glyph: SerreGlyph, activity: PlantActivity = .resting) {
        self.glyph = glyph
        self.activity = activity
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                SerreGlyphShape(glyph: glyph)
                    .trim(from: 0, to: grown ? 1 : 0)
                    .stroke(Palette.accent.color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 58, height: 58)
                FlowerHead(open: activity == .blooming)
                    .offset(y: -10)
            }
            .ambientSway(degrees: activity == .growing ? 12 : 7, phase: Double(glyph.hashValue % 7),
                         period: activity == .growing ? 0.9 : 2.6, caused: activity == .growing)
            Capsule().fill(Palette.deep.color).frame(width: 84, height: 5)
        }
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion { grown = true } else {
                withAnimation(MotionCurve.sap.animation(duration: MotionToken.bloom.duration)) { grown = true }
            }
        }
    }
}

/// A flower that opens once at the top of a plant when a page's work is done.
struct FlowerHead: View {
    let open: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Ellipse().fill(Palette.accent.color.opacity(0.9)).frame(width: 7, height: 12)
                    .offset(y: -7).rotationEffect(.degrees(Double(index) * 60))
            }
            Circle().fill(Palette.caution.color).frame(width: 7, height: 7)
        }
        .scaleEffect(open ? 1 : 0.05)
        .rotationEffect(.degrees(open ? 0 : -90))
        .opacity(open ? 1 : 0)
        .animation(reduceMotion ? nil : MotionCurve.sprout.animation(duration: 0.7), value: open)
    }
}

/// The living ground under every page: the hour's light over the canvas and pollen in the air.
public struct LivingBackdrop: View {
    public init() {}

    public var body: some View {
        ZStack {
            Palette.canvas.color
            LinearGradient(colors: [tint, .clear], startPoint: .top, endPoint: .center)
            PollenField(density: 1.4)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var tint: Color {
        switch GreenhouseLight.at(hour: Calendar.current.component(.hour, from: .now)) {
        case .dawn: Palette.caution.color.opacity(0.07)
        case .day: Palette.accent.color.opacity(0.06)
        case .dusk: Palette.danger.color.opacity(0.06)
        case .night: Palette.deep.color.opacity(0.6)
        }
    }
}

/// Pollen drifting up through the greenhouse (decision 0003): a Core Animation emitter, drawn by
/// the render server. It only emits while ambient life is allowed; otherwise the air is still.
public struct PollenField: View {
    let density: Double
    @Environment(\.serreAmbientAllowed) private var allowed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(density: Double = 1) { self.density = density }

    public var body: some View {
        PollenLayer(alive: AmbientLife.isAlive(allowed: allowed, reduceMotion: reduceMotion), density: density)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct PollenLayer: NSViewRepresentable {
    let alive: Bool
    let density: Double

    func makeNSView(context: Context) -> PollenView { PollenView() }

    func updateNSView(_ view: PollenView, context: Context) {
        view.update(alive: alive, density: density)
    }
}

final class PollenView: NSView {
    private let emitter = CAEmitterLayer()
    private let cell = CAEmitterCell()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(emitter)
        emitter.emitterShape = .line
        emitter.renderMode = .additive
        cell.contents = Self.dot
        cell.lifetime = 9
        cell.velocity = 9
        cell.velocityRange = 6
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = .pi / 5
        cell.yAcceleration = 1.5
        cell.xAcceleration = 0.6
        cell.scale = 0.34
        cell.scaleRange = 0.18
        cell.alphaSpeed = -0.08
        cell.spin = 0.4
        cell.spinRange = 0.6
        emitter.emitterCells = [cell]
        emitter.birthRate = 0
    }

    @MainActor @preconcurrency required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: 0)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
    }

    func update(alive: Bool, density: Double) {
        cell.color = NSColor(Palette.accent.color).withAlphaComponent(0.8).cgColor
        cell.birthRate = Float(5 * density)
        emitter.emitterCells = [cell]
        emitter.birthRate = alive ? 1 : 0
    }

    /// A soft round grain.
    private static let dot: CGImage? = {
        let size = 16
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: colors, locations: [0, 1]) {
            context.drawRadialGradient(gradient, startCenter: CGPoint(x: 8, y: 8), startRadius: 0,
                                       endCenter: CGPoint(x: 8, y: 8), endRadius: 8, options: [])
        }
        return context.makeImage()
    }()
}

/// A vine that grows along the top of a page when it opens, from the sidebar's edge towards the
/// page's plant, with a few leaves unfolding behind its tip, then fades (caused by navigation).
public struct VineSweep: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = 0.0
    @State private var fade = 1.0

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                VinePath().trim(from: 0, to: grown)
                    .stroke(Palette.accent.color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                ForEach(0..<6, id: \.self) { index in
                    let at = Double(index + 1) / 7
                    RiskLeafShape(level: .low)
                        .fill(Palette.accent.color.opacity(0.8))
                        .frame(width: 9, height: 9)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -40 : 220))
                        .scaleEffect(grown > at ? 1 : 0.01)
                        .position(VinePath.point(at: at, in: size))
                        .animation(reduceMotion ? nil : MotionCurve.sprout.animation(duration: 0.35), value: grown > at)
                }
            }
            .opacity(fade)
        }
        .frame(height: 24)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { fade = 0; return }
            withAnimation(MotionCurve.sap.animation(duration: 0.7)) { grown = 1 }
            withAnimation(MotionCurve.retreat.animation(duration: 0.6).delay(1.1)) { fade = 0 }
        }
    }
}

struct VinePath: Shape {
    static func point(at t: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * t, y: size.height * 0.5 + sin(t * .pi * 4) * size.height * 0.3)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 60
        path.move(to: Self.point(at: 0, in: rect.size))
        for step in 1...steps { path.addLine(to: Self.point(at: Double(step) / Double(steps), in: rect.size)) }
        return path
    }
}
