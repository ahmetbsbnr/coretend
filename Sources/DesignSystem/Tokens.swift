// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

// MARK: - Porcelain / Slate / Teal design tokens

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
    /// Capped so a dragged divider cannot turn the sidebar into half the
    /// window on a wide display.
    public static let sidebarMax: CGFloat = 320
    /// Sidebar minimum (190) plus what the Dashboard hero genuinely needs
    /// (ring, copy column, and a 40pt metric side by side ≈ 690), plus room
    /// rather than exactly enough. At 860 the two minimums did not both fit and
    /// the split view resolved it by starving the sidebar until its contents
    /// overflowed and clipped.
    public static let windowMinWidth: CGFloat = 1000
    public static let windowMinHeight: CGFloat = 580
    /// What the window opens at on a first launch. Wide enough that the
    /// Dashboard's three-column hero and the sidebar both have room, so the
    /// first thing a new user sees is the layout as designed rather than its
    /// compressed form.
    public static let windowDefaultWidth: CGFloat = 1180
    public static let windowDefaultHeight: CGFloat = 800
    public static let metricRing: CGFloat = 76
    public static let chartHeight: CGFloat = 140
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
