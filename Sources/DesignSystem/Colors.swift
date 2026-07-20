import SwiftUI
import AppKit

/// Semantic palette — Orbital Ecology. Every color adapts to light/dark.
/// Chart/status colors are paired with symbols in the UI so color is never
/// the only channel (Differentiate Without Color).
public enum MCColor {
    /// Adaptive color helper (light, dark) in sRGB.
    private static func adaptive(_ name: String,
                                 light: (Double, Double, Double),
                                 dark: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
            let m = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = m ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }

    // Brand
    public static let coreMint = adaptive("coreMint",
        light: (0.043, 0.51, 0.46), dark: (0.30, 0.83, 0.75))
    public static let ionViolet = adaptive("ionViolet",
        light: (0.36, 0.33, 0.80), dark: (0.60, 0.57, 0.96))
    public static let solarAmber = adaptive("solarAmber",
        light: (0.72, 0.46, 0.07), dark: (0.95, 0.68, 0.26))
    public static let pulseCoral = adaptive("pulseCoral",
        light: (0.75, 0.25, 0.23), dark: (0.95, 0.47, 0.43))

    // Roles
    public static let storage = coreMint
    public static let protection = ionViolet
    public static let performance = solarAmber
    public static let destructive = pulseCoral
    public static let attention = solarAmber
    public static let success = adaptive("success",
        light: (0.10, 0.55, 0.30), dark: (0.35, 0.80, 0.50))

    /// Chart series order: storage, protection, performance, then neutrals.
    public static let chartSeries: [Color] = [storage, protection, performance, .secondary]
    public static let graphGrid = Color.secondary.opacity(0.15)

    // Surfaces — prefer system semantics for adaptivity.
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let elevatedBackground = Color(nsColor: .controlBackgroundColor)
    public static let separator = Color(nsColor: .separatorColor)
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary
}
