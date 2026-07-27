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
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let clusterCount = groupWeights.count
            let clusterCenters = (0..<clusterCount).map { i -> CGPoint in
                guard clusterCount > 1 else { return center }
                let angle = (Double(i) / Double(clusterCount)) * 2 * .pi - .pi / 2
                let r = min(size.width, size.height) * 0.28
                return CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            }

            for (ci, weight) in groupWeights.enumerated() {
                let fragmentsInGroup = max(2, Int(weight * 10))
                let clusterCenter = clusterCenters[ci]
                for f in 0..<fragmentsInGroup {
                    let seed = Double(ci * 37 + f * 13)
                    let scatterAngle = seed.truncatingRemainder(dividingBy: 6.28)
                    let scatterRadius = min(size.width, size.height) * 0.42
                    let restPoint = CGPoint(
                        x: center.x + scatterRadius * cos(scatterAngle) * (0.4 + 0.6 * (seed.truncatingRemainder(dividingBy: 7) / 7)),
                        y: center.y + scatterRadius * sin(scatterAngle) * (0.4 + 0.6 * (seed.truncatingRemainder(dividingBy: 5) / 5))
                    )
                    let clusterSpread = CGFloat(6 + (f % 3) * 4)
                    let clusteredPoint = CGPoint(
                        x: clusterCenter.x + clusterSpread * cos(seed),
                        y: clusterCenter.y + clusterSpread * sin(seed)
                    )

                    let point: CGPoint
                    let radius: CGFloat
                    let opacity: Double
                    switch phase {
                    case .rest:
                        point = restPoint; radius = 2.5; opacity = 0.4
                    case .scanning:
                        // Halfway between scattered and clustered — mid-gather.
                        point = CGPoint(x: (restPoint.x + clusteredPoint.x) / 2, y: (restPoint.y + clusteredPoint.y) / 2)
                        radius = 3; opacity = 0.6
                    case .review:
                        point = clusteredPoint; radius = 3.5; opacity = 0.85
                    case .executing:
                        // Draining downward off the clustered position.
                        point = CGPoint(x: clusteredPoint.x, y: clusteredPoint.y + size.height * 0.15)
                        radius = 3; opacity = 0.35
                    case .success:
                        point = clusterCenter; radius = 2; opacity = 0.25
                    }

                    let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)))
                }
            }

            if phase == .success {
                let checkRadius = size.width * 0.09
                context.stroke(
                    Path(ellipseIn: CGRect(x: center.x - checkRadius, y: center.y - checkRadius,
                                            width: checkRadius * 2, height: checkRadius * 2)),
                    with: .color(MCColor.success), lineWidth: 2)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: phase)
        .accessibilityHidden(true)
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
