import SwiftUI

/// The greenhouse of the Home (decision 0008), drawn on every frame from measurements only:
/// plants grow taller and denser with the free share of the disk, glowing seeds stand for space
/// that can be given back, and the whole bed leans toward the pointer. Still when ambient motion
/// is not allowed.
public struct ImmersiveGreenhouse: View {
    /// Free share of the volume, 0…1, or nil when unknown (drawn as a middle bed).
    let freeFraction: Double?
    /// Share of the volume CoreTend can give back, 0…1, or nil when unknown.
    let recoverableFraction: Double?
    @Environment(\.serreAmbientAllowed) private var allowed
    @Environment(\.colorScheme) private var scheme
    @State private var pointer: CGPoint?
    @State private var lean: Double = 0
    @State private var born = Date()

    public init(freeFraction: Double?, recoverableFraction: Double?) {
        self.freeFraction = freeFraction
        self.recoverableFraction = recoverableFraction
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !allowed)) { timeline in
            let now = timeline.date
            let t = allowed ? now.timeIntervalSinceReferenceDate : 0
            // The bed grows up from the soil during the first two seconds.
            let growth = allowed ? min(1, now.timeIntervalSince(born) / 2.2) : 1
            Canvas { context, size in
                GreenhouseDrawing(t: t, growth: ease(growth), dark: scheme == .dark,
                                  vigor: freeFraction.map { 0.45 + 0.55 * min(max($0 * 2.2, 0), 1) } ?? 0.7,
                                  seeds: seedCount, pointer: pointer, size: size).draw(&context)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location): pointer = location
            case .ended: pointer = nil
            }
        }
        .onAppear { born = .now }
        .accessibilityHidden(true)
    }

    private var seedCount: Int {
        guard let recoverableFraction, recoverableFraction > 0 else { return 0 }
        return max(2, min(16, Int((recoverableFraction * 400).rounded())))
    }

    private func ease(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
}

struct GreenhouseDrawing {
    let t: Double
    let growth: Double
    let dark: Bool
    let vigor: Double
    let seeds: Int
    let pointer: CGPoint?
    let size: CGSize

    var wind: Double {
        guard let pointer, size.width > 0 else { return 0 }
        return (pointer.x / size.width - 0.5) * 2
    }

    func draw(_ context: inout GraphicsContext) {
        sky(&context)
        glass(&context)
        hills(&context)
        bed(&context, layer: 0)
        fireflies(&context)
        bed(&context, layer: 1)
        soil(&context)
        reflection(&context)
    }

    // MARK: Layers

    private func sky(_ context: inout GraphicsContext) {
        let rect = CGRect(origin: .zero, size: size)
        let colors: [Color] = dark
            ? [Color(red: 0.03, green: 0.10, blue: 0.11), Color(red: 0.05, green: 0.20, blue: 0.16), Color(red: 0.10, green: 0.32, blue: 0.20)]
            : [Color(red: 0.80, green: 0.93, blue: 0.90), Color(red: 0.90, green: 0.96, blue: 0.84), Color(red: 0.98, green: 0.96, blue: 0.80)]
        context.fill(Path(rect), with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        // A sun (day) or a moon halo (night) that drifts across the glass very slowly.
        let sx = size.width * (0.72 + 0.04 * sin(t * 0.02)), sy = size.height * 0.22
        let r = size.height * 0.9
        context.fill(Path(ellipseIn: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.97, blue: 0.8).opacity(dark ? 0.18 : 0.75), .clear]),
                                           center: CGPoint(x: sx, y: sy), startRadius: 0, endRadius: r))
        if dark {
            var random = SeededRandom(seed: 3)
            for i in 0..<70 {
                let x = random.next() * size.width, y = random.next() * size.height * 0.55
                let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (1 + random.next() * 2) + Double(i)))
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(.white.opacity(0.5 * twinkle)))
            }
        }
    }

    private func glass(_ context: inout GraphicsContext) {
        let arches = max(3, Int(size.width / 360))
        let span = size.width / Double(arches)
        let line = (dark ? Color(red: 0.6, green: 0.95, blue: 0.75) : Color(red: 0.25, green: 0.45, blue: 0.32)).opacity(dark ? 0.16 : 0.22)
        for i in 0..<arches {
            let x0 = Double(i) * span
            var arch = Path()
            arch.move(to: CGPoint(x: x0, y: size.height))
            arch.addQuadCurve(to: CGPoint(x: x0 + span, y: size.height), control: CGPoint(x: x0 + span / 2, y: -size.height * 0.35))
            context.stroke(arch, with: .color(line), lineWidth: 1.4)
            for m in 1..<4 {
                let mx = x0 + span * Double(m) / 4
                let top = size.height - (size.height * 1.35) * (1 - pow((mx - x0 - span / 2) / (span / 2), 2)) * 0.5
                var mullion = Path()
                mullion.move(to: CGPoint(x: mx, y: max(top, 0)))
                mullion.addLine(to: CGPoint(x: mx, y: size.height))
                context.stroke(mullion, with: .color(line.opacity(0.6)), lineWidth: 0.8)
            }
        }
    }

    private func hills(_ context: inout GraphicsContext) {
        for layer in 0..<2 {
            var hill = Path()
            let base = size.height * (layer == 0 ? 0.70 : 0.78)
            hill.move(to: CGPoint(x: 0, y: size.height))
            hill.addLine(to: CGPoint(x: 0, y: base))
            let steps = 12
            for s in 1...steps {
                let x = size.width * Double(s) / Double(steps)
                let y = base - size.height * 0.05 * (1 + sin(Double(s) * 1.3 + Double(layer) * 2 + t * 0.03))
                hill.addLine(to: CGPoint(x: x, y: y))
            }
            hill.addLine(to: CGPoint(x: size.width, y: size.height))
            hill.closeSubpath()
            let tone = dark ? Color(red: 0.06, green: 0.22 + 0.04 * Double(layer), blue: 0.14) : Color(red: 0.62 - 0.08 * Double(layer), green: 0.80, blue: 0.62)
            context.fill(hill, with: .color(tone.opacity(dark ? 0.85 : 0.55)))
        }
    }

    private func bed(_ context: inout GraphicsContext, layer: Int) {
        var random = SeededRandom(seed: UInt64(11 + layer * 17))
        let count = Int(Double(layer == 0 ? 22 : 30) * (0.6 + 0.4 * vigor))
        let ground = size.height * (layer == 0 ? 0.80 : 0.92)
        let scale = layer == 0 ? 0.62 : 1.0
        var seedsLeft = layer == 1 ? seeds : 0
        for i in 0..<count {
            let x = (Double(i) + 0.5 + (random.next() - 0.5) * 0.8) / Double(count) * size.width
            let height = size.height * (0.30 + 0.45 * random.next()) * vigor * scale * growth
            let phase = random.next() * 6.28
            let speed = 0.6 + random.next() * 0.8
            let pointerPull: Double = {
                guard let pointer else { return 0 }
                let d = (pointer.x - x) / size.width
                return max(-1, min(1, d * 4)) * exp(-abs(d) * 5) * 0.9
            }()
            let sway = sin(t * speed + phase) * 0.10 + sin(t * speed * 2.3 + phase) * 0.04 + wind * 0.10 + pointerPull * 0.35
            let tip = CGPoint(x: x + sway * height, y: ground - height)
            let control = CGPoint(x: x + sway * height * 0.25, y: ground - height * 0.55)
            var stem = Path()
            stem.move(to: CGPoint(x: x, y: ground))
            stem.addQuadCurve(to: tip, control: control)
            let hueShift = random.next()
            let stemColor = dark
                ? Color(red: 0.25 + 0.2 * hueShift, green: 0.62 + 0.25 * hueShift, blue: 0.32).opacity(layer == 0 ? 0.55 : 0.95)
                : Color(red: 0.16 + 0.15 * hueShift, green: 0.42 + 0.18 * hueShift, blue: 0.22).opacity(layer == 0 ? 0.45 : 0.95)
            context.stroke(stem, with: .color(stemColor), style: StrokeStyle(lineWidth: (layer == 0 ? 1.4 : 2.4) * (0.7 + vigor * 0.4), lineCap: .round))
            // Leaves along the stem, opening as the bed grows.
            let leaves = 2 + Int(random.next() * 3)
            for l in 0..<leaves {
                let s = 0.3 + 0.6 * Double(l) / Double(max(leaves - 1, 1))
                let p = point(on: CGPoint(x: x, y: ground), control, tip, s)
                let side: Double = l % 2 == 0 ? 1 : -1
                let angle = -Double.pi / 2 + side * (0.9 - 0.2 * s) + sway * 1.5 + sin(t * speed * 1.4 + phase + Double(l)) * 0.08
                let length = height * (0.22 - 0.06 * s) * (0.6 + 0.4 * growth)
                let leafColor = dark
                    ? Color(red: 0.30 + 0.25 * hueShift, green: 0.75 + 0.2 * hueShift, blue: 0.38).opacity(layer == 0 ? 0.5 : 0.92)
                    : Color(red: 0.22 + 0.2 * hueShift, green: 0.55 + 0.2 * hueShift, blue: 0.28).opacity(layer == 0 ? 0.45 : 0.92)
                context.fill(leaf(at: p, angle: angle, length: length), with: .color(leafColor))
            }
            // Glowing seeds: what can be given back, ripening at the top of the front stems.
            if seedsLeft > 0 && i % max(1, count / max(seeds, 1)) == 0 {
                seedsLeft -= 1
                let pulse = 0.75 + 0.25 * sin(t * 2.2 + phase)
                let r = 5.5 * pulse * growth
                let halo = r * 5
                context.fill(Path(ellipseIn: CGRect(x: tip.x - halo, y: tip.y - halo, width: halo * 2, height: halo * 2)),
                             with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.88, blue: 0.4).opacity(0.55 * pulse), .clear]),
                                                   center: tip, startRadius: 0, endRadius: halo))
                context.fill(Path(ellipseIn: CGRect(x: tip.x - r, y: tip.y - r, width: r * 2, height: r * 2)),
                             with: .color(Color(red: 1, green: 0.93, blue: 0.62)))
            }
        }
    }

    private func fireflies(_ context: inout GraphicsContext) {
        var random = SeededRandom(seed: 29)
        let count = dark ? 46 : 28
        context.drawLayer { layer in
            layer.blendMode = dark ? .plusLighter : .normal
            for i in 0..<count {
                let bx = random.next(), by = random.next(), sp = 0.05 + random.next() * 0.12, ph = random.next() * 6.28
                var x = (bx + 0.06 * sin(t * sp * 3 + ph) + t * sp * 0.01).truncatingRemainder(dividingBy: 1) * size.width
                let y = (0.15 + 0.7 * by + 0.05 * cos(t * sp * 4 + ph)) * size.height
                if let pointer {
                    // They scatter softly away from the pointer.
                    let dx = x - pointer.x, dy = y - pointer.y, d = max(hypot(dx, dy), 1)
                    if d < 140 { x += dx / d * (140 - d) * 0.35 }
                }
                let blink = max(0, sin(t * (1.5 + random.next()) + Double(i)))
                let r = 1.6 + 1.6 * blink
                let tone = dark ? Color(red: 0.85, green: 1, blue: 0.55) : Color(red: 1, green: 0.95, blue: 0.7)
                layer.fill(Path(ellipseIn: CGRect(x: x - r * 4, y: y - r * 4, width: r * 8, height: r * 8)),
                           with: .radialGradient(Gradient(colors: [tone.opacity(0.45 * blink), .clear]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 4))
                layer.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)), with: .color(tone.opacity(0.4 + 0.6 * blink)))
            }
        }
    }

    private func soil(_ context: inout GraphicsContext) {
        let top = size.height * 0.90
        var soil = Path()
        soil.move(to: CGPoint(x: 0, y: size.height))
        soil.addLine(to: CGPoint(x: 0, y: top))
        for s in 0...24 {
            let x = size.width * Double(s) / 24
            soil.addLine(to: CGPoint(x: x, y: top + 3 * sin(Double(s) * 1.7)))
        }
        soil.addLine(to: CGPoint(x: size.width, y: size.height))
        soil.closeSubpath()
        let colors = dark ? [Color(red: 0.08, green: 0.16, blue: 0.10), Color(red: 0.03, green: 0.07, blue: 0.05)]
                          : [Color(red: 0.55, green: 0.66, blue: 0.48), Color(red: 0.42, green: 0.52, blue: 0.36)]
        context.fill(soil, with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
    }

    /// A band of light sliding across the glass.
    private func reflection(_ context: inout GraphicsContext) {
        let period = 9.0
        let p = (t.truncatingRemainder(dividingBy: period)) / period
        let x = (p * 1.6 - 0.3) * size.width
        var band = Path()
        band.move(to: CGPoint(x: x, y: 0))
        band.addLine(to: CGPoint(x: x + 60, y: 0))
        band.addLine(to: CGPoint(x: x - 80, y: size.height))
        band.addLine(to: CGPoint(x: x - 140, y: size.height))
        band.closeSubpath()
        context.fill(band, with: .linearGradient(Gradient(colors: [Color.white.opacity(dark ? 0.05 : 0.22), .clear]),
                                                 startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x - 100, y: size.height)))
    }

    // MARK: Geometry

    private func point(on a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ s: Double) -> CGPoint {
        let u = 1 - s
        return CGPoint(x: u * u * a.x + 2 * u * s * c.x + s * s * b.x, y: u * u * a.y + 2 * u * s * c.y + s * s * b.y)
    }

    private func leaf(at p: CGPoint, angle: Double, length: Double) -> Path {
        let tip = CGPoint(x: p.x + cos(angle) * length, y: p.y + sin(angle) * length)
        let normal = angle + .pi / 2
        let width = length * 0.38
        let mid = CGPoint(x: (p.x + tip.x) / 2, y: (p.y + tip.y) / 2)
        var path = Path()
        path.move(to: p)
        path.addQuadCurve(to: tip, control: CGPoint(x: mid.x + cos(normal) * width, y: mid.y + sin(normal) * width))
        path.addQuadCurve(to: p, control: CGPoint(x: mid.x - cos(normal) * width * 0.6, y: mid.y - sin(normal) * width * 0.6))
        return path
    }
}

/// A terrarium jar filled to `fraction` with a living liquid: two waves, rising bubbles.
public struct LiquidGauge: View {
    let fraction: Double
    let tint: Color
    @Environment(\.serreAmbientAllowed) private var allowed
    @Environment(\.colorScheme) private var scheme
    @State private var shown = 0.0

    public init(fraction: Double, tint: Color) {
        self.fraction = min(max(fraction, 0), 1)
        self.tint = tint
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !allowed)) { timeline in
            let t = allowed ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let jar = Path(roundedRect: rect, cornerRadius: min(size.width, size.height) * 0.28, style: .continuous)
                context.clip(to: jar)
                context.fill(jar, with: .linearGradient(Gradient(colors: [Color.white.opacity(scheme == .dark ? 0.06 : 0.55), tint.opacity(scheme == .dark ? 0.16 : 0.20)]),
                                                        startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                // Graduations, so a low level still reads as a level.
                for mark in 1..<4 {
                    let y = size.height * Double(mark) / 4
                    context.stroke(Path { $0.move(to: CGPoint(x: size.width * 0.72, y: y)); $0.addLine(to: CGPoint(x: size.width * 0.88, y: y)) },
                                   with: .color(tint.opacity(0.35)), lineWidth: 1)
                }
                let level = size.height * (1 - shown)
                for wave in 0..<2 {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height))
                    let amplitude = 3.5 + Double(wave) * 2
                    for s in stride(from: 0.0, through: size.width, by: 3) {
                        let y = level + amplitude * sin(s / size.width * .pi * 2 * 1.3 + t * (1.6 + Double(wave) * 0.7) + Double(wave) * 2)
                        path.addLine(to: CGPoint(x: s, y: y))
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .linearGradient(Gradient(colors: [tint.opacity(wave == 0 ? 0.55 : 0.95), tint.opacity(wave == 0 ? 0.35 : 0.75)]),
                                                             startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: size.height)))
                }
                var random = SeededRandom(seed: 5)
                for _ in 0..<9 {
                    let bx = random.next() * size.width, speed = 14 + random.next() * 22, r = 1.5 + random.next() * 2.5
                    let span = max(size.height - level, 1)
                    let y = size.height - (t * speed + random.next() * 200).truncatingRemainder(dividingBy: span)
                    context.fill(Path(ellipseIn: CGRect(x: bx, y: y, width: r, height: r)), with: .color(.white.opacity(0.45)))
                }
                context.stroke(jar, with: .color(.white.opacity(scheme == .dark ? 0.18 : 0.6)), lineWidth: 1.5)
            }
        }
        .onAppear { withAnimation(.spring(response: 1.4, dampingFraction: 0.7).delay(0.2)) { shown = fraction } }
        .onChange(of: fraction) { _, value in withAnimation(.spring(response: 1, dampingFraction: 0.8)) { shown = value } }
        .accessibilityHidden(true)
    }
}

/// Leaves that burst out when `trigger` changes: a short flight with gravity and spin.
public struct LeafBurst: View {
    let trigger: Int
    let tint: Color
    @State private var start: Date?

    public init(trigger: Int, tint: Color) { self.trigger = trigger; self.tint = tint }

    public var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let age = timeline.date.timeIntervalSince(start)
                guard age < 0.9 else { return }
                var random = SeededRandom(seed: UInt64(trigger + 1))
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for _ in 0..<14 {
                    let angle = random.next() * .pi * 2, speed = 70 + random.next() * 120, spin = (random.next() - 0.5) * 12
                    let x = center.x + cos(angle) * speed * age
                    let y = center.y + sin(angle) * speed * age + 160 * age * age
                    var leaf = context
                    leaf.translateBy(x: x, y: y)
                    leaf.rotate(by: .radians(angle + spin * age))
                    leaf.opacity = 1 - age / 0.9
                    var path = Path()
                    path.move(to: .zero)
                    path.addQuadCurve(to: CGPoint(x: 9, y: 0), control: CGPoint(x: 4.5, y: -4))
                    path.addQuadCurve(to: .zero, control: CGPoint(x: 4.5, y: 3))
                    leaf.fill(path, with: .color(tint))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            start = .now
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(950))
                start = nil
            }
        }
        .accessibilityHidden(true)
    }
}
