// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

// MARK: - Porcelain / Slate / Teal design tokens

/// Spacing scale (pt). Views compose from these; no arbitrary values.
public enum MCSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    /// Standard page padding for module screens.
    public static let page: CGFloat = 24
    /// Inside a control or a dense row, where the 4pt grid's smallest step is
    /// still too much: a treemap cell's label, a row that has to fit in 28pt.
    public static let tight: CGFloat = 5
}

public enum MCRadius {
    public static let small: CGFloat = 6
    public static let card: CGFloat = 8
    public static let hero: CGFloat = 12
    public static let capsule: CGFloat = 999
}

public enum MCSize {
    public static let sidebarMin: CGFloat = 190
    public static let sidebarIdeal: CGFloat = 220
    /// Capped so a dragged divider cannot turn the sidebar into half the
    /// window on a wide display.
    public static let sidebarMax: CGFloat = 320
    /// Sidebar minimum (190) plus what the Dashboard hero genuinely needs
    /// (ring, copy column, and a 40pt metric side by side ≈ 690), plus room
    /// rather than exactly enough. At 860 the two minimums did not both fit and
    /// the split view resolved it by starving the sidebar until its contents
    /// overflowed and clipped.
    public static let windowMinWidth: CGFloat = 1000
    public static let windowMinHeight: CGFloat = 580
    /// What the window opens at on a first launch. Wide enough that the
    /// Dashboard's three-column hero and the sidebar both have room, so the
    /// first thing a new user sees is the layout as designed rather than its
    /// compressed form.
    public static let windowDefaultWidth: CGFloat = 1180
    public static let windowDefaultHeight: CGFloat = 800
    public static let metricRing: CGFloat = 76
    /// A live curve's height.
    ///
    /// Was 140. Measured on a capture, two curves at that height plus their
    /// labels pushed Performance's scan history — the section that makes this
    /// module temporal rather than a status readout — below the fold, and left
    /// 38% of the detail column flat. A curve does not need 140 points to show
    /// its shape.
    public static let chartHeight: CGFloat = 104
    /// The widest a column of prose or summary rows may get.
    ///
    /// A large window is not a reason to stretch a sentence to 1400pt: the
    /// eye loses the line. Screens whose content is reading material cap at
    /// this and keep the extra space as margin; screens whose content is a
    /// table or a map use the whole width, because there the extra width
    /// genuinely shows more.
    public static let readableWidth: CGFloat = 820
}

/// Motion, named by what it is for.
///
/// ## Why the previous version was not a system
///
/// It offered `quick`/`standard`/`gentle` (three raw `Double`s nothing used)
/// and two springs. Views then wrote their own: `.smooth(duration: 0.4)`,
/// `.smooth(0.45)`, `.smooth(0.3)`, `.easeOut(0.9)`, `.easeOut(0.6)`,
/// `.easeOut(0.35)`, `.easeOut(0.18)`, `.spring(0.45, 0.62)`. Eight durations
/// and four curve families across seventeen call sites — not a motion system,
/// eight separate opinions, and no way to change the app's feel without
/// finding all of them.
///
/// The tokens below are named for the *reason* something moves, so a call site
/// picks by intent and two screens doing the same kind of thing cannot drift
/// apart. Four is enough; a fifth would be a duration looking for a purpose.
///
/// ## Reduce Motion
///
/// The old doc comment claimed `MCMotion.animation(_:reduce:)` was "one choke
/// point". It was used at five of seventeen call sites; the rest wrote
/// `reduceMotion ? nil : …` by hand, or forgot. A choke point that must be
/// remembered is not a choke point.
///
/// `.mcAnimation(_:value:)` reads the environment itself, so honouring the
/// setting is no longer something a call site can omit.
public enum MCMotion {
    /// Content arriving: a card, a row, a result appearing for the first time.
    ///
    /// Was 0.4 s with a `smooth` curve, and both were wrong for how it is
    /// actually used. Every one of its four call sites fires because the user
    /// did something — opened a module, finished a cleanup — and the rule for
    /// user-triggered motion is ease-out under 300 ms. `smooth` is roughly
    /// ease-in-out, so the motion started slowly *after* the click, which is
    /// the specific thing that reads as sluggish. 280 ms ease-out.
    /// Shortened from 0.28. A reveal that takes a third of a second reads as
    /// a transition being performed for the viewer; at 0.18 it reads as the
    /// interface having already responded. Nothing in this app is a
    /// spectacle — motion exists to say what changed, then get out of the way.
    public static let reveal = Animation.easeOut(duration: 0.18)

    /// One state becoming another: a phase change, a tab swap, a filter
    /// applying. Faster than `reveal` because nothing new is being introduced.
    public static let transition = Animation.easeOut(duration: 0.16)

    /// Direct response to a pointer or key: hover, press, selection. Must feel
    /// attached to the input, so it is the shortest thing here.
    public static let response = Animation.easeOut(duration: 0.11)

    /// Motion that reports nothing and gates nothing — the glow that blooms
    /// behind a completed cleanup. The one place where taking time is the
    /// point, and the only token allowed past 300 ms.
    ///
    /// Separate from `reveal` precisely so that "this is decorative" has to be
    /// said out loud at the call site. A single token used for both is how a
    /// decorative duration ends up gating a result.
    public static let ambient = Animation.easeOut(duration: 0.5)

    /// Something settling into place under its own weight: a zoom, a treemap
    /// rearranging, a value animating to a new number. The only spring, because
    /// a spring says "physical" and almost nothing here is.
    /// Higher damping, shorter response: a spring that visibly oscillates is
    /// a bounce, and a bounce is decoration.
    public static let settle = Animation.spring(response: 0.32, dampingFraction: 0.95)

    /// Kept for the two call sites that pass an animation around rather than
    /// applying it. New code should use `.mcAnimation(_:value:)`.
    public static let snappy = response

    /// Returns `nil` (no animation) when Reduce Motion is on.
    ///
    /// Prefer `.mcAnimation(_:value:)`, which cannot be forgotten.
    public static func animation(_ base: Animation, reduce: Bool) -> Animation? {
        reduce ? nil : base
    }

    /// Stagger between siblings in a revealing group.
    ///
    /// Capped deliberately: an ungated `index * delay` turns a list of forty
    /// into a four-second wait for the last row. Past the cap everything
    /// arrives together, which is the correct answer for "too many to stagger".
    public static func stagger(index: Int, step: Double = 0.06, cap: Double = 0.36) -> Double {
        min(Double(index) * step, cap)
    }
}

public extension View {
    /// Animates `value` changes, honouring Reduce Motion without the call site
    /// having to remember to.
    func mcAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MCAnimationModifier(animation: animation, value: value))
    }
}

private struct MCAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// The only opacities the app uses, each with a reason.
///
/// Views carried ten ad-hoc values between them — 0.16 here, 0.18 there, 0.35,
/// 0.55, 0.85 — none measured and none reused deliberately. A number nobody
/// can name is a number nobody checked.
///
/// Status pills are deliberately absent: tinting a label with its own colour
/// at any usable opacity fails the text minimum (worst pairing 3.67:1, and the
/// opacity that would fix it is 0.05, which is not a pill). `MCStatusTag` uses
/// a solid fill instead.
public enum MCOpacity {
    /// Track ring behind a determinate progress arc (Core Bloom, metric rings).
    public static let orbitTrack: Double = 0.14
    /// Selection wash behind a sidebar row, over the user's accent. Measured
    /// with the label on top across all seven system accents — see
    /// `SidebarAccentTests`.
    public static let selectionWash: Double = 0.18
    /// A chart's area under its line: enough to read as volume, faint enough
    /// not to compete with the line.
    public static let chartArea: Double = 0.18
    /// A secondary figure on a filled surface, where full strength would fight
    /// the primary label beside it.
    public static let onFillSecondary: Double = 0.85
    /// A hairline that separates without drawing a line the eye stops on.
    public static let hairline: Double = 0.55
    /// A shade over a cell whose contents could not be read, so it reads as
    /// unavailable rather than as dark-coloured data.
    public static let unavailableOverlay: Double = 0.35
    /// Hover on a navigation row, over the user's accent. Faint enough that a
    /// pointer moving down the sidebar does not look like six selections; the
    /// opaque surface it replaced made hover as loud as selection.
    /// Hover says "this responds", nothing more. Applied as a neutral ink
    /// wash rather than an accent tint, so hovering a row never looks like a
    /// second, weaker selection.
    public static let hoverWash: Double = 0.055
    /// Selection wash under Increase Contrast. Someone who turned that setting
    /// on has said a faint tint is not enough of a boundary for them, and a
    /// pale wash of a light accent is exactly that. Paired with a stroke.
    public static let selectionWashHighContrast: Double = 0.34
}

/// Semantic colour aliases. Views reference these role names (`accent`,
/// `warning`, …) rather than raw `MCColor` hues, so a palette change is one
/// edit here. Layout values live in `MCRadius` / `MCSpacing` / `MCSize`.
public enum MCTheme {
    public static let accent = MCColor.teal
    public static let accentSecondary = MCColor.graphite
    public static let warning = MCColor.amber
    public static let danger = MCColor.coral
    public static let success = MCColor.success
}
