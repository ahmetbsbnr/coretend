import SwiftUI
import AppKit

/// Porcelain / Slate / Teal: one brand accent, functional caution and danger hues, neutral ink.
/// Values follow the retained CoreTend visual direction; contrast is enforced by `DesignSystemTests`.
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
    public static let canvas = PaletteRole(name: "coretend.canvas", light: RGB(hex: 0xF6F4EF), dark: RGB(hex: 0x16191E))
    public static let ink = PaletteRole(name: "coretend.ink", light: RGB(hex: 0x1B1E22), dark: RGB(hex: 0xECEBE4))
    public static let secondaryInk = PaletteRole(name: "coretend.graphite", light: RGB(hex: 0x4A535F), dark: RGB(hex: 0x7E8894))
    public static let accent = PaletteRole(name: "coretend.teal", light: RGB(hex: 0x0B6E6C), dark: RGB(hex: 0x5FD3C6))
    public static let onAccent = PaletteRole(name: "coretend.onTeal", light: RGB(hex: 0xF6F4EF), dark: RGB(hex: 0x16191E))
    public static let caution = PaletteRole(name: "coretend.amber", light: RGB(hex: 0x8A5A12), dark: RGB(hex: 0xF4C76B))
    public static let danger = PaletteRole(name: "coretend.coral", light: RGB(hex: 0xB83C33), dark: RGB(hex: 0xF08A7E))
}
