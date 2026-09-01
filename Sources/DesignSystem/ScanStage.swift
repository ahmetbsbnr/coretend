import SwiftUI

/// A live scanning visualization — the piece the modules were missing.
///
/// `MCFragmentView` is a static per-phase Canvas; this is its motion
/// counterpart, driven by `TimelineView(.animation)`:
///
///  - a Core Bloom sweep arc rotates continuously while `isScanning`,
///  - the nucleus pulses in time with it,
///  - motes drift inward on faint orbits, standing in for files being read,
///  - a count-up ring fills toward `fraction` when the scan is bounded.
///
/// Everything animates transform/opacity only. Under Reduce Motion the sweep,
/// pulse and motes stop and a single calm ring is shown instead — the caller
/// still gets a clear "work is happening" signal without continuous movement.
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
        VStack(spacing: MCSpacing.md) {
            ZStack {
                track
                if reduceMotion || !isScanning {
                    staticState
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        motion(t: t)
                    }
                }
                progressRing
                nucleus
            }
            .frame(width: MCSize.heroCore, height: MCSize.heroCore)
            .accessibilityHidden(true)

            caption
                .font(MCFont.monospacedMetric)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .accessibilityElement(children: .combine)
        }
    }

    // The faint full circle the sweep and motes ride on.
    private var track: some View {
        Circle()
            .strokeBorder(tint.opacity(MCOpacity.orbitTrack), lineWidth: 2)
    }

    private var nucleus: some View {
        Circle()
            .fill(tint)
            .frame(width: MCSize.heroCore * MCBloomGeometry.nucleusFraction * 0.7,
                   height: MCSize.heroCore * MCBloomGeometry.nucleusFraction * 0.7)
            .opacity(isScanning ? 1 : 0.55)
    }

    /// Determinate progress. Hidden while the scan is open-ended.
    @ViewBuilder private var progressRing: some View {
        if let fraction {
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: fraction)
        }
    }

    // Reduce Motion / resting: one calm inner ring, no movement.
    private var staticState: some View {
        Circle()
            .strokeBorder(tint.opacity(isScanning ? 0.45 : 0.2), lineWidth: 2)
            .padding(MCSize.heroCore * 0.22)
    }

    // The moving parts: a sweep arc + a handful of inward-drifting motes.
    private func motion(t: TimeInterval) -> some View {
        let sweepAngle = t.truncatingRemainder(dividingBy: 2.4) / 2.4 * 360
        let pulse = 0.5 + 0.5 * sin(t * 2.6)

        return ZStack {
            // Sweep: a short bright arc chasing the track.
            Circle()
                .trim(from: 0, to: 0.16)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [tint.opacity(0), tint]),
                        center: .center),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(sweepAngle - 90))

            // Motes: files being read, drawn inward on their own phase.
            ForEach(0..<7, id: \.self) { i in
                let phase = t * 0.7 + Double(i) * (2 * .pi / 7)
                let progress = (sin(phase) + 1) / 2                // 0…1, in and out
                let radius = MCSize.heroCore * (0.14 + 0.30 * (1 - progress))
                let angle = phase * 1.3
                Circle()
                    .fill(tint.opacity(0.20 + 0.55 * progress))
                    .frame(width: 3 + 3 * progress, height: 3 + 3 * progress)
                    .offset(x: radius * cos(angle), y: radius * sin(angle))
            }

            nucleus.scaleEffect(1 + 0.10 * pulse)
        }
    }
}

public extension MCScanStage where Caption == EmptyView {
    init(isScanning: Bool, fraction: Double? = nil, tint: Color = MCColor.teal) {
        self.init(isScanning: isScanning, fraction: fraction, tint: tint) { EmptyView() }
    }
}
