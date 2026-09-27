import SwiftUI
import AppKit

/// Serre colors (Documentation/Design/UI-guide.md § 2): night-greenhouse and frosted-glass
/// greens, one chlorophyll accent, pollen caution, terracotta danger. Every text role meets
/// 4.5:1 and every control outline 3:1 on canvas, sidebar, surface and raised surface, in both
/// appearances (DesignSystemTests). Separator is decorative; strongSeparator outlines controls.
public enum Appearance: CaseIterable, Sendable { case light, dark }

public struct RGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    /// WCAG 2.x relative luminance.
    public var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2.x contrast ratio, from 1 to 21.
    public func contrast(with other: RGB) -> Double {
        let (lighter, darker) = luminance >= other.luminance ? (luminance, other.luminance) : (other.luminance, luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

public struct PaletteRole: Sendable {
    public let name: String
    public let light: RGB
    public let dark: RGB

    public func value(for appearance: Appearance) -> RGB { appearance == .light ? light : dark }

    /// A SwiftUI color that follows the current light or dark appearance.
    public var color: Color {
        let light = light, dark = dark
        return Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let value = isDark ? dark : light
            return NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: 1)
        })
    }
}

public enum Palette {
    // Grounds.
    public static let canvas = PaletteRole(name: "coretend.canvas", light: RGB(hex: 0xE7EFE4), dark: RGB(hex: 0x0F2019))
    public static let sidebar = PaletteRole(name: "coretend.sidebar", light: RGB(hex: 0xDCE7D8), dark: RGB(hex: 0x0B1913))
    public static let surface = PaletteRole(name: "coretend.surface", light: RGB(hex: 0xF4F8F1), dark: RGB(hex: 0x14291F))
    public static let raisedSurface = PaletteRole(name: "coretend.raisedSurface", light: RGB(hex: 0xFFFFFF), dark: RGB(hex: 0x183126))
    /// Soil behind visualisations (roots, strata).
    public static let deep = PaletteRole(name: "coretend.deep", light: RGB(hex: 0xD3E0CF), dark: RGB(hex: 0x0A1510))
    public static let separator = PaletteRole(name: "coretend.separator", light: RGB(hex: 0xBFD0C1), dark: RGB(hex: 0x2C4A37))
    public static let strongSeparator = PaletteRole(name: "coretend.strongSeparator", light: RGB(hex: 0x65826D), dark: RGB(hex: 0x5F8A6C))

    // Ink and signals. Lowest ratio over the four grounds, light / dark:
    // ink 12.5 / 12.2, secondaryInk 6.9 / 8.5, tertiaryInk 4.9 / 5.0,
    // accent 4.9 / 9.0, caution 4.7 / 7.5, danger 4.7 / 5.5; onAccent on accent 5.8 / 11.7.
    public static let ink = PaletteRole(name: "coretend.ink", light: RGB(hex: 0x10261C), dark: RGB(hex: 0xEEF1E6))
    public static let secondaryInk = PaletteRole(name: "coretend.secondaryInk", light: RGB(hex: 0x35503F), dark: RGB(hex: 0xC3CDB9))
    public static let tertiaryInk = PaletteRole(name: "coretend.tertiaryInk", light: RGB(hex: 0x4F6557), dark: RGB(hex: 0x8FA088))
    public static let accent = PaletteRole(name: "coretend.accent", light: RGB(hex: 0x2C6E35), dark: RGB(hex: 0x9BE36D))
    public static let onAccent = PaletteRole(name: "coretend.onAccent", light: RGB(hex: 0xF4F8F1), dark: RGB(hex: 0x0B1913))
    public static let caution = PaletteRole(name: "coretend.caution", light: RGB(hex: 0x8A5A00), dark: RGB(hex: 0xE8B64A))
    public static let danger = PaletteRole(name: "coretend.danger", light: RGB(hex: 0xA9431C), dark: RGB(hex: 0xE98A63))
    public static let focus = PaletteRole(name: "coretend.focus", light: RGB(hex: 0x2C6E35), dark: RGB(hex: 0x9BE36D))
}
