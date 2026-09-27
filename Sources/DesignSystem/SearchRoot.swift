import SwiftUI

/// The root drawn under the search field (UI guide § 8, "Recherche ⌘K"): it grows with what is
/// typed, with a few rootlets along the way, and withdraws as the query is erased.
public struct SearchRoot: Shape {
    public var progress: Double

    public init(progress: Double) { self.progress = progress }

    public nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Full length is reached at 14 characters; one character already shows a sprout of root.
    public nonisolated static func progress(forQueryLength length: Int) -> Double {
        guard length > 0 else { return 0 }
        return min(1, 0.08 + Double(length) / 14 * 0.92)
    }

    public func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        var main = Path()
        let y = rect.midY
        let width = rect.width
        main.move(to: CGPoint(x: rect.minX, y: y))
        // A gentle wave along the field.
        let steps = 6
        for step in 1...steps {
            let x = rect.minX + width * Double(step) / Double(steps)
            let previous = rect.minX + width * Double(step - 1) / Double(steps)
            let lift: Double = step.isMultiple(of: 2) ? -2.5 : 2.5
            main.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: (previous + x) / 2, y: y + lift))
        }
        var drawn = main.trimmedPath(from: 0, to: progress)
        // Rootlets appear once the root has passed them.
        for (fraction, length) in [(0.22, 5.0), (0.47, 4.0), (0.71, 5.5), (0.9, 3.5)] where progress >= fraction {
            let x = rect.minX + width * fraction
            drawn.move(to: CGPoint(x: x, y: y))
            drawn.addQuadCurve(to: CGPoint(x: x + length, y: y + length), control: CGPoint(x: x + 1, y: y + length * 0.8))
        }
        return drawn
    }
}
