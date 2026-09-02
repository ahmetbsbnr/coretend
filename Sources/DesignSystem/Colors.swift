import SwiftUI
import AppKit

/// Semantic palette — **Porcelain / Slate / Teal**, CoreTend's own identity:
/// a warm porcelain-and-slate neutral base with a single oceanic-teal accent,
/// not a multi-hue system.
///
/// Colour carries meaning on one axis only:
///
/// | Colour | Means |
/// |--------|-------|
/// | teal   | the brand accent — storage, protection, every primary action |
/// | amber  | caution — a functional warning colour, not brand |
/// | coral  | error, or an action that cannot be undone |
///
/// Storage/protection/performance do not each get their own hue: a calm
/// one-accent system can't spend teal three different ways and still read as
/// "one colour", so those roles are told apart by icon and label instead
/// (Differentiate Without Color).
///
/// ## Why teal needs two tuned values, not one
///
/// The brand teal (`#0B6E6C`) is tuned for **Porcelain**: ~5.0:1 there, over
/// the 4.5:1 text minimum. On the dark **Slate** canvas it drops well below
/// 3:1. Teal is light-tuned and needs a *brightened* dark sibling
/// (`#5FD3C6`, ~9:1 on Slate) rather than a darkened one. Name the sibling;
/// don't leave it for someone to rediscover in a contrast checker.
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

    /// The canonical Porcelain/Slate/Teal palette. Referenced by the asset
    /// generator (`Scripts/export-design-tokens.py`) and the website's tokens
    /// so there is one source of truth for the hex values.
    ///
    /// The public symbol names below (`cobalt`, `cobaltBright`, …) are kept
    /// deliberately stable across the identity change so the generated
    /// `--ct-*` CSS custom properties the website consumes don't have to be
    /// renamed in lockstep. The *values* are the identity; the names are just
    /// slots. Renaming the slots to `teal*` is a tracked follow-up.
    public enum Canonical {
        /// `#1B1E22` — the dark surface. Warm slate, not pure grey.
        public static let ink = (0.1059, 0.1176, 0.1333)
        /// `#F6F4EF` — the light surface. Warm porcelain.
        public static let paper = (0.9647, 0.9569, 0.9373)
        /// `#0B6E6C` — the one brand accent. Light-tuned: ~5.0:1 on
        /// Porcelain, below 3:1 on Slate (see `cobaltBright`).
        public static let cobalt = (0.0431, 0.4314, 0.4235)
        /// `#08514F` — hover/pressed on Porcelain, and a deeper tonal step
        /// where the treemap needs a second, darker teal swatch.
        public static let cobaltDeep = (0.0314, 0.3176, 0.3098)
        /// `#5FD3C6` — the Slate-surface sibling of `cobalt`. ~9:1 on Slate,
        /// where canonical teal itself falls below 3:1.
        public static let cobaltBright = (0.3725, 0.8275, 0.7765)
        /// `#2E9E93` / `#A7E6DE` — two more tonal steps of the same hue, for
        /// the Space Lens treemap only: it needs several distinguishable
        /// swatches at once, which the three UI tones above don't provide.
        public static let cobaltMid = (0.1804, 0.6196, 0.5765)
        public static let cobaltBrightest = (0.6549, 0.9020, 0.8706)
        /// `#063F3D` — deepest tonal step, Porcelain-surface only.
        public static let cobaltDeepest = (0.0235, 0.2471, 0.2392)
        /// `#F4C76B` — caution, functional not brand. Native macOS uses
        /// orange for warnings everywhere (Finder, Disk Utility), and it
        /// doesn't compete with a single-hue brand accent the way a second
        /// saturated brand colour would.
        public static let warmAmber = (0.9569, 0.7804, 0.4196)
        /// `#F08A7E` — error, or an action that cannot be undone. Slate-tuned
        /// sibling of `coralDeep`.
        public static let signalCoral = (0.9412, 0.5412, 0.4941)
        /// `#7E8894` — secondary text and inert UI on Slate; also the app's
        /// secondary accent — a graphite tone rather than a second hue.
        public static let mutedSlate = (0.4941, 0.5333, 0.5804)

        /// Light-mode siblings, darkened to clear 4.5:1 against Porcelain.
        /// Amber is the hardest hue to darken without turning brown, so this
        /// sits just past the 4.5:1 line rather than comfortably beyond it.
        public static let amberDeep = (0.5412, 0.3529, 0.0706)
        public static let coralDeep = (0.72, 0.235, 0.20)
        public static let slateDeep = (0.2902, 0.3255, 0.3725)
    }

    // Brand — the one accent. Light surfaces use the light-tuned teal
    // directly; Slate uses the brightened sibling instead of a darkened one,
    // per the header note above.
    public static let teal = adaptive("teal",
        light: Canonical.cobalt, dark: Canonical.cobaltBright)
    /// Secondary accent — a graphite tone, not a second brand hue. Used
    /// where a UI moment needs to read as "not the primary action" (e.g. an
    /// "approved" log entry, a "scan" activity icon) without introducing a
    /// colour that would compete with teal for "the brand colour" status.
    public static let graphite = adaptive("graphite",
        light: Canonical.slateDeep, dark: Canonical.mutedSlate)
    public static let amber = adaptive("amber",
        light: Canonical.amberDeep, dark: Canonical.warmAmber)
    public static let coral = adaptive("coral",
        light: Canonical.coralDeep, dark: Canonical.signalCoral)

    // Roles
    public static let storage = teal
    public static let protection = graphite
    public static let performance = amber
    public static let destructive = coral
    public static let attention = amber
    public static let success = adaptive("success",
        light: (0.04, 0.45, 0.34), dark: (0.36, 0.82, 0.66))

    /// Chart series order: storage, protection, performance, then neutrals.
    public static let chartSeries: [Color] = [storage, protection, performance, .secondary]
    public static let graphGrid = Color.secondary.opacity(0.15)

    // File-type category colors (Space Lens treemap). Tonal steps of teal
    // plus the existing graphite/amber neutrals, rather than a second and
    // third brand hue — six categories still read as distinct swatches, but
    // the family stays "teal + neutrals", not a rainbow.
    public static let cellTealDeep = adaptive("cellTealDeep",
        light: Canonical.cobaltDeep, dark: Canonical.cobaltMid)
    public static let cellGraphite = adaptive("cellGraphite",
        light: Canonical.slateDeep, dark: Canonical.mutedSlate)
    public static let cellTealPale = adaptive("cellTealPale",
        light: Canonical.cobaltDeepest, dark: Canonical.cobaltBrightest)

    // Surfaces. Porcelain/Slate axis, adapting to the user's light/dark
    // appearance.
    public static let background = adaptive("background",
        light: Canonical.paper, dark: Canonical.ink)
    // Dark elevated surface sits a clear ~3 L* steps above Slate so cards
    // read as raised, not as the same flat field. Light stays near-white.
    public static let elevatedBackground = adaptive("elevatedBackground",
        light: (1.0, 0.996, 0.988), dark: (0.1725, 0.1922, 0.2157))
    public static let secondaryBackground = adaptive("secondaryBackground",
        light: (0.9255, 0.9098, 0.8784), dark: (0.0784, 0.0863, 0.0980))
    public static let separator = adaptive("separator",
        light: (0.84, 0.82, 0.78), dark: (0.27, 0.29, 0.32))
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary
}
