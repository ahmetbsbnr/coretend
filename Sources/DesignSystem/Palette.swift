import SwiftUI
import AppKit

/// Observatoire colors: slate surfaces, mineral cyan actions, copper caution, coral danger.
/// Text and signal roles meet 4.5:1 against canvas and both surfaces in each appearance.
/// Separator is a decorative boundary; focus provides the visible control outline.
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
    // Light: mist canvas / white panels. Dark: deep slate / progressively raised panels.
    // Surface/canvas contrast: 1.09 light, 1.05 dark. Raised/surface: 1.04 light, 1.14 dark.
    // Separator/surface: 1.32 light, 1.47 dark; it does not carry meaning alone.
    public static let canvas = PaletteRole(name: "coretend.canvas", light: RGB(hex: 0xEDF0F4), dark: RGB(hex: 0x18263A))
    public static let surface = PaletteRole(name: "coretend.surface", light: RGB(hex: 0xF9FAFC), dark: RGB(hex: 0x1D2A3C))
    public static let raisedSurface = PaletteRole(name: "coretend.raisedSurface", light: RGB(hex: 0xFFFFFF), dark: RGB(hex: 0x253348))
    public static let separator = PaletteRole(name: "coretend.separator", light: RGB(hex: 0xD5DCE5), dark: RGB(hex: 0x35445A))

    // Minimum contrast on canvas / surface / raisedSurface respectively:
    // ink 13.33 / 14.59 / 15.24 (light), 13.56 / 12.89 / 11.35 (dark)
    // secondaryInk 4.72 / 5.17 / 5.40 (light), 7.42 / 7.05 / 6.21 (dark)
    // accent 5.35 / 5.86 / 6.12 (light), 7.91 / 7.52 / 6.62 (dark)
    // caution 4.86 / 5.32 / 5.56 (light), 6.88 / 6.54 / 5.75 (dark)
    // danger 4.92 / 5.39 / 5.63 (light), 6.27 / 5.97 / 5.25 (dark)
    public static let ink = PaletteRole(name: "coretend.ink", light: RGB(hex: 0x1A2638), dark: RGB(hex: 0xEFF2F4))
    public static let secondaryInk = PaletteRole(name: "coretend.secondaryInk", light: RGB(hex: 0x5F6B7E), dark: RGB(hex: 0xABB6C4))
    public static let accent = PaletteRole(name: "coretend.accent", light: RGB(hex: 0x176C74), dark: RGB(hex: 0x77C9C0))
    public static let onAccent = PaletteRole(name: "coretend.onAccent", light: RGB(hex: 0xFFFFFF), dark: RGB(hex: 0x18263A))
    public static let caution = PaletteRole(name: "coretend.caution", light: RGB(hex: 0x9A5731), dark: RGB(hex: 0xE1A071))
    public static let danger = PaletteRole(name: "coretend.danger", light: RGB(hex: 0xB83C33), dark: RGB(hex: 0xF08A7E))
    public static let focus = PaletteRole(name: "coretend.focus", light: RGB(hex: 0x176C74), dark: RGB(hex: 0x77C9C0))
    // onAccent/accent: 6.12 light, 7.91 dark. Focus/raisedSurface: 6.12 light, 6.62 dark.
}
