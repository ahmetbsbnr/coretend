import SwiftUI

/// Protection's visual motif: a containment mesh of nodes on a ring.
/// `completeness` (0...1) is real — driven by whether the engine is
/// installed/ready, never decorative. An incomplete mesh communicates
/// "engine unavailable" without a blank screen or alarming red.
/// Static Canvas draw — no timers, no cost while idle.
public struct MCMeshView: View {
    public enum Style { case incomplete, ready, scanning, alert }

    private let nodeCount: Int
    private let completeness: Double
    private let style: Style

    public init(nodeCount: Int = 8, completeness: Double, style: Style) {
        self.nodeCount = max(3, nodeCount)
        self.completeness = min(1, max(0, completeness))
        self.style = style
    }

    private var tint: Color {
        switch style {
        case .incomplete: return MCColor.protection.opacity(0.55)
        case .ready: return MCColor.protection
        case .scanning: return MCColor.protection
        case .alert: return MCColor.attention // never critical red for mesh state itself
        }
    }

    public var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let points = meshPoints(center: center, size: size)
        let presentCount = Int(Double(nodeCount) * completeness)

        drawNucleus(center: center, size: size, context: &context)
        drawEdges(
            points: points,
            center: center,
            presentCount: presentCount,
            context: &context
        )
        drawNodes(points: points, presentCount: presentCount, context: &context)
    }

    private func meshPoints(center: CGPoint, size: CGSize) -> [CGPoint] {
        let radius = min(size.width, size.height) / 2 * 0.82
        return (0..<nodeCount).map { index in
            let fraction = Double(index) / Double(nodeCount)
            let angle = fraction * 2 * Double.pi - Double.pi / 2
            return CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
        }
    }

    private func drawNucleus(
        center: CGPoint,
        size: CGSize,
        context: inout GraphicsContext
    ) {
        let radius = size.width * 0.05
        let diameter = radius * 2
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: diameter,
            height: diameter
        )
        context.fill(Path(ellipseIn: rect), with: .color(tint))
    }

    private func drawEdges(
        points: [CGPoint],
        center: CGPoint,
        presentCount: Int,
        context: inout GraphicsContext
    ) {
        for index in 0..<nodeCount {
            let nextIndex = (index + 1) % nodeCount
            let bothPresent = index < presentCount && nextIndex < presentCount
            drawEdge(
                from: points[index],
                to: points[nextIndex],
                present: bothPresent,
                context: &context
            )
            drawSpoke(
                from: center,
                to: points[index],
                present: index < presentCount,
                context: &context
            )
        }
    }

    private func drawEdge(
        from start: CGPoint,
        to end: CGPoint,
        present: Bool,
        context: inout GraphicsContext
    ) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        if present {
            context.stroke(path, with: .color(tint.opacity(0.6)), lineWidth: 1.5)
        } else {
            let style = StrokeStyle(lineWidth: 1, dash: [3, 4])
            context.stroke(
                path,
                with: .color(Color.secondary.opacity(0.25)),
                style: style
            )
        }
    }

    private func drawSpoke(
        from center: CGPoint,
        to point: CGPoint,
        present: Bool,
        context: inout GraphicsContext
    ) {
        var path = Path()
        path.move(to: center)
        path.addLine(to: point)
        let color = present ? tint.opacity(0.35) : Color.secondary.opacity(0.15)
        context.stroke(path, with: .color(color), lineWidth: 1)
    }

    private func drawNodes(
        points: [CGPoint],
        presentCount: Int,
        context: inout GraphicsContext
    ) {
        for (index, point) in points.enumerated() {
            let present = index < presentCount
            let radius: CGFloat = present ? 4 : 3
            let diameter = radius * 2
            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: diameter,
                height: diameter
            )
            let path = Path(ellipseIn: rect)
            if present {
                context.fill(path, with: .color(tint))
            } else {
                context.stroke(
                    path,
                    with: .color(Color.secondary.opacity(0.35)),
                    lineWidth: 1
                )
            }
        }
    }

    /// VoiceOver-facing summary of the same real state the mesh renders.
    public var accessibilityDescription: String {
        switch style {
        case .incomplete: return "Protection mesh incomplete — engine unavailable."
        case .ready: return "Protection mesh complete — engine ready."
        case .scanning: return "Protection mesh forming — scan in progress."
        case .alert: return "Protection mesh distorted — detection found."
        }
    }
}
