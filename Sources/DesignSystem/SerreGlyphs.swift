import SwiftUI

/// The Serre icon set (Documentation/Design/UI-guide.md § 5): line drawings on a 24-unit grid,
/// stroked at 1.6 units with round ends, each with one organic curve.
public enum SerreGlyph: CaseIterable, Sendable {
    /// The state of the greenhouse: a sprout above the soil line.
    case overview
    /// Plots: a bed divided into parcels, one sprouting.
    case explore
    /// Pruning shears.
    case cleanup
    /// Twin leaves.
    case duplicates
    /// A potted plant.
    case applications
    /// A plant label with a check.
    case integrity
    /// Sap: a wave ending in a leaf.
    case performance
    /// The herbarium: an open book holding a pressed leaf.
    case record
    /// Two sliders with leaf-shaped knobs.
    case settings
    /// A loupe.
    case search
}

public struct SerreGlyphShape: Shape {
    public let glyph: SerreGlyph

    public init(glyph: SerreGlyph) { self.glyph = glyph }

    public func path(in rect: CGRect) -> Path {
        var p = Path()
        switch glyph {
        case .overview:
            p.move(to: pt(3, 19)); p.addLine(to: pt(21, 19))
            p.move(to: pt(12, 19)); p.addLine(to: pt(12, 10.5))
            leaf(&p, base: pt(12, 13.5), tip: pt(6.5, 8), c1: pt(8.2, 13.4), c2: pt(6.4, 11), back1: pt(9.8, 8.1), back2: pt(12, 10.4))
            leaf(&p, base: pt(12, 11), tip: pt(18, 5), c1: pt(12, 7.6), c2: pt(14.4, 5), back1: pt(18, 8.4), back2: pt(15.4, 11))
        case .explore:
            p.addRoundedRect(in: CGRect(x: 3.5, y: 4.5, width: 17, height: 15), cornerSize: CGSize(width: 3, height: 3))
            p.move(to: pt(3.5, 12)); p.addLine(to: pt(20.5, 12))
            p.move(to: pt(11, 4.5)); p.addLine(to: pt(11, 19.5))
            p.move(to: pt(15.8, 10.2)); p.addCurve(to: pt(18.2, 6.8), control1: pt(15.6, 8.4), control2: pt(16.6, 7.1))
        case .cleanup:
            p.move(to: pt(6, 4.5)); p.addCurve(to: pt(12, 12), control1: pt(8.5, 7.5), control2: pt(10, 9.6))
            p.move(to: pt(18, 4.5)); p.addCurve(to: pt(12, 12), control1: pt(15.5, 7.5), control2: pt(14, 9.6))
            p.move(to: pt(12, 12)); p.addLine(to: pt(9.7, 15))
            p.move(to: pt(12, 12)); p.addLine(to: pt(14.3, 15))
            p.addEllipse(in: CGRect(x: 5.6, y: 14.6, width: 5, height: 5))
            p.addEllipse(in: CGRect(x: 13.4, y: 14.6, width: 5, height: 5))
        case .duplicates:
            for x in [8.0, 16.0] {
                p.move(to: pt(x, 20)); p.addCurve(to: pt(x, 7.5), control1: pt(x - 3.6, 16.5), control2: pt(x - 3.6, 11))
                p.addCurve(to: pt(x, 20), control1: pt(x + 3.6, 11), control2: pt(x + 3.6, 16.5))
                p.move(to: pt(x, 20)); p.addLine(to: pt(x, 11.5))
            }
        case .applications:
            p.move(to: pt(6, 14)); p.addLine(to: pt(18, 14))
            p.move(to: pt(7.2, 14)); p.addLine(to: pt(8.4, 20)); p.addLine(to: pt(15.6, 20)); p.addLine(to: pt(16.8, 14))
            p.move(to: pt(12, 14)); p.addLine(to: pt(12, 8.5))
            leaf(&p, base: pt(12, 10.5), tip: pt(7.5, 5.5), c1: pt(9, 10.4), c2: pt(7.5, 8.2), back1: pt(10, 5.6), back2: pt(12, 7.6))
            leaf(&p, base: pt(12, 8.5), tip: pt(16.5, 4), c1: pt(12, 6), c2: pt(13.8, 4), back1: pt(16.5, 6.6), back2: pt(14.6, 8.5))
        case .integrity:
            p.move(to: pt(4.5, 5.5)); p.addLine(to: pt(14, 5.5)); p.addLine(to: pt(19.5, 10))
            p.addLine(to: pt(14, 14.5)); p.addLine(to: pt(4.5, 14.5)); p.closeSubpath()
            p.move(to: pt(9, 14.5)); p.addCurve(to: pt(9.6, 20.5), control1: pt(9.2, 16.5), control2: pt(9.5, 18.5))
            p.move(to: pt(7.3, 10)); p.addLine(to: pt(9.2, 11.8)); p.addLine(to: pt(12.4, 8.3))
        case .performance:
            p.move(to: pt(3, 15)); p.addCurve(to: pt(8.5, 9), control1: pt(5.5, 15), control2: pt(6, 9))
            p.addCurve(to: pt(14, 17), control1: pt(11, 9), control2: pt(11.5, 17))
            p.addCurve(to: pt(18.5, 11.5), control1: pt(16, 17), control2: pt(16.8, 12))
            leaf(&p, base: pt(18.5, 11.5), tip: pt(21.2, 7.2), c1: pt(18.5, 9.2), c2: pt(19.6, 7.6), back1: pt(21.4, 9.6), back2: pt(20.2, 11.2))
        case .record:
            p.move(to: pt(3.5, 6)); p.addCurve(to: pt(12, 7), control1: pt(6.5, 5), control2: pt(9.5, 5.3))
            p.addCurve(to: pt(20.5, 6), control1: pt(14.5, 5.3), control2: pt(17.5, 5))
            p.addLine(to: pt(20.5, 18.5))
            p.addCurve(to: pt(12, 19.5), control1: pt(17.5, 17.5), control2: pt(14.5, 17.8))
            p.addCurve(to: pt(3.5, 18.5), control1: pt(9.5, 17.8), control2: pt(6.5, 17.5))
            p.closeSubpath()
            p.move(to: pt(12, 7)); p.addLine(to: pt(12, 19.5))
            leaf(&p, base: pt(14.8, 15.6), tip: pt(18.3, 9.8), c1: pt(14.8, 12.6), c2: pt(16.2, 10.4), back1: pt(18.4, 12.8), back2: pt(17, 15))
        case .settings:
            p.move(to: pt(3.5, 8)); p.addLine(to: pt(20.5, 8))
            p.move(to: pt(3.5, 16)); p.addLine(to: pt(20.5, 16))
            for (x, y) in [(9.0, 8.0), (15.0, 16.0)] {
                p.move(to: pt(x, y - 2.8)); p.addCurve(to: pt(x, y + 2.8), control1: pt(x + 2.2, y - 1.6), control2: pt(x + 2.2, y + 1.6))
                p.addCurve(to: pt(x, y - 2.8), control1: pt(x - 2.2, y + 1.6), control2: pt(x - 2.2, y - 1.6))
            }
        case .search:
            p.addEllipse(in: CGRect(x: 4.5, y: 4.5, width: 12, height: 12))
            p.move(to: pt(14.9, 14.9)); p.addCurve(to: pt(20, 20.5), control1: pt(16.8, 16.6), control2: pt(18.2, 18.4))
        }
        return p.applying(CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width / 24, y: rect.height / 24))
    }

    private func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    /// A closed leaf from `base` to `tip` and back.
    private func leaf(_ p: inout Path, base: CGPoint, tip: CGPoint, c1: CGPoint, c2: CGPoint, back1: CGPoint, back2: CGPoint) {
        p.move(to: base)
        p.addCurve(to: tip, control1: c1, control2: c2)
        p.addCurve(to: base, control1: back1, control2: back2)
    }
}

/// A Serre icon at the size of the surrounding text.
public struct SerreIcon: View {
    let glyph: SerreGlyph
    let size: CGFloat

    public init(_ glyph: SerreGlyph, size: CGFloat = 18) {
        self.glyph = glyph
        self.size = size
    }

    public var body: some View {
        SerreGlyphShape(glyph: glyph)
            .stroke(style: StrokeStyle(lineWidth: 1.6 * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Risk leaves

public enum RiskLevel: CaseIterable, Sendable { case low, medium, high }

/// Risk is told by shape as well as colour and label: a whole leaf, a half-filled leaf, a split leaf.
public struct RiskLeafShape: Shape {
    public let level: RiskLevel

    public init(level: RiskLevel) { self.level = level }

    public func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + x * w, y: rect.minY + y * h) }
        var p = Path()
        switch level {
        case .low:
            p.move(to: pt(0.5, 0.95))
            p.addCurve(to: pt(0.5, 0.05), control1: pt(0.15, 0.72), control2: pt(0.15, 0.3))
            p.addCurve(to: pt(0.5, 0.95), control1: pt(0.85, 0.3), control2: pt(0.85, 0.72))
        case .medium:
            // Left half filled; the right half is an outline drawn by RiskLeaf.
            p.move(to: pt(0.5, 0.95))
            p.addCurve(to: pt(0.5, 0.05), control1: pt(0.15, 0.72), control2: pt(0.15, 0.3))
            p.closeSubpath()
        case .high:
            // Two halves split apart along the midrib.
            p.move(to: pt(0.42, 0.95))
            p.addCurve(to: pt(0.42, 0.05), control1: pt(0.07, 0.72), control2: pt(0.07, 0.3))
            p.addLine(to: pt(0.42, 0.95))
            p.move(to: pt(0.58, 0.95))
            p.addCurve(to: pt(0.58, 0.05), control1: pt(0.93, 0.72), control2: pt(0.93, 0.3))
            p.addLine(to: pt(0.58, 0.95))
        }
        return p
    }
}

/// The risk leaf in its colour; always shown beside the risk's text label.
public struct RiskLeaf: View {
    let level: RiskLevel
    let size: CGFloat

    public init(_ level: RiskLevel, size: CGFloat = 12) {
        self.level = level
        self.size = size
    }

    public var body: some View {
        ZStack {
            if level == .medium { RiskLeafShape(level: .low).stroke(lineWidth: 1) }
            RiskLeafShape(level: level).fill()
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var color: Color {
        switch level {
        case .low: Palette.accent.color
        case .medium: Palette.caution.color
        case .high: Palette.danger.color
        }
    }
}
