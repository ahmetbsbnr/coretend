// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

// MARK: - CoreTend "Instrument" design tokens
//
// The app reads as a precision instrument: flat panels separated by
// hairlines, tight radii, dense-but-legible rows, and numbers set large and
// light. Depth comes from surface steps (canvas → panel → well), never from
// drop shadows or glass.

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

/// Tight, engineered radii. Panels are barely softened; only compact
/// statuses and toggles use the capsule.
public enum MCRadius {
    public static let small: CGFloat = 4
    /// Buttons, fields, segmented controls.
    public static let control: CGFloat = 5
    public static let card: CGFloat = 7
    public static let hero: CGFloat = 10
    public static let capsule: CGFloat = 999
}

public enum MCSize {
    public static let sidebarMin: CGFloat = 200
    public static let sidebarIdeal: CGFloat = 232
    public static let windowMinWidth: CGFloat = 820
    public static let windowMinHeight: CGFloat = 560
    public static let metricRing: CGFloat = 76
    public static let chartHeight: CGFloat = 132
    /// Readable measure for prose and forms inside a page.
    public static let contentMax: CGFloat = 1120
    /// Narrow column used by briefing/landing layouts.
    public static let columnMax: CGFloat = 520
    /// Standard row height for dense lists.
    public static let rowHeight: CGFloat = 40
    /// Icon tile (square) used by rows and empty states.
    public static let iconTile: CGFloat = 28
}

/// Motion tokens. All animation in the app routes through these so that
/// Reduce Motion has one choke point (`MCMotion.animation(_:reduce:)`).
public enum MCMotion {
    public static let quick: Double = 0.15
    public static let standard: Double = 0.3
    public static let gentle: Double = 0.55

    public static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.85)
    public static let settle = Animation.spring(response: 0.55, dampingFraction: 0.9)

    /// Returns `nil` (no animation) when Reduce Motion is on.
    public static func animation(_ base: Animation, reduce: Bool) -> Animation? {
        reduce ? nil : base
    }
}

public enum MCOpacity {
    /// Track ring behind a determinate progress arc (Core Bloom, metric rings).
    public static let orbitTrack: Double = 0.14
}

/// Semantic colour aliases. Views reference these role names (`accent`,
/// `warning`, …) rather than raw `MCColor` hues, so a palette change is one
/// edit here. Layout values live in `MCRadius` / `MCSpacing` / `MCSize`.
public enum MCTheme {
    public static let accent = MCColor.teal
    public static let accentSecondary = MCColor.graphite
    public static let warning = MCColor.amber
    public static let danger = MCColor.coral
    public static let success = MCColor.success
}
