import SwiftUI

/// Semantic text styles. San Francisco only; identity comes from rhythm,
/// weight contrast and rounded numerics — not from an external font.
public enum MCFont {
    public static let displayMetric = Font.system(size: 40, weight: .semibold, design: .rounded)
    public static let heroTitle = Font.system(size: 26, weight: .bold)
    public static let pageTitle = Font.title2.weight(.semibold)
    public static let sectionTitle = Font.subheadline.weight(.semibold)
    public static let cardTitle = Font.headline
    public static let body = Font.body
    public static let secondaryBody = Font.callout
    public static let caption = Font.caption
    public static let metric = Font.system(.title3, design: .rounded).weight(.semibold)
    public static let monospacedMetric = Font.body.monospacedDigit()
    public static let badge = Font.caption2.weight(.semibold)
    public static let tableHeader = Font.caption.weight(.medium)
}
