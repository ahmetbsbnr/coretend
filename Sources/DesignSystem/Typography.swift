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

/// Icon glyph point sizes (Image(systemName:).font(.system(size:))). These
/// were previously repeated as bare numeric literals (48/56) at ~18 call
/// sites across per-view empty/success states — named here so a future
/// change to the convention is one edit, not a grep-and-replace.
public enum MCIconSize {
    /// Secondary empty/error/success-state glyph.
    public static let emptyState: CGFloat = 48
    /// Primary/prominent empty-state glyph (module landing states).
    public static let emptyStateProminent: CGFloat = 56
    /// Glyph inside the shared MCEmptyState component (deliberately more
    /// compact than emptyState/emptyStateProminent — this one nests inside
    /// other content rather than filling a whole module landing screen).
    public static let compactState: CGFloat = 40
    /// Glyph inside the shared MCErrorState component.
    public static let errorState: CGFloat = 36
    /// Small inline status glyph (lock/cloud indicators on list rows).
    public static let inline: CGFloat = 8
}
