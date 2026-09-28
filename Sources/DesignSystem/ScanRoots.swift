import SwiftUI

/// Where a scan stands, as the roots show it.
public enum ScanRootsPhase: Equatable, Sendable {
    /// Files are being read; the roots descend with each progress event.
    case reading
    /// The scan ended; one bloom opens at the surface and the roots stay as they are.
    case finished
    /// The scan was cancelled; the roots withdraw.
    case retracted
}

/// A root system drawn down to `depth` (0…1): a taproot with side roots that appear once the
/// taproot has passed them (UI guide § 8, "Analyse en cours").
public struct RootSystem: Shape {
    public var depth: Double

    public init(depth: Double) { self.depth = depth }

    public nonisolated var animatableData: Double {
        get { depth }
        set { depth = newValue }
    }

    /// Depth for a number of files actually read. There is no total, so this is not a
    /// percentage: it only grows with real events, quickly at first and ever slower after
    /// (full depth at 100 000 files). Zero files draw nothing.
    public nonisolated static func depth(forCompletedFiles count: Int) -> Double {
        guard count > 0 else { return 0 }
        return min(1, 0.06 + log10(Double(count) + 1) / 5 * 0.94)
    }

    /// Side roots: where they leave the taproot, which side, how far they reach.
    private static let branches: [(start: Double, side: Double, reach: Double)] = [
        (0.10, -1, 0.34), (0.18, 1, 0.40), (0.30, -1, 0.44), (0.42, 1, 0.36),
        (0.54, -1, 0.30), (0.66, 1, 0.28), (0.78, -1, 0.20), (0.88, 1, 0.16),
    ]

    public func path(in rect: CGRect) -> Path {
        let depth = min(max(depth, 0), 1)
        guard depth > 0 else { return Path() }
        func taproot(_ f: Double) -> CGPoint {
            CGPoint(x: rect.midX + sin(f * 7) * rect.width * 0.018, y: rect.minY + f * rect.height)
        }
        var path = Path()
        path.move(to: taproot(0))
        let steps = 32
        for step in 1...steps {
            let f = depth * Double(step) / Double(steps)
            path.addLine(to: taproot(f))
        }
        for branch in Self.branches where depth > branch.start {
            let grown = min(1, (depth - branch.start) / 0.22)
            let origin = taproot(branch.start)
            let reach = rect.width * branch.reach * grown
            let drop = rect.height * 0.16 * grown
            let end = CGPoint(x: origin.x + branch.side * reach, y: origin.y + drop)
            let control = CGPoint(x: origin.x + branch.side * reach * 0.45, y: origin.y + drop * 0.05)
            path.move(to: origin)
            path.addQuadCurve(to: end, control: control)
            // A rootlet near the end of the longer side roots.
            if grown > 0.6, branch.reach > 0.25 {
                let base = CGPoint(x: origin.x + branch.side * reach * 0.7, y: origin.y + drop * 0.45)
                path.move(to: base)
                path.addQuadCurve(to: CGPoint(x: base.x + branch.side * 6, y: base.y + 12),
                                  control: CGPoint(x: base.x + branch.side * 1, y: base.y + 8))
            }
        }
        return path
    }
}

/// The scan in progress: roots descend as files are read, the count of files read stands in
/// Iowan beside them, a bloom opens once when the scan ends, and the roots withdraw on cancel.
/// Nothing moves without a progress event. Under Reduce Motion the soil stays still and only the
/// count changes.
public struct ScanRoots: View {
    let completed: Int
    let count: String
    let caption: String
    let phase: ScanRootsPhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownDepth = 0.0
    @State private var bloomed = false

    public init(completed: Int, count: String, caption: String, phase: ScanRootsPhase) {
        self.completed = completed
        self.count = count
        self.caption = caption
        self.phase = phase
    }

    private var targetDepth: Double {
        phase == .retracted ? 0 : RootSystem.depth(forCompletedFiles: completed)
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(count)
                    .font(CoreTendTypography.hero)
                    .foregroundStyle(Palette.ink.color)
                    .contentTransition(.numericText(value: Double(completed)))
                    .monospacedDigit()
                Text(caption)
                    .font(CoreTendTypography.secondary)
                    .foregroundStyle(Palette.secondaryInk.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 180, alignment: .leading)
            soil
        }
        .accessibilityElement(children: .combine)
        .onAppear { settle(animated: false) }
        .onChange(of: completed) { _, _ in settle(animated: true) }
        .onChange(of: phase) { _, _ in settle(animated: true) }
    }

    private var soil: some View {
        ZStack(alignment: .top) {
            LeafCorner.control.shape.fill(Palette.deep.color)
            Palette.strongSeparator.color.frame(height: 1).padding(.horizontal, 10).padding(.top, 14)
            if !reduceMotion {
                RootSystem(depth: shownDepth)
                    .stroke(Palette.accent.color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .padding(.top, 14).padding(.bottom, 10).padding(.horizontal, 12)
            }
            if phase == .finished {
                Bloom(open: bloomed || reduceMotion)
                    .frame(width: 22, height: 22)
                    .offset(y: 3)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .clipShape(LeafCorner.control.shape)
        .accessibilityHidden(true)
    }

    private func settle(animated: Bool) {
        let target = targetDepth
        guard animated, !reduceMotion else {
            shownDepth = target
            bloomed = phase == .finished
            return
        }
        switch phase {
        case .reading:
            bloomed = false
            // A short, interruptible growth per event; a new event takes over at once.
            withAnimation(MotionCurve.sap.animation(duration: MotionToken.standard.duration)) { shownDepth = target }
        case .retracted:
            withAnimation(MotionCurve.retreat.animation(duration: 0.4)) { shownDepth = 0 }
        case .finished:
            // A quick scan ends before the roots have grown: they reach their depth, then bloom.
            withAnimation(MotionCurve.sap.animation(duration: MotionToken.grow.duration)) { shownDepth = target }
            withAnimation(MotionCurve.sap.animation(duration: MotionToken.bloom.duration).delay(MotionToken.grow.duration * 0.7)) { bloomed = true }
        }
    }
}

/// One flower at the surface: the end of a scan.
private struct Bloom: View {
    let open: Bool

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Ellipse()
                    .fill(Palette.accent.color.opacity(0.85))
                    .frame(width: 7, height: 11)
                    .offset(y: -6)
                    .rotationEffect(.degrees(Double(index) * 72))
            }
            Circle().fill(Palette.caution.color).frame(width: 6, height: 6)
        }
        .scaleEffect(open ? 1 : 0.1)
        .opacity(open ? 1 : 0)
    }
}
