import SwiftUI

// MARK: - Paper / Ink / Cobalt design tokens

/// Spacing scale (pt). Views compose from these; no arbitrary values.
public enum MCSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    /// Standard page padding for module screens.
    public static let page: CGFloat = 24
}

public enum MCRadius {
    public static let small: CGFloat = 6
    public static let card: CGFloat = 8
    public static let hero: CGFloat = 12
    public static let capsule: CGFloat = 999
}

public enum MCSize {
    public static let sidebarMin: CGFloat = 190
    public static let sidebarIdeal: CGFloat = 220
    public static let windowMinWidth: CGFloat = 860
    public static let windowMinHeight: CGFloat = 580
    public static let heroCore: CGFloat = 200
    public static let metricRing: CGFloat = 76
    public static let chartHeight: CGFloat = 140
    public static let moduleIcon: CGFloat = 30
}

/// Motion tokens. All animation in the app routes through these so that
/// Reduce Motion has one choke point (`MCMotion.animation(_:reduce:)`).
public enum MCMotion {
    public static let quick: Double = 0.15
    public static let standard: Double = 0.3
    public static let gentle: Double = 0.55

    public static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.85)
    public static let settle = Animation.spring(response: 0.55, dampingFraction: 0.9)
    public static let ease = Animation.easeInOut(duration: standard)

    /// Returns `nil` (no animation) when Reduce Motion is on.
    public static func animation(_ base: Animation, reduce: Bool) -> Animation? {
        reduce ? nil : base
    }
}

public enum MCOpacity {
    public static let hover: Double = 0.08
    public static let pressed: Double = 0.14
    public static let disabled: Double = 0.4
    public static let orbitTrack: Double = 0.14
    public static let halo: Double = 0.22
}

/// Backwards-compatible theme namespace (older views reference MCTheme).
public enum MCTheme {
    public static let accent = MCColor.coreMint
    public static let accentSecondary = MCColor.ionViolet
    public static let warning = MCColor.solarAmber
    public static let danger = MCColor.pulseCoral
    public static let success = MCColor.success

    public static let cornerRadius = MCRadius.card
    public static let cardPadding = MCSpacing.md
    public static let sidebarWidth = MCSize.sidebarIdeal
}
