import SwiftUI

/// A live scanning visualization — the piece the modules were missing.
///
/// `MCFragmentView` is a static per-phase Canvas; this is its motion
/// counterpart, driven by `TimelineView(.animation)`:
///
///  - the three Core Bloom arcs rotate as the resting frame,
///  - a radar wedge sweeps continuously while `isScanning`,
///  - ping rings pulse outward from the nucleus,
///  - motes stream inward on their own phases (files being read),
///  - a count-up ring fills toward `fraction` when the scan is bounded.
///
/// Everything animates transform/opacity only. Under Reduce Motion the sweep,
/// pings, pulse and motes stop and a single calm ring is shown instead — the
/// caller still gets a clear "work is happening" signal without movement.
///
/// The numeric readout (paths seen, bytes found) is the caller's job — pass it
/// as `caption`; this view owns only the geometry.
public struct MCScanStage<Caption: View>: View {
    private let isScanning: Bool
    /// 0…1 when the scan is bounded; `nil` for an open-ended sweep.
    private let fraction: Double?
    private let tint: Color
    private let caption: Caption

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let side: CGFloat = 224

    public init(
        isScanning: Bool,
        fraction: Double? = nil,
        tint: Color = MCColor.teal,
        @ViewBuilder caption: () -> Caption
    ) {
        self.isScanning = isScanning
        self.fraction = fraction.map { min(max($0, 0), 1) }
        self.tint = tint
        self.caption = caption()
    }

    public var body: some View {
        VStack(spacing: MCSpacing.lg) {
            ZStack {
                if reduceMotion || !isScanning {
                    restingFrame(rotation: 0)
                    staticState
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                        motion(t: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
                progressRing
                nucleus(scale: 1)
            }
            .frame(width: side, height: side)
            .accessibilityHidden(true)

            caption
                .font(MCFont.metric)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Static parts

    /// The three Core Bloom arcs, optionally rotated as one — the resting frame.
    private func restingFrame(rotation: Double) -> some View {
        ZStack {
            Circle().strokeBorder(tint.opacity(0.10), lineWidth: 1.5)
            ForEach(0..<3, id: \.self) { i in
                let a = MCBloomGeometry.arcs[i]
                MCArc(start: a.0, span: a.1, radiusFraction: a.2)
                    .stroke(tint.opacity(0.28 - Double(i) * 0.06),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
        .rotationEffect(.degrees(rotation))
    }

    private func nucleus(scale: CGFloat) -> some View {
        let d = side * MCBloomGeometry.nucleusFraction * 0.62
        return ZStack {
            Circle().fill(tint.opacity(0.18)).frame(width: d * 2.2, height: d * 2.2).blur(radius: 8)
            Circle().fill(tint).frame(width: d, height: d)
        }
        .scaleEffect(scale)
        .opacity(isScanning ? 1 : 0.5)
    }

    /// Determinate progress. Hidden while the scan is open-ended.
    @ViewBuilder private var progressRing: some View {
        if let fraction {
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: fraction)
        }
    }

    /// Reduce Motion / resting: one calm inner ring, no movement.
    private var staticState: some View {
        Circle()
            .strokeBorder(tint.opacity(isScanning ? 0.5 : 0.22), lineWidth: 2.5)
            .padding(side * 0.20)
    }

    // MARK: - Motion

    private func motion(t: TimeInterval) -> some View {
        let sweep = t.truncatingRemainder(dividingBy: 2.0) / 2.0            // 0…1 per revolution
        let pulse = 0.5 + 0.5 * sin(t * 3.0)
        let pingCount = 3

        return ZStack {
            restingFrame(rotation: t * 6)                                    // slow drift, ~one turn / minute

            // Radar wedge — a bright conic sweep, unmistakably "scanning".
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: tint.opacity(0), location: 0.0),
                            .init(color: tint.opacity(0.06), location: 0.55),
                            .init(color: tint.opacity(0.38), location: 0.98),
                            .init(color: tint.opacity(0), location: 1.0),
                        ]),
                        center: .center))
                .mask(Circle().strokeBorder(.black, lineWidth: side * 0.5))
                .rotationEffect(.degrees(sweep * 360))

            // Leading edge of the sweep, a crisp bright arc.
            Circle()
                .trim(from: 0, to: 0.02)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(sweep * 360 - 90))

            // Ping rings expanding outward from the nucleus.
            ForEach(0..<pingCount, id: \.self) { i in
                let p = ((t * 0.6) + Double(i) / Double(pingCount)).truncatingRemainder(dividingBy: 1)
                Circle()
                    .strokeBorder(tint.opacity(0.35 * (1 - p)), lineWidth: 1.5)
                    .scaleEffect(0.12 + 0.9 * p)
            }

            // Motes: files being read, streaming inward.
            ForEach(0..<16, id: \.self) { i in
                let phase = t * 0.9 + Double(i) * (2 * .pi / 16)
                let cyc = (sin(phase) + 1) / 2                               // 0 (rim) … 1 (centre)
                let radius = side * (0.10 + 0.36 * (1 - cyc))
                let angle = phase * 1.7 + Double(i)
                Circle()
                    .fill(tint.opacity(0.15 + 0.7 * cyc))
                    .frame(width: 3 + 4 * cyc, height: 3 + 4 * cyc)
                    .offset(x: radius * cos(angle), y: radius * sin(angle))
            }

            nucleus(scale: 1 + 0.16 * pulse)
        }
    }
}
