// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import AppKit

/// How every CoreTend colour resolves.
///
/// One token, four values: light, dark, and a high-contrast variant of each.
/// `NSColor(name:dynamicProvider:)` picks between them at *draw* time, from the
/// appearance the view is actually being drawn in — which means Light Mode,
/// Dark Mode and Increase Contrast all work without a single call site
/// changing, and without threading an environment value through eighty files.
///
/// ## Why this replaces a fixed dark palette
///
/// The app used to pin `.darkAqua` and ship one palette. The reasoning was that
/// colour is the loudest thing an app says about itself and CoreTend should say
/// one thing. That part still holds — and it is satisfied by *owning both
/// palettes*, derived from the same brand hues, rather than by refusing one of
/// them. Pinning the appearance also meant a user who runs their Mac in Light
/// Mode got one window that ignored them.
///
/// What does not change: neither palette is the system's. Light is warm paper
/// and a deep teal, not `NSColor.windowBackgroundColor`.
///
/// ## Every value here is measured
///
/// `PaletteContrastTests` recomputes each pairing, in both appearances and both
/// contrast modes. A hex edit that drops a pairing under its floor fails the
/// build rather than shipping.
public struct MCPaletteColor: Sendable {
    public let light: UInt32
    public let dark: UInt32
    /// Increase Contrast variants. Defaulting these to the base values would
    /// silently make the setting a no-op, so they are required.
    public let lightHighContrast: UInt32
    public let darkHighContrast: UInt32

    public init(light: UInt32, dark: UInt32,
                lightHighContrast: UInt32, darkHighContrast: UInt32) {
        self.light = light
        self.dark = dark
        self.lightHighContrast = lightHighContrast
        self.darkHighContrast = darkHighContrast
    }

    /// A token that is genuinely the same in both appearances — a fixed ink on
    /// a fixed fill, for instance. Rare, and spelled out so it reads as a
    /// decision rather than as a half-filled token.
    public static func fixed(_ hex: UInt32, highContrast: UInt32? = nil) -> MCPaletteColor {
        MCPaletteColor(light: hex, dark: hex,
                       lightHighContrast: highContrast ?? hex,
                       darkHighContrast: highContrast ?? hex)
    }

    public func value(dark isDark: Bool, highContrast: Bool) -> UInt32 {
        switch (isDark, highContrast) {
        case (true, false): dark
        case (true, true): darkHighContrast
        case (false, false): light
        case (false, true): lightHighContrast
        }
    }

    /// A `Color` that re-resolves whenever the drawing appearance changes.
    ///
    /// The provider runs on every draw, so `accessibilityDisplayShouldIncreaseContrast`
    /// is read live: toggling the setting repaints without a relaunch.
    public var color: Color {
        Color(nsColor: nsColor)
    }

    public var nsColor: NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            return MCPaletteColor.srgb(value(dark: isDark, highContrast: contrast))
        }
    }

    static func srgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: Double((hex >> 16) & 0xFF) / 255,
                green: Double((hex >> 8) & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255,
                alpha: 1)
    }
}

/// The canonical values, in both appearances.
///
/// Read by the token exporter and the website, so a colour cannot drift between
/// the app and its marketing surface.
public enum MCPalette {

    // MARK: - Ground and elevation
    //
    // A four-step ladder in each appearance, so a card on a panel on the ground
    // reads as three planes rather than one flat field with hairlines on it.
    // In Light the ladder runs the other way — raised surfaces get *lighter*
    // than the ground, because on a light field elevation reads as approaching
    // the light source, not as receding from it.

    /// The canvas.
    ///
    /// Under Increase Contrast the light ground steps *down* off pure white
    /// rather than up onto it. Raised surfaces in Light are white, and a ground
    /// that also went white collapsed the four-step ladder into three — a card
    /// on a panel became one flat field exactly when the user had asked for
    /// more separation, not less. `elevationStepsAreDistinct` caught it.
    ///
    /// Neither pure black nor pure white: pure black under light
    /// text haloes and smears on OLED scroll edges, and pure white raises the
    /// same halation problem in reverse for long reading.
    public static let ground = MCPaletteColor(
        light: 0xF7F8F9, dark: 0x14171A, lightHighContrast: 0xF2F4F6, darkHighContrast: 0x000000)
    /// Sunken surfaces: the sidebar, inset wells.
    public static let sunken = MCPaletteColor(
        light: 0xEDEFF1, dark: 0x1B1F23, lightHighContrast: 0xE4E8EB, darkHighContrast: 0x0A0C0E)
    /// The default raised surface: cards, rows, popovers.
    public static let raised = MCPaletteColor(
        light: 0xFFFFFF, dark: 0x22272C, lightHighContrast: 0xFFFFFF, darkHighContrast: 0x2A3037)
    /// One step above raised: hover, selected rows, controls.
    public static let raisedHigh = MCPaletteColor(
        light: 0xE4E7EA, dark: 0x2B3137, lightHighContrast: 0xD6DBE0, darkHighContrast: 0x3A424A)
    /// Hairlines and dividers. Never text — it is not required to clear a text
    /// floor, and under Increase Contrast it darkens hard, because the whole
    /// point of that setting is that separations become explicit.
    public static let border = MCPaletteColor(
        light: 0xD2D7DC, dark: 0x3A4047, lightHighContrast: 0x8A929A, darkHighContrast: 0x6A737C)

    // MARK: - Text
    //
    // Three weights. There is no fourth: a fourth tier is always either
    // decoration or information someone is hiding.

    public static let textPrimary = MCPaletteColor(
        light: 0x14171A, dark: 0xF2F5F7, lightHighContrast: 0x000000, darkHighContrast: 0xFFFFFF)
    public static let textSecondary = MCPaletteColor(
        light: 0x4A545E, dark: 0xA8B2BC, lightHighContrast: 0x2B333B, darkHighContrast: 0xC8D0D8)
    /// Tertiary: units, inert glyphs, supporting detail.
    ///
    /// This used to sit at 4.1:1 with a note saying it was below the body
    /// minimum on purpose and must never be the only carrier of meaning. A
    /// token documented as unsafe gets misused — it already was, on the
    /// Record's timestamps, where the time is the primary key. Both appearances
    /// now clear 4.5:1 on every surface they are allowed on, and the escape
    /// hatch is gone.
    public static let textTertiary = MCPaletteColor(
        light: 0x5D6873, dark: 0x8D99A4, lightHighContrast: 0x3E4750, darkHighContrast: 0xAAB4BE)

    // MARK: - Accent and signal
    //
    // The brand teal cannot be one value across both appearances: #4FD1C5 on
    // white measures 1.7:1. Light gets the deep teal, which carries text
    // weight on a light field; dark keeps the bright one. Same hue family,
    // two legible members of it.

    public static let teal = MCPaletteColor(
        light: 0x0F7A72, dark: 0x4FD1C5, lightHighContrast: 0x085650, darkHighContrast: 0x7FE3DA)
    public static let tealBright = MCPaletteColor(
        light: 0x0B5E58, dark: 0x6FDCD2, lightHighContrast: 0x064540, darkHighContrast: 0x9BEDE6)
    public static let tealDeep = MCPaletteColor(
        light: 0x0B5E58, dark: 0x2FA79C, lightHighContrast: 0x053B37, darkHighContrast: 0x45BDB1)
    /// A tint, never a text background on its own.
    public static let tealWash = MCPaletteColor(
        light: 0xDCF0EE, dark: 0x0E3B38, lightHighContrast: 0xC9E7E4, darkHighContrast: 0x145049)

    public static let amber = MCPaletteColor(
        light: 0x8A5A00, dark: 0xF5C56B, lightHighContrast: 0x5E3D00, darkHighContrast: 0xFFD98F)
    public static let coral = MCPaletteColor(
        light: 0xB3301F, dark: 0xF28B7D, lightHighContrast: 0x8A2214, darkHighContrast: 0xFFA99D)
    public static let green = MCPaletteColor(
        light: 0x1E7A4C, dark: 0x5BC98E, lightHighContrast: 0x125634, darkHighContrast: 0x84DDAB)
    public static let slate = MCPaletteColor(
        light: 0x5A6672, dark: 0x8794A0, lightHighContrast: 0x3A434D, darkHighContrast: 0xAAB5BF)

    /// The label on a filled accent control.
    ///
    /// Not white. White on the dark teal measures 1.87:1, and that was the
    /// label of the app's primary action on every screen that had one. In Light
    /// the accent is dark enough that white is the legible choice; in Dark it
    /// is the ground colour. This is why `MCPrimaryButtonStyle` exists rather
    /// than `.borderedProminent`, which pairs a tint with a white label and
    /// never checks whether the two can be read together.
    public static let onAccent = MCPaletteColor(
        light: 0xFFFFFF, dark: 0x14171A, lightHighContrast: 0xFFFFFF, darkHighContrast: 0x000000)
}
