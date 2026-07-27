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
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 * 0.82
            let points = (0..<nodeCount).map { i -> CGPoint in
                let angle = (Double(i) / Double(nodeCount)) * 2 * .pi - .pi / 2
                return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            }
            let presentCount = Int(Double(nodeCount) * completeness)

            // Nucleus
            let nucleusRadius = size.width * 0.05
            context.fill(Path(ellipseIn: CGRect(x: center.x - nucleusRadius, y: center.y - nucleusRadius,
                                                 width: nucleusRadius * 2, height: nucleusRadius * 2)),
                         with: .color(tint))

            // Edges between neighboring present nodes (mesh containment lines).
            for i in 0..<nodeCount {
                let j = (i + 1) % nodeCount
                let bothPresent = i < presentCount && j < presentCount
                var path = Path()
                path.move(to: points[i])
                path.addLine(to: points[j])
                if bothPresent {
                    context.stroke(path, with: .color(tint.opacity(0.6)), lineWidth: 1.5)
                } else {
                    context.stroke(path, with: .color(Color.secondary.opacity(0.25)),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }
                // Spoke from nucleus to node.
                var spoke = Path()
                spoke.move(to: center)
                spoke.addLine(to: points[i])
                context.stroke(spoke, with: .color((i < presentCount ? tint : Color.secondary).opacity(i < presentCount ? 0.35 : 0.15)),
                                lineWidth: 1)
            }

            // Nodes.
            for (i, p) in points.enumerated() {
                let present = i < presentCount
                let r: CGFloat = present ? 4 : 3
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                if present {
                    context.fill(Path(ellipseIn: rect), with: .color(tint))
                } else {
                    context.stroke(Path(ellipseIn: rect), with: .color(Color.secondary.opacity(0.35)), lineWidth: 1)
                }
            }
        }
        .accessibilityHidden(true)
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
