// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

/// Semantic text styles. San Francisco only; identity comes from rhythm,
/// weight contrast and rounded numerics — not from an external font.
///
/// ## Why this list grew
///
/// It used to hold ten styles, and views bypassed it anyway: `.font(.caption)`
/// appeared 56 times — more than any token here was used — alongside 15 uses of
/// `.caption2` at three different weights, and twelve bare `.system(size: N)`
/// literals (9, 12, 13, 14, 15, 28, 30, 34). 92 uses of the system against
/// roughly 110 that went around it.
///
/// That is not a discipline problem. A token set that does not name the styles
/// a codebase actually needs will be bypassed, and each bypass is a decision
/// nobody can find later. The set below covers what the app was already doing,
/// named for what the text *is* rather than how big it is.
///
/// Sizes are Dynamic Type styles wherever possible, so text scales with the
/// user's setting. The fixed-point exceptions are labelled and are places where
/// scaling would break a fixed-size container.
public enum MCFont {
    // MARK: Display and headings

    /// The one number a screen exists to show: recoverable bytes, free space.
    public static let displayMetric = Font.system(size: 40, weight: .semibold, design: .rounded)
    public static let heroTitle = Font.system(size: 28, weight: .bold)
    /// Module landing headings. Bold, not semibold: it needs a clear step above
    /// `cardTitle` so the hierarchy reads at a glance.
    public static let pageTitle = Font.title2.weight(.bold)
    public static let sectionTitle = Font.subheadline.weight(.semibold)
    public static let cardTitle = Font.headline

    // MARK: Body

    public static let body = Font.body
    public static let secondaryBody = Font.callout
    /// A row's primary line — a file name, an app name. Medium rather than
    /// semibold: it must lead its row without competing with a card title.
    public static let rowTitle = Font.callout.weight(.medium)

    // MARK: Supporting text
    //
    // Two tiers, not three. `caption` is supporting text someone is expected to
    // read; `micro` is a label attached to something else — a unit, a badge, a
    // timestamp — that is scanned rather than read.

    public static let caption = Font.caption
    public static let captionEmphasis = Font.caption.weight(.medium)
    public static let micro = Font.caption2
    public static let microEmphasis = Font.caption2.weight(.medium)
    public static let badge = Font.caption2.weight(.semibold)

    // MARK: Numeric and monospaced
    //
    // Rounded digits for values that change in place, so the text does not
    // jitter as it animates. Monospaced where columns must line up or where the
    // content is literal — a checksum, a key combination, a path.

    public static let metric = Font.system(.title3, design: .rounded).weight(.semibold)
    public static let monoBody = Font.system(.body, design: .monospaced)
    public static let monoCaption = Font.system(.callout, design: .monospaced)

    // MARK: Controls

    /// The label of a screen's primary action.
    public static let actionLabel = Font.title3.weight(.semibold)

    /// A group heading inside content — a section of a list, a cluster of
    /// related rows. Small, tracked and uppercased at the call site, like the
    /// sidebar's, but fixed: it is not a sidebar and must not follow the
    /// sidebar size setting.
    public static let groupHeader = Font.system(size: 11, weight: .semibold)

    // MARK: Navigation
    //
    // The sidebar has its own three styles because it is read at a glance
    // rather than read properly. Section labels are small, tracked and
    // uppercased so they register as structure and not as items; the active
    // item steps up in weight rather than in size, so row height never changes
    // as selection moves and the list does not twitch.
    //
    // Fixed point sizes, deliberately: the sidebar column has a fixed width and
    // scaling these would clip it rather than reflow.

    // Functions rather than constants: these follow the user's sidebar icon
    // size from System Settings ▸ Appearance, which a standard `List` picks up
    // for free and a hand-built sidebar has to ask for. See MCSidebarMetrics.
    public static func sidebarSection(_ size: MCSidebarMetrics.Size) -> Font {
        .system(size: size.sectionSize, weight: .semibold)
    }

    /// The active item steps up in *weight*, never in size, so row height does
    /// not change as selection moves and the list does not twitch.
    public static func sidebarItem(_ size: MCSidebarMetrics.Size, active: Bool) -> Font {
        .system(size: size.textSize, weight: active ? .semibold : .regular)
    }
}

/// Icon glyph point sizes, for `Image(systemName:).font(.system(size:))`.
///
/// These were eleven bare numeric literals across seven files — 9, 12, 13, 14,
/// 15, 28, 30, 34 — which is not eight deliberate sizes but three or four with
/// several of them differing by a point because one was typed from memory.
/// 13, 14 and 15 all became `row`: at that scale the difference is invisible
/// and the inconsistency is not.
///
/// Named by the role the glyph plays, so the size follows from what the icon is
/// doing rather than from what looked right in one view.
public enum MCIconSize {
    /// The single glyph a full-screen success or empty state is built around.
    public static let emptyStateProminent: CGFloat = 56
    /// Secondary empty/error/success-state glyph.
    public static let emptyState: CGFloat = 48
    /// Inside the shared `MCEmptyState`, which nests in other content rather
    /// than filling a module screen.
    public static let compactState: CGFloat = 40
    /// A moment of completion — the seal on a finished run.
    public static let hero: CGFloat = 34
    /// The glyph at the centre of a feature: a progress ring, a step header.
    public static let feature: CGFloat = 30
    /// A card's identifying icon.
    public static let card: CGFloat = 28
    /// Anything sitting in a row: sidebar items, status glyphs, small actions.
    public static let row: CGFloat = 14
    /// Directional affordances — the arrow that says "this opens something".
    public static let chevron: CGFloat = 12
    /// Small inline status dot (lock/cloud indicators on list rows).
    public static let inline: CGFloat = 8
}
