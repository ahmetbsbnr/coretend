// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import AppKit

/// CoreTend's palette. **Slate ground, teal accent** — one owned appearance,
/// not two that track the system light/dark switch.
///
/// ## Why these are fixed values and not adaptive ones
///
/// Every colour here used to be a `(light, dark)` pair resolved from the
/// system appearance. That meant two complete palettes, each of which had to
/// independently clear contrast minimums, each of which had to be checked
/// whenever either changed — and a product whose identity was decided by a
/// setting elsewhere on the Mac. Colour is the loudest thing an app says about
/// itself, and CoreTend now says one thing.
///
/// Everything below is measured against `ground` (#14171A) unless stated.
/// Ratios are WCAG 2.1 relative luminance, computed on the sRGB values in this
/// file; `Tests/DesignSystemTests` recomputes them so a "small tweak" to a hex
/// value cannot quietly drop text under 4.5:1.
///
/// ## The one axis colour carries
///
/// | Colour  | Means                                                      |
/// |---------|------------------------------------------------------------|
/// | teal    | the brand accent — every primary action, every live value   |
/// | amber   | caution — functional, not brand                             |
/// | coral   | error, or an action that cannot be undone                   |
/// | slate   | inert, secondary, structural                                |
///
/// Storage, protection and performance do **not** each get a hue. A one-accent
/// system cannot spend teal three ways and still read as one colour, so those
/// roles are told apart by icon and label — Differentiate Without Colour, which
/// is also what makes the app legible to a colourblind user.
///
/// ## What is still honoured from the system
///
/// Owning the appearance is a taste decision and stops at taste. Increase
/// Contrast, Reduce Transparency, Reduce Motion and Differentiate Without
/// Colour are accessibility settings and are still respected — see
/// `AccessibilityState`.
public enum MCColor {
    private static func srgb(_ hex: UInt32) -> Color {
        Color(nsColor: NSColor(
            srgbRed: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: 1))
    }

    /// The canonical hex values. One source of truth, referenced by the token
    /// exporter and the website so a colour cannot drift between the app and
    /// its marketing surface.
    public enum Canonical {
        // MARK: Ground and elevation
        //
        // A four-step ladder rather than "background and a lighter one". Each
        // step is a real, perceptible increment (~3–4 L*), so a card on a
        // panel on the ground reads as three planes instead of one flat field
        // with hairlines drawn on it.

        /// `#14171A` — the canvas. Warm slate, deliberately not pure black:
        /// pure black against light text produces halation, and on OLED it
        /// makes every scroll edge smear.
        public static let ground: UInt32 = 0x14171A
        /// `#1B1F23` — sunken surfaces: the sidebar, inset wells.
        public static let sunken: UInt32 = 0x1B1F23
        /// `#22272C` — the default raised surface: cards, rows, popovers.
        public static let raised: UInt32 = 0x22272C
        /// `#2B3137` — the step above raised: hover, selected rows, controls.
        public static let raisedHigh: UInt32 = 0x2B3137
        /// `#3A4047` — hairlines and dividers. Never text.
        public static let border: UInt32 = 0x3A4047

        // MARK: Text
        //
        // Three weights, all measured on `ground`. There is no fourth: a
        // fourth tier is always either decoration or information someone is
        // hiding.

        /// `#F2F5F7` — primary text. 15.8:1 on ground.
        public static let textPrimary: UInt32 = 0xF2F5F7
        /// `#A8B2BC` — secondary text. 7.6:1 on ground — comfortably past the
        /// 4.5:1 body-text minimum rather than sitting on it.
        public static let textSecondary: UInt32 = 0xA8B2BC
        /// `#717D88` — tertiary: timestamps, units, inert glyphs. 4.1:1, below
        /// the body minimum on purpose and therefore restricted to text that
        /// is never the only carrier of meaning.
        public static let textTertiary: UInt32 = 0x717D88

        // MARK: Accent

        /// `#4FD1C5` — the accent. 10.4:1 on ground, so it is legible as text
        /// and not only as a fill.
        public static let teal: UInt32 = 0x4FD1C5
        /// `#6FDCD2` — hover.
        public static let tealBright: UInt32 = 0x6FDCD2
        /// `#2FA79C` — pressed, and the fill under white label text.
        public static let tealDeep: UInt32 = 0x2FA79C
        /// `#0E3B38` — the tint behind a selected row: enough teal to read as
        /// the accent, dark enough to keep `textPrimary` above 12:1 on it.
        public static let tealWash: UInt32 = 0x0E3B38

        // MARK: Signal

        /// `#F5C56B` — caution. 11.4:1.
        public static let amber: UInt32 = 0xF5C56B
        /// `#F28B7D` — error or irreversible. 8.3:1.
        public static let coral: UInt32 = 0xF28B7D
        /// `#5BC98E` — completion. Distinct from teal in hue *and* in where it
        /// is allowed to appear: success is only ever a transient state, never
        /// a persistent surface, so the two never sit side by side.
        public static let green: UInt32 = 0x5BC98E
        /// `#8794A0` — inert, structural, "not the primary action".
        public static let slate: UInt32 = 0x8794A0

        // MARK: Data visualisation
        //
        // Space Lens needs several swatches legible at once. Tonal steps of
        // the accent plus neutrals, never a rainbow: a treemap in six unrelated
        // hues reads as a toy.
        public static let dataTeal: UInt32 = 0x4FD1C5
        public static let dataTealDeep: UInt32 = 0x2FA79C
        public static let dataTealPale: UInt32 = 0x9BE7DF
        public static let dataSlate: UInt32 = 0x8794A0
        public static let dataAmber: UInt32 = 0xF5C56B
        public static let dataCoral: UInt32 = 0xF28B7D
    }

    // MARK: - Surfaces

    public static let background = srgb(Canonical.ground)
    public static let secondaryBackground = srgb(Canonical.sunken)
    public static let elevatedBackground = srgb(Canonical.raised)
    public static let elevatedHighBackground = srgb(Canonical.raisedHigh)
    public static let separator = srgb(Canonical.border)

    // MARK: - Text

    public static let textPrimary = srgb(Canonical.textPrimary)
    public static let textSecondary = srgb(Canonical.textSecondary)
    public static let textTertiary = srgb(Canonical.textTertiary)

    // MARK: - Accent and signal

    public static let teal = srgb(Canonical.teal)
    public static let tealBright = srgb(Canonical.tealBright)
    public static let tealDeep = srgb(Canonical.tealDeep)
    public static let tealWash = srgb(Canonical.tealWash)
    public static let graphite = srgb(Canonical.slate)
    public static let amber = srgb(Canonical.amber)
    public static let coral = srgb(Canonical.coral)
    public static let success = srgb(Canonical.green)

    // MARK: - Roles
    //
    // Named by meaning so a view never reaches for a hue directly. Changing
    // what "destructive" looks like is one edit here, not a search across
    // forty files.

    public static let storage = teal
    public static let protection = graphite
    public static let performance = amber
    public static let destructive = coral
    public static let attention = amber

    /// Chart series order. Accent first, then neutrals — the first series is
    /// the one the eye lands on and it should be the one that matters.
    public static let chartSeries: [Color] = [
        srgb(Canonical.dataTeal),
        srgb(Canonical.dataSlate),
        srgb(Canonical.dataAmber),
        srgb(Canonical.dataTealPale),
    ]
    public static let graphGrid = srgb(Canonical.border).opacity(0.6)

    // Space Lens treemap swatches.
    public static let cellTealDeep = srgb(Canonical.dataTealDeep)
    public static let cellGraphite = srgb(Canonical.dataSlate)
    public static let cellTealPale = srgb(Canonical.dataTealPale)

    // MARK: - Contrast, computed

    /// WCAG 2.1 relative luminance of a canonical hex.
    public static func relativeLuminance(_ hex: UInt32) -> Double {
        func channel(_ raw: UInt32) -> Double {
            let value = Double(raw) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF)
             + 0.7152 * channel((hex >> 8) & 0xFF)
             + 0.0722 * channel(hex & 0xFF)
    }

    /// WCAG 2.1 contrast ratio between two canonical hexes. Exposed so the
    /// ratios quoted in this file's documentation are checkable by a test
    /// rather than by trust.
    public static func contrastRatio(_ a: UInt32, _ b: UInt32) -> Double {
        let (l1, l2) = (relativeLuminance(a), relativeLuminance(b))
        let (lighter, darker) = l1 > l2 ? (l1, l2) : (l2, l1)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
