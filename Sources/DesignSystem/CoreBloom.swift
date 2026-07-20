import SwiftUI

// MARK: - Core Bloom — the brand signature.
// A nucleus orbited by three asymmetric arcs (storage, protection, performance).

/// One orbital arc. Angles in degrees, 0 = top, clockwise.
public struct MCArc: Shape {
    public var start: Double
    public var span: Double
    public var radiusFraction: CGFloat

    public init(start: Double, span: Double, radiusFraction: CGFloat) {
        self.start = start
        self.span = span
        self.radiusFraction = radiusFraction
    }

    public var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(start, span) }
        set { start = newValue.first; span = newValue.second }
    }

    public func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2 * radiusFraction
        var p = Path()
        p.addArc(center: c, radius: r,
                 startAngle: .degrees(start - 90),
                 endAngle: .degrees(start + span - 90),
                 clockwise: false)
        return p
    }
}

/// Geometry shared by every Core Bloom rendition (logo, hero, progress).
public enum MCBloomGeometry {
    /// (startAngle, span, radiusFraction) — deliberate asymmetry.
    public static let arcs: [(Double, Double, CGFloat)] = [
        (-30, 150, 0.94),   // storage — outer
        (105, 115, 0.72),   // protection — middle
        (250, 80, 0.50),    // performance — inner
    ]
    public static let nucleusFraction: CGFloat = 0.24
}

/// Static Core Bloom mark. Monochrome when `tint` is nil.
public struct CoreBloomMark: View {
    private let tint: [Color]?
    private let lineWidthFraction: CGFloat

    public init(tint: [Color]? = nil, lineWidthFraction: CGFloat = 0.07) {
        self.tint = tint
        self.lineWidthFraction = lineWidthFraction
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let lw = max(1, side * lineWidthFraction)
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let a = MCBloomGeometry.arcs[i]
                    MCArc(start: a.0, span: a.1, radiusFraction: a.2)
                        .stroke(color(i), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                }
                Circle()
                    .fill(color(0))
                    .frame(width: side * MCBloomGeometry.nucleusFraction,
                           height: side * MCBloomGeometry.nucleusFraction)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }

    private func color(_ i: Int) -> Color {
        if let tint { return tint[i % tint.count] }
        return .primary
    }
}

/// Three orbital progress arcs bound to real fractions (0…1 each).
/// Indeterminate arcs rotate slowly (never when Reduce Motion is on).
public struct OrbitalProgressView: View {
    public struct Track: Identifiable {
        public let id: String
        public let color: Color
        /// nil = indeterminate (activity), value = determinate progress.
        public let progress: Double?
        public init(id: String, color: Color, progress: Double?) {
            self.id = id
            self.color = color
            self.progress = progress
        }
    }

    private let tracks: [Track]
    private let animating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(tracks: [Track], animating: Bool) {
        self.tracks = tracks
        self.animating = animating
    }

    public var body: some View {
        ZStack {
            if animating && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    rings(rotation: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                rings(rotation: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        tracks.map { t in
            if let p = t.progress { return "\(t.id): \(Int(p * 100))%" }
            return "\(t.id): in progress"
        }.joined(separator: ", ")
    }

    @ViewBuilder
    private func rings(rotation: TimeInterval) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let lw = max(2, side * 0.045)
            ZStack {
                ForEach(Array(tracks.prefix(3).enumerated()), id: \.element.id) { i, track in
                    let a = MCBloomGeometry.arcs[i]
                    // Track ring
                    Circle()
                        .inset(by: side * (1 - a.2) / 2)
                        .stroke(track.color.opacity(MCOpacity.orbitTrack), lineWidth: lw)
                    if let p = track.progress {
                        MCArc(start: a.0, span: max(4, a.1 * p), radiusFraction: a.2)
                            .stroke(track.color, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    } else {
                        // Indeterminate: short arc orbiting at per-ring speed.
                        let speed = [40.0, -28.0, 55.0][i]
                        MCArc(start: a.0 + rotation.truncatingRemainder(dividingBy: 360) * speed,
                              span: a.1 * 0.35, radiusFraction: a.2)
                            .stroke(track.color, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
