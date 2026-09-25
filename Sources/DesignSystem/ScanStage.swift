// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

/// A live scanning visualization — the instrument dial.
///
/// A ring of graduated ticks (long ticks every 30°) around the static Core
/// Bloom mark. While `isScanning`, a lit "read head" travels the dial and
/// leaves a short decaying trail — one clear, calm signal that work is
/// happening. When the scan is bounded, a thin progress arc fills inside the
/// ticks.
///
/// Drawn in a single `Canvas` driven by `TimelineView(.animation)`, so it is
/// cheap regardless of scan throughput. Under Reduce Motion the head stops and
/// the ticks glow evenly instead — still an unmistakable "busy" state.
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

    private let side: CGFloat = 212
    private let tickCount = 72

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
                    dial(head: nil)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        dial(head: t.truncatingRemainder(dividingBy: 2.4) / 2.4)
                    }
                }
                progressArc
                CoreBloomMark(tint: [tint], lineWidthFraction: 0.085)
                    .frame(width: side * 0.30, height: side * 0.30)
                    .opacity(isScanning ? 1 : 0.45)
            }
            .frame(width: side, height: side)
            .accessibilityHidden(true)

            caption
                .font(MCFont.metric)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
                .accessibilityElement(children: .combine)
        }
    }

    /// The graduated ring. `head` is the read-head position (0…1, clockwise
    /// from 12 o'clock) or `nil` for a static dial.
    private func dial(head: Double?) -> some View {
        let tint = tint
        let scanning = isScanning
        let count = tickCount
        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            for i in 0..<count {
                let position = Double(i) / Double(count)
                let angle = position * 2 * Double.pi - Double.pi / 2
                let long = i % 6 == 0
                let inner = radius * (long ? 0.79 : 0.85)
                let outer = radius * 0.95
                var intensity = scanning ? 0.34 : 0.18
                if let head {
                    // Distance behind the head, 0…1 around the dial.
                    let behind = ((head - position).truncatingRemainder(dividingBy: 1) + 1)
                        .truncatingRemainder(dividingBy: 1)
                    intensity = max(0.16, 1 - behind * 5)
                }
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle)))
                tick.addLine(to: CGPoint(x: center.x + outer * cos(angle), y: center.y + outer * sin(angle)))
                context.stroke(tick, with: .color(tint.opacity(intensity)),
                               style: StrokeStyle(lineWidth: long ? 2 : 1.25, lineCap: .round))
            }
        }
    }

    /// Determinate progress. Hidden while the scan is open-ended.
    @ViewBuilder private var progressArc: some View {
        if let fraction {
            ZStack {
                Circle()
                    .stroke(tint.opacity(MCOpacity.orbitTrack), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: fraction)
            }
            .padding(side * 0.20)
        }
    }
}
