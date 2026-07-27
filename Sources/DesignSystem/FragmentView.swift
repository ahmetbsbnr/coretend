import SwiftUI

/// Cleanup's visual motif: loose fragments (found items) that gather into
/// grouped clusters as the scan progresses, then drain away on execute.
/// Sizes are real — one fragment weight per rule group's share of bytes,
/// never decorative. Static Canvas draw per phase; SwiftUI's implicit
/// animation on phase change is skipped under Reduce Motion.
public struct MCFragmentView: View {
    public enum Phase: Equatable { case rest, scanning, review, executing, success }

    /// Relative weight (0...1] of each group, largest first. Empty means "no data yet".
    private let groupWeights: [Double]
    private let phase: Phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(groupWeights: [Double], phase: Phase) {
        self.groupWeights = groupWeights.isEmpty ? [1] : groupWeights
        self.phase = phase
    }

    private var tint: Color { MCColor.storage }

    public var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: phase)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let centers = clusterCenters(around: center, size: size)

        for (clusterIndex, weight) in groupWeights.enumerated() {
            drawFragments(
                clusterIndex: clusterIndex,
                weight: weight,
                clusterCenter: centers[clusterIndex],
                center: center,
                size: size,
                context: &context
            )
        }

        drawSuccessRing(center: center, size: size, context: &context)
    }

    private func clusterCenters(around center: CGPoint, size: CGSize) -> [CGPoint] {
        let count = groupWeights.count
        guard count > 1 else { return [center] }
        let orbitRadius = min(size.width, size.height) * 0.28

        return (0..<count).map { index in
            let fraction = Double(index) / Double(count)
            let angle = fraction * 2 * Double.pi - Double.pi / 2
            return CGPoint(
                x: center.x + orbitRadius * CGFloat(cos(angle)),
                y: center.y + orbitRadius * CGFloat(sin(angle))
            )
        }
    }

    private func drawFragments(
        clusterIndex: Int,
        weight: Double,
        clusterCenter: CGPoint,
        center: CGPoint,
        size: CGSize,
        context: inout GraphicsContext
    ) {
        let count = max(2, Int(weight * 10))
        for fragmentIndex in 0..<count {
            let seed = Double(clusterIndex * 37 + fragmentIndex * 13)
            let restPoint = restPoint(seed: seed, center: center, size: size)
            let clusteredPoint = clusteredPoint(
                seed: seed,
                fragmentIndex: fragmentIndex,
                center: clusterCenter
            )
            let visual = fragmentVisual(
                restPoint: restPoint,
                clusteredPoint: clusteredPoint,
                clusterCenter: clusterCenter,
                size: size
            )
            let diameter = visual.radius * 2
            let rect = CGRect(
                x: visual.point.x - visual.radius,
                y: visual.point.y - visual.radius,
                width: diameter,
                height: diameter
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(tint.opacity(visual.opacity))
            )
        }
    }

    private func restPoint(seed: Double, center: CGPoint, size: CGSize) -> CGPoint {
        let angle = seed.truncatingRemainder(dividingBy: 6.28)
        let radius = min(size.width, size.height) * 0.42
        let xVariance = 0.4 + 0.6 * (seed.truncatingRemainder(dividingBy: 7) / 7)
        let yVariance = 0.4 + 0.6 * (seed.truncatingRemainder(dividingBy: 5) / 5)
        return CGPoint(
            x: center.x + radius * CGFloat(cos(angle) * xVariance),
            y: center.y + radius * CGFloat(sin(angle) * yVariance)
        )
    }

    private func clusteredPoint(seed: Double, fragmentIndex: Int, center: CGPoint) -> CGPoint {
        let spread = CGFloat(6 + (fragmentIndex % 3) * 4)
        return CGPoint(
            x: center.x + spread * CGFloat(cos(seed)),
            y: center.y + spread * CGFloat(sin(seed))
        )
    }

    private func fragmentVisual(
        restPoint: CGPoint,
        clusteredPoint: CGPoint,
        clusterCenter: CGPoint,
        size: CGSize
    ) -> (point: CGPoint, radius: CGFloat, opacity: Double) {
        switch phase {
        case .rest:
            return (restPoint, 2.5, 0.4)
        case .scanning:
            let midpoint = CGPoint(
                x: (restPoint.x + clusteredPoint.x) / 2,
                y: (restPoint.y + clusteredPoint.y) / 2
            )
            return (midpoint, 3, 0.6)
        case .review:
            return (clusteredPoint, 3.5, 0.85)
        case .executing:
            let drainingPoint = CGPoint(
                x: clusteredPoint.x,
                y: clusteredPoint.y + size.height * 0.15
            )
            return (drainingPoint, 3, 0.35)
        case .success:
            return (clusterCenter, 2, 0.25)
        }
    }

    private func drawSuccessRing(
        center: CGPoint,
        size: CGSize,
        context: inout GraphicsContext
    ) {
        guard phase == .success else { return }
        let radius = size.width * 0.09
        let diameter = radius * 2
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: diameter,
            height: diameter
        )
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(MCColor.success),
            lineWidth: 2
        )
    }

    public var accessibilityDescription: String {
        switch phase {
        case .rest: return "No scan yet."
        case .scanning: return "Scanning — gathering candidate files."
        case .review: return "Review — files grouped by rule."
        case .executing: return "Cleaning up selected files."
        case .success: return "Cleanup complete."
        }
    }
}
