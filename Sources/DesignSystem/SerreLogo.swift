import SwiftUI

/// What the logo shows at a given moment of its germination. 0 = not yet grown, 1 = grown.
public struct SerreLogoState: Equatable, Sendable {
    /// How far above its resting place the seed still is, in logo units (the logo is 40 units).
    public var seedDrop: Double
    public var seedScale: Double
    public var stem: Double
    public var firstLeaf: Double
    public var secondLeaf: Double

    public static let seed = SerreLogoState(seedDrop: 6, seedScale: 0.82, stem: 0, firstLeaf: 0, secondLeaf: 0)
    public static let grown = SerreLogoState(seedDrop: 0, seedScale: 1, stem: 1, firstLeaf: 1, secondLeaf: 1)
}

/// The CoreTend logo: a seed, a stem and two leaves (Documentation/Design/UI-guide.md § 6).
/// With `germinates`, it grows once when it appears (about 1.2 s) and then stays still; under
/// Reduce Motion it is shown grown. On hover its leaves flutter once.
public struct SerreLogo: View {
    public struct Step: Sendable {
        public let delay: Double
        public let duration: Double
        let curve: MotionCurve
        let apply: @Sendable (inout SerreLogoState) -> Void
    }

    /// The seed falls and settles, swells, the stem draws upward, then each leaf unfolds.
    public static let germinationSteps: [Step] = [
        Step(delay: 0, duration: 0.16, curve: .fall) { $0.seedDrop = 0 },
        Step(delay: 0.16, duration: 0.18, curve: .sprout) { $0.seedScale = 1 },
        Step(delay: 0.3, duration: 0.42, curve: .sap) { $0.stem = 1 },
        Step(delay: 0.72, duration: 0.36, curve: .sprout) { $0.firstLeaf = 1 },
        Step(delay: 0.81, duration: 0.36, curve: .sprout) { $0.secondLeaf = 1 },
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state: SerreLogoState
    @State private var flutter = 0.0
    private let germinates: Bool
    private let size: CGFloat

    public init(size: CGFloat = 40, germinates: Bool = false) {
        self.size = size
        self.germinates = germinates
        _state = State(initialValue: germinates ? .seed : .grown)
    }

    /// A fixed moment of the germination, for rendering checks.
    init(size: CGFloat, frozenAt state: SerreLogoState) {
        self.size = size
        self.germinates = false
        _state = State(initialValue: state)
    }

    public var body: some View {
        let unit = size / 40
        ZStack {
            leaf(Self.firstLeafPath, progress: state.firstLeaf, anchor: UnitPoint(x: 0.5, y: 17 / 40.0), direction: 1)
            leaf(Self.secondLeafPath, progress: state.secondLeaf, anchor: UnitPoint(x: 0.5, y: 13 / 40.0), direction: -1)
            Self.stemPath.trimmedPath(from: 0, to: state.stem)
                .applying(CGAffineTransform(scaleX: unit, y: unit))
                .stroke(Palette.ink.color, style: StrokeStyle(lineWidth: 2 * unit, lineCap: .round))
            Circle()
                .fill(Palette.accent.color)
                .frame(width: 11 * unit, height: 11 * unit)
                .scaleEffect(state.seedScale)
                .position(x: 20 * unit, y: (30 - state.seedDrop) * unit)
        }
        .frame(width: size, height: size)
        .onAppear(perform: germinate)
        .onHover { inside in
            guard inside, !reduceMotion else { return }
            withAnimation(MotionCurve.sprout.animation(duration: 0.2)) { flutter = 4 }
            withAnimation(MotionCurve.sprout.animation(duration: 0.2).delay(0.2)) { flutter = 0 }
        }
        .accessibilityElement()
        .accessibilityLabel("CoreTend")
    }

    private func germinate() {
        guard germinates else { return }
        guard !reduceMotion else { state = .grown; return }
        state = .seed
        for step in Self.germinationSteps {
            withAnimation(step.curve.animation(duration: step.duration).delay(step.delay)) { step.apply(&state) }
        }
    }

    /// A leaf unfolds from 18° folded towards its stem to 0°; `direction` mirrors the two leaves.
    private func leaf(_ path: Path, progress: Double, anchor: UnitPoint, direction: Double) -> some View {
        let unit = size / 40
        let scaled = path.applying(CGAffineTransform(scaleX: unit, y: unit))
        return ZStack {
            scaled.fill(Palette.accent.color.opacity(0.9 * progress))
            scaled.trimmedPath(from: 0, to: progress)
                .stroke(Palette.accent.color, style: StrokeStyle(lineWidth: 1.8 * unit, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(direction * (18 * (1 - progress) + flutter)), anchor: anchor)
    }

    private static let stemPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 20, y: 26))
        p.addCurve(to: CGPoint(x: 20, y: 8), control1: CGPoint(x: 20, y: 18), control2: CGPoint(x: 20, y: 14))
        return p
    }()

    private static let firstLeafPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 20, y: 17))
        p.addCurve(to: CGPoint(x: 11, y: 8), control1: CGPoint(x: 14, y: 16), control2: CGPoint(x: 11, y: 12))
        p.addCurve(to: CGPoint(x: 20, y: 17), control1: CGPoint(x: 16, y: 8), control2: CGPoint(x: 20, y: 11))
        return p
    }()

    private static let secondLeafPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 20, y: 13))
        p.addCurve(to: CGPoint(x: 29, y: 5), control1: CGPoint(x: 25, y: 12), control2: CGPoint(x: 28, y: 9))
        p.addCurve(to: CGPoint(x: 20, y: 13), control1: CGPoint(x: 24, y: 5), control2: CGPoint(x: 21, y: 8))
        return p
    }()
}
