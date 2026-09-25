// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

/// Semantic text styles. San Francisco only; identity comes from rhythm,
/// weight contrast and a monospaced "instrument" voice for labels and
/// figures — not from an external font.
///
/// Three voices:
/// - **Readout** — large, light, tabular numerals (`displayMetric`,
///   `readout`, `metric`). Numbers are the product; they get the size.
/// - **Prose** — SF Pro at native sizes for titles and body copy.
/// - **Label** — small monospaced caps (`eyebrow`, `badge`, `mono`) for
///   section labels, units, paths and status tags.
public enum MCFont {
    public static let displayMetric = Font.system(size: 46, weight: .light).monospacedDigit()
    public static let readout = Font.system(size: 30, weight: .light).monospacedDigit()
    public static let heroTitle = Font.system(size: 26, weight: .semibold)
    public static let pageTitle = Font.system(size: 22, weight: .semibold)
    /// Section labels — monospaced caps. Pair with `.textCase(.uppercase)`
    /// and `MCTracking.label`.
    public static let sectionTitle = Font.system(size: 10.5, weight: .semibold, design: .monospaced)
    public static let eyebrow = sectionTitle
    public static let cardTitle = Font.system(size: 13, weight: .semibold)
    public static let body = Font.body
    public static let secondaryBody = Font.callout
    public static let caption = Font.caption
    public static let metric = Font.system(size: 19, weight: .regular).monospacedDigit()
    public static let badge = Font.system(size: 10, weight: .semibold, design: .monospaced)
    /// Paths, identifiers, byte counts inside rows.
    public static let mono = Font.system(size: 11.5, weight: .regular, design: .monospaced)
}

/// Letter-spacing tokens.
public enum MCTracking {
    /// Monospaced caps labels.
    public static let label: CGFloat = 0.9
    /// Large light numerals read tighter.
    public static let display: CGFloat = -1.2
    public static let title: CGFloat = -0.3
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
    /// Small inline status glyph (lock/cloud indicators on list rows).
    public static let inline: CGFloat = 8
}
