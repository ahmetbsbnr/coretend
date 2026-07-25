import SwiftUI
import AppKit

/// Semantic palette — **Living System**, built on the Orbital Ecology
/// foundations (Core Bloom nucleus, three arcs, functional colour roles).
///
/// Colour carries meaning here, and always on a single axis:
///
/// | Hue    | Means |
/// |--------|-------|
/// | green  | storage and care |
/// | violet | privacy and protection |
/// | amber  | activity and performance |
/// | coral  | error or a critical action |
///
/// Every colour adapts to light/dark, and every chart or status colour is
/// paired with a symbol in the UI so colour is never the only channel
/// (Differentiate Without Color).
///
/// ## Why the light variants are not the published hex values
///
/// `LivingSystem` below holds the brand's canonical hex values. Those are
/// tuned for a dark surface (Core Ink) and several of them — Fresh Mint
/// especially — fall well under 4.5:1 against a near-white surface. Shipping
/// them unchanged in light mode would mean unreadable text on half the
/// installs, so light mode uses darkened siblings of the same hue.
///
/// That is a deliberate divergence, not drift: the brand value is the
/// reference, the light value is what keeps it legible, and both are named
/// here rather than left for someone to rediscover in a contrast checker.
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

    /// The canonical Living System palette, exactly as published in the brand
    /// documentation. Referenced by the asset generator and the website's
    /// tokens so there is one source of truth for the hex values.
    public enum LivingSystem {
        /// `#0B0F14` — the dark surface everything else is tuned against.
        public static let coreInk = (0.043, 0.059, 0.078)
        /// `#F4F6F3` — the light surface.
        public static let softPorcelain = (0.957, 0.965, 0.953)
        /// `#74A487` — mid green, usable as a fill on either surface.
        public static let livingMoss = (0.455, 0.643, 0.529)
        /// `#A8E6C1` — the accent green. Dark-surface only for text.
        public static let freshMint = (0.659, 0.902, 0.757)
        /// `#9B8AFB` — privacy and protection.
        public static let orbitIris = (0.608, 0.541, 0.984)
        /// `#F4C76B` — activity and performance.
        public static let warmAmber = (0.957, 0.780, 0.420)
        /// `#F47F78` — error, or an action that cannot be undone.
        public static let signalCoral = (0.957, 0.498, 0.471)
        /// `#77818E` — secondary text and inert UI.
        public static let mutedSlate = (0.467, 0.506, 0.557)

        /// Light-mode siblings, darkened to clear 4.5:1 against Soft
        /// Porcelain. Same hue family, different luminance.
        public static let mossDeep = (0.075, 0.404, 0.290)
        public static let irisDeep = (0.360, 0.330, 0.800)
        /// Amber is the hardest hue to darken without turning brown, so this
        /// sits only just past the 4.5:1 line rather than comfortably beyond
        /// it. The previous value looked right and measured 4.1:1.
        public static let amberDeep = (0.580, 0.375, 0.040)
        public static let coralDeep = (0.720, 0.220, 0.200)
        public static let slateDeep = (0.310, 0.345, 0.392)
    }

    // Brand — light: accessible sibling, dark: canonical Living System value.
    public static let coreMint = adaptive("coreMint",
        light: LivingSystem.mossDeep, dark: LivingSystem.freshMint)
    public static let ionViolet = adaptive("ionViolet",
        light: LivingSystem.irisDeep, dark: LivingSystem.orbitIris)
    public static let solarAmber = adaptive("solarAmber",
        light: LivingSystem.amberDeep, dark: LivingSystem.warmAmber)
    public static let pulseCoral = adaptive("pulseCoral",
        light: LivingSystem.coralDeep, dark: LivingSystem.signalCoral)
    /// Mid green — the one Living System hue that works as a fill on either
    /// surface, so it is not split into light/dark siblings.
    public static let livingMoss = adaptive("livingMoss",
        light: (0.365, 0.553, 0.439), dark: LivingSystem.livingMoss)

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

    // File-type category colors (Space Lens treemap). A distinct hue family
    // from the app-level storage/protection/performance roles above — this
    // is a different semantic axis (file type within storage), so reusing
    // e.g. `storage` here would be a false equivalence, not a simplification.
    public static let novaMagenta = adaptive("novaMagenta",
        light: (0.70, 0.40, 0.70), dark: (0.90, 0.62, 0.90))
    public static let glacierBlue = adaptive("glacierBlue",
        light: (0.30, 0.60, 0.82), dark: (0.55, 0.80, 0.95))
    public static let mossGreen = adaptive("mossGreen",
        light: (0.48, 0.62, 0.28), dark: (0.68, 0.82, 0.52))

    // Surfaces — prefer system semantics for adaptivity. The Living System
    // surface values exist for the website and generated assets, where there
    // is no AppKit to ask; inside the app, matching the user's actual system
    // appearance beats matching a brand swatch.
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let elevatedBackground = Color(nsColor: .controlBackgroundColor)
    public static let separator = Color(nsColor: .separatorColor)
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary
}
