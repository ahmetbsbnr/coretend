import SwiftUI
import AppKit

/// Semantic palette — **Paper / Ink / Cobalt**, the same editorial identity
/// as the portfolio (`ahmetbsbnr-portfolio/app/globals.css`): a paper-and-ink
/// neutral base with a single cobalt-blue accent, not a multi-hue system.
///
/// Colour carries meaning on one axis only:
///
/// | Colour | Means |
/// |--------|-------|
/// | cobalt | the brand accent — storage, protection, every primary action |
/// | amber  | caution — a functional warning colour, not brand |
/// | coral  | error, or an action that cannot be undone |
///
/// Storage/protection/performance no longer get their own hue: an editorial
/// one-accent system can't spend cobalt three different ways and still read
/// as "one colour", so those roles are told apart by icon and label instead
/// (Differentiate Without Color) — the same principle the old palette
/// already followed, just with fewer hues available to lean on.
///
/// ## Why cobalt needs two tuned values, not one
///
/// The published brand blue (`#2240E2`) is tuned for **Paper**: 6.6:1 there,
/// comfortably over the 4.5:1 text minimum. On **Ink** it drops to 2.4:1 —
/// this is the inverse of the old mint/violet palette, where the canonical
/// value was dark-tuned and needed a *deepened* light sibling. Cobalt is
/// light-tuned and needs a *brightened* dark sibling instead. Both directions
/// get the same treatment: name the sibling, don't leave it for someone to
/// rediscover in a contrast checker.
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

    /// The canonical Paper/Ink/Cobalt palette. Referenced by the asset
    /// generator and the website's tokens so there is one source of truth
    /// for the hex values, and matched byte-for-byte to the portfolio's
    /// `--paper`/`--ink`/`--cobalt` tokens so the two never drift apart.
    public enum Canonical {
        /// `#17191D` — the dark surface. Matches portfolio `--ink`.
        public static let ink = (0.0902, 0.0980, 0.1137)
        /// `#F4F4F0` — the light surface. Matches portfolio `--paper`.
        public static let paper = (0.9569, 0.9569, 0.9412)
        /// `#2240E2` — the one brand accent. Matches portfolio `--cobalt`.
        /// Light-tuned: 6.6:1 on Paper, 2.4:1 on Ink (see `cobaltBright`).
        public static let cobalt = (0.1333, 0.2510, 0.8863)
        /// `#182FB2` — hover/pressed on Paper, and a deep tonal step where
        /// the treemap needs a second, darker cobalt swatch. Matches
        /// portfolio `--cobalt-deep`.
        public static let cobaltDeep = (0.0941, 0.1843, 0.6980)
        /// `#8E9EF0` — the Ink-surface sibling of `cobalt`. 7.0:1 on Ink,
        /// where canonical cobalt itself falls to 2.4:1.
        public static let cobaltBright = (0.5569, 0.6196, 0.9412)
        /// `#6177EA` / `#B2BDF5` — two more tonal steps of the same hue, for
        /// the Space Lens treemap only: it needs several distinguishable
        /// swatches at once, which the three UI tones above don't provide
        /// on their own.
        public static let cobaltMid = (0.3804, 0.4667, 0.9176)
        public static let cobaltBrightest = (0.6991, 0.7399, 0.9605)
        /// `#162DA7` — deepest tonal step, Paper-surface only (2.4:1 on
        /// Ink, same problem as canonical cobalt, only worse).
        public static let cobaltDeepest = (0.0863, 0.1765, 0.6549)
        /// `#F4C76B` — caution, functional not brand. Unchanged by the
        /// re-skin: native macOS uses orange for warnings everywhere
        /// (Finder, Disk Utility), and it doesn't compete with a single-hue
        /// brand accent the way a second saturated brand colour would.
        public static let warmAmber = (0.957, 0.780, 0.420)
        /// `#F47F78` — error, or an action that cannot be undone. Unchanged
        /// for the same reason as `warmAmber`.
        public static let signalCoral = (0.957, 0.498, 0.471)
        /// `#77818E` — secondary text, inert UI, and (below) the app's
        /// secondary accent — a graphite tone rather than a second hue.
        public static let mutedSlate = (0.467, 0.506, 0.557)

        /// Light-mode siblings, darkened to clear 4.5:1 against Paper.
        /// Amber and coral are unchanged from the pre-re-skin palette.
        /// Amber is the hardest hue to darken without turning brown, so this
        /// sits only just past the 4.5:1 line rather than comfortably beyond
        /// it. The previous value looked right and measured 4.1:1.
        public static let amberDeep = (0.580, 0.375, 0.040)
        public static let coralDeep = (0.720, 0.220, 0.200)
        public static let slateDeep = (0.310, 0.345, 0.392)
    }

    // Brand — the one accent. Light surfaces use the published brand value
    // directly (it already clears contrast there); Ink uses the brightened
    // sibling instead of a darkened one, per the header note above.
    public static let coreMint = adaptive("coreMint",
        light: Canonical.cobalt, dark: Canonical.cobaltBright)
    /// Secondary accent — a graphite tone, not a second brand hue. Used
    /// where a UI moment needs to read as "not the primary action" (e.g. an
    /// "approved" log entry, a "scan" activity icon) without introducing a
    /// colour that would compete with cobalt for "the brand colour" status.
    public static let ionViolet = adaptive("ionViolet",
        light: Canonical.slateDeep, dark: Canonical.mutedSlate)
    public static let solarAmber = adaptive("solarAmber",
        light: Canonical.amberDeep, dark: Canonical.warmAmber)
    public static let pulseCoral = adaptive("pulseCoral",
        light: Canonical.coralDeep, dark: Canonical.signalCoral)

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

    // File-type category colors (Space Lens treemap). Tonal steps of cobalt
    // plus the existing graphite/amber neutrals, rather than a second and
    // third brand hue — six categories still read as distinct swatches, but
    // the family stays "cobalt + neutrals", not a rainbow.
    public static let novaMagenta = adaptive("novaMagenta",
        light: Canonical.cobaltDeep, dark: Canonical.cobaltMid)
    public static let glacierBlue = adaptive("glacierBlue",
        light: Canonical.slateDeep, dark: Canonical.mutedSlate)
    public static let mossGreen = adaptive("mossGreen",
        light: Canonical.cobaltDeepest, dark: Canonical.cobaltBrightest)

    // Surfaces. These stay on the same Paper/Ink axis as the website and
    // portfolio while still adapting to the user's light/dark appearance.
    public static let background = adaptive("background",
        light: Canonical.paper, dark: Canonical.ink)
    public static let elevatedBackground = adaptive("elevatedBackground",
        light: (0.988, 0.988, 0.976), dark: (0.125, 0.133, 0.153))
    public static let secondaryBackground = adaptive("secondaryBackground",
        light: (0.925, 0.925, 0.902), dark: (0.078, 0.086, 0.102))
    public static let separator = adaptive("separator",
        light: (0.82, 0.82, 0.78), dark: (0.28, 0.30, 0.34))
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary
}
