// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import SwiftUI
import AppKit
@testable import DesignSystem

@Suite("Design tokens")
struct TokenTests {
    @Test func spacingScaleIsMonotonic() {
        let scale: [CGFloat] = [MCSpacing.xxs, MCSpacing.xs, MCSpacing.sm,
                                MCSpacing.md, MCSpacing.lg, MCSpacing.xl, MCSpacing.xxl]
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
    }

    @Test func radiiAreOrdered() {
        #expect(MCRadius.small < MCRadius.card)
        #expect(MCRadius.card < MCRadius.hero)
    }

    // `quick`/`standard`/`gentle` were three bare Doubles that no view ever
    // read, while seventeen call sites wrote their own curves. The replacement
    // tokens are named by intent and are covered by MotionSystemTests below.
}

@Suite("Bloom geometry")
struct BloomGeometryTests {
    @Test func threeAsymmetricArcs() {
        #expect(MCBloomGeometry.arcs.count == 3)
        let spans = MCBloomGeometry.arcs.map(\.1)
        #expect(Set(spans).count == 3) // asymmetry: no two spans equal
        let radii = MCBloomGeometry.arcs.map(\.2)
        #expect(radii == radii.sorted(by: >)) // outer → inner
        #expect(radii.allSatisfy { $0 > MCBloomGeometry.nucleusFraction })
    }

    @Test func arcSpansStayPartial() {
        // Arcs must remain arcs, never full circles.
        #expect(MCBloomGeometry.arcs.allSatisfy { $0.1 > 30 && $0.1 < 300 })
    }
}

@Suite("Semantic colors")
struct ColorTests {
    /// Every role resolves to a different value in each appearance.
    ///
    /// This assertion has now been inverted twice, and the history is the
    /// point. It first required each brand colour to *differ* between aqua and
    /// darkAqua, because the palette was two palettes. It was then flipped to
    /// require they be *identical*, because the app pinned `.darkAqua` and
    /// shipped one owned palette. It is flipped back here — but not to where
    /// it started.
    ///
    /// The mistake in the middle version was conflating two separate things:
    /// owning a palette, and refusing an appearance. CoreTend still owns every
    /// value; what it no longer does is override the user's choice of Light or
    /// Dark. So the invariant is not "fixed" and not merely "adapts" — it is
    /// *adapts to its own measured values*, which is what the next test checks.
    @Test func everyRoleHasBothAppearances() {
        for (name, color) in Self.roles {
            #expect(resolved(color, .aqua) != resolved(color, .darkAqua),
                    "\(name) resolves identically in both appearances, so one of them was never designed")
        }
    }

    /// Adapting must not mean deferring to AppKit.
    ///
    /// The cheap way to get a light mode is to hand the system colours back —
    /// `windowBackgroundColor`, `labelColor`, `controlAccentColor` — at which
    /// point the app has no appearance of its own in half of its life. Each
    /// resolved value is compared against the system colour that would have
    /// replaced it.
    ///
    /// Which roles are CoreTend's is decided per role, not by a blanket rule.
    ///
    /// `elevatedBackground` is deliberately absent. In Light it resolves to
    /// white, which is also `controlBackgroundColor` — and that is not a
    /// failure to own anything. Nobody owns white. An app's identity does not
    /// live in its neutral surfaces, and insisting on a slightly-off white
    /// purely so a test can call it "ours" is decoration pretending to be
    /// branding. Identity lives in the accent, in the ink-on-ground pairing,
    /// and in the tint applied to state — so those are what this pins.
    @Test func ownedRolesAreNotTheSystemDefaults() {
        let comparisons: [(String, Color, NSColor)] = [
            ("background", MCColor.background, .windowBackgroundColor),
            ("teal", MCColor.teal, .controlAccentColor),
            ("textPrimary", MCColor.textPrimary, .labelColor),
            ("textSecondary", MCColor.textSecondary, .secondaryLabelColor),
        ]
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            for (name, ours, system) in comparisons {
                #expect(resolved(ours, appearance) != resolved(Color(nsColor: system), appearance),
                        "\(name) in \(appearance.rawValue) is just the system colour")
            }
        }
    }

    private static let roles: [(String, Color)] = [
        ("teal", MCColor.teal), ("tealBright", MCColor.tealBright),
        ("tealDeep", MCColor.tealDeep), ("tealWash", MCColor.tealWash),
        ("graphite", MCColor.graphite), ("amber", MCColor.amber),
        ("coral", MCColor.coral), ("success", MCColor.success),
        ("background", MCColor.background), ("secondaryBackground", MCColor.secondaryBackground),
        ("elevatedBackground", MCColor.elevatedBackground),
        ("elevatedHighBackground", MCColor.elevatedHighBackground),
        ("separator", MCColor.separator), ("textPrimary", MCColor.textPrimary),
        ("textSecondary", MCColor.textSecondary), ("textTertiary", MCColor.textTertiary),
    ]

    /// Resolves a colour under a given appearance, so "does not adapt" is
    /// measured rather than assumed from how it was declared.
    private func resolved(_ color: Color, _ appearance: NSAppearance.Name) -> NSColor {
        let ns = NSColor(color)
        var out = NSColor.black
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            out = ns.usingColorSpace(.sRGB) ?? ns
        }
        return out
    }

    @Test func chartSeriesHasDistinctLeadColors() {
        #expect(MCColor.chartSeries.count >= 3)
    }

    /// The Space Lens swatches are held to the same rule as the brand palette:
    /// fixed, owned, identical under either system appearance.
    @Test func categoryColoursDoNotFollowTheSystemAppearance() {
        for (name, color) in [
            ("cellTealDeep", MCColor.cellTealDeep),
            ("cellGraphite", MCColor.cellGraphite),
            ("cellTealPale", MCColor.cellTealPale),
        ] {
            #expect(resolved(color, .aqua) == resolved(color, .darkAqua),
                    "\(name) still changes with the system appearance")
        }
    }

    /// Chart series must be distinguishable from one another, not merely
    /// present: four swatches that resolve to two colours is a chart with a
    /// lie in it.
    @Test func chartSeriesColoursAreMutuallyDistinct() {
        let resolvedSeries = MCColor.chartSeries.map { resolved($0, .darkAqua) }
        #expect(Set(resolvedSeries).count == MCColor.chartSeries.count)
    }

    @Test func categoryColorsAreMutuallyDistinct() {
        let colors = [MCColor.cellTealDeep, MCColor.cellGraphite, MCColor.cellTealPale]
        let hexes = Set(colors.map { NSColor($0).usingColorSpace(.sRGB) ?? NSColor($0) })
        #expect(hexes.count == colors.count, "category colors must be visually distinguishable from each other")
    }
}

@Suite("Brand resources")
struct BrandResourceTests {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test func generatedAssetsExist() {
        let generated = root.appendingPathComponent("Resources/Brand/Generated")
        for name in ["AppIcon.icns", "MenuBarTemplate.png", "MenuBarTemplate@2x.png", "AppIcon-1024.png"] {
            #expect(FileManager.default.fileExists(atPath: generated.appendingPathComponent(name).path),
                    "missing \(name)")
        }
    }

    @Test func iconsetCoversAllSizes() {
        let iconset = root.appendingPathComponent("Resources/Brand/Generated/AppIcon.iconset")
        for size in [16, 32, 128, 256, 512] {
            #expect(FileManager.default.fileExists(
                atPath: iconset.appendingPathComponent("icon_\(size)x\(size).png").path))
            #expect(FileManager.default.fileExists(
                atPath: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png").path))
        }
    }

    @Test func infoPlistDeclaresIconAndVersion() throws {
        let plistURL = root.appendingPathComponent("Resources/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let identityURL = root.appendingPathComponent("Configuration/PublicIdentity.example.json")
        let identityData = try Data(contentsOf: identityURL)
        let identity = try JSONSerialization.jsonObject(with: identityData) as? [String: Any]
        #expect(plist?["CFBundleIconFile"] as? String == "AppIcon")
        let version = plist?["CFBundleShortVersionString"] as? String ?? ""
        #expect(version.compare("0.4.0", options: .numeric) != .orderedAscending)
        #expect(version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil)
        let build = plist?["CFBundleVersion"] as? String ?? ""
        #expect(build.range(of: #"^\d+(\.\d+){0,2}$"#, options: .regularExpression) != nil)
        #expect(plist?["CFBundleIdentifier"] as? String == identity?["bundleId"] as? String)
        #expect(plist?["CoreTendMarketingVersion"] as? String == identity?["marketingVersion"] as? String)
        #expect(plist?["CFBundleVersion"] as? String == identity?["buildNumber"] as? String)
        #expect(plist?["LSMinimumSystemVersion"] as? String == identity?["deploymentTarget"] as? String)
    }
}

@Suite("Owned palette contrast")
struct PaletteContrastTests {
    private let ground = MCColor.Canonical.ground

    /// Every colour that carries text must clear the WCAG 4.5:1 body minimum
    /// on the one ground the app renders on. Ratios are recomputed here rather
    /// than trusted from the comments in Colors.swift: a documented ratio is a
    /// claim, and a claim that nothing checks is how palettes drift.
    @Test func textColoursClearTheBodyMinimum() {
        for (name, value) in [
            ("textPrimary", MCColor.Canonical.textPrimary),
            ("textSecondary", MCColor.Canonical.textSecondary),
            ("teal", MCColor.Canonical.teal),
            ("tealBright", MCColor.Canonical.tealBright),
            ("amber", MCColor.Canonical.amber),
            ("coral", MCColor.Canonical.coral),
            ("green", MCColor.Canonical.green),
        ] {
            let ratio = MCColor.contrastRatio(value, ground)
            #expect(ratio >= 4.5, "\(name) on ground is \(ratio):1, under the 4.5:1 body minimum")
        }
    }

    /// `textTertiary` deliberately sits under the body minimum. It is allowed
    /// to, because it is restricted to text that never carries meaning alone —
    /// but it must still clear the 3:1 large-text/non-text floor, and it must
    /// stay *below* secondary, or the three-tier hierarchy has collapsed into
    /// two tiers with an extra name.
    @Test func tertiaryTextIsDeliberatelyQuietButStillVisible() {
        let tertiary = MCColor.contrastRatio(MCColor.Canonical.textTertiary, ground)
        let secondary = MCColor.contrastRatio(MCColor.Canonical.textSecondary, ground)
        #expect(tertiary >= 3.0, "textTertiary on ground is \(tertiary):1, under the 3:1 floor")
        #expect(tertiary < 4.5, "textTertiary now clears the body minimum — it is no longer a third tier")
        #expect(tertiary < secondary, "tertiary is not quieter than secondary")
    }

    /// Primary text has to stay readable on every surface in the elevation
    /// ladder, not only on the ground. A card colour chosen for looks that
    /// happens to sink its own label is the classic way this breaks.
    @Test func primaryTextIsReadableOnEverySurface() {
        for (name, surface) in [
            ("ground", MCColor.Canonical.ground),
            ("sunken", MCColor.Canonical.sunken),
            ("raised", MCColor.Canonical.raised),
            ("raisedHigh", MCColor.Canonical.raisedHigh),
            ("tealWash", MCColor.Canonical.tealWash),
        ] {
            let ratio = MCColor.contrastRatio(MCColor.Canonical.textPrimary, surface)
            #expect(ratio >= 4.5, "textPrimary on \(name) is \(ratio):1")
        }
    }

    /// The elevation ladder must actually be a ladder. Four surfaces that are
    /// nearly the same colour are one surface with three extra names, and the
    /// depth the design depends on has to come from hairlines instead.
    @Test func elevationStepsArePerceptiblyDistinct() {
        let ladder = [
            ("ground", MCColor.Canonical.ground),
            ("sunken", MCColor.Canonical.sunken),
            ("raised", MCColor.Canonical.raised),
            ("raisedHigh", MCColor.Canonical.raisedHigh),
        ]
        for (lower, upper) in zip(ladder, ladder.dropFirst()) {
            let low = MCColor.relativeLuminance(lower.1)
            let high = MCColor.relativeLuminance(upper.1)
            #expect(high > low, "\(upper.0) is not lighter than \(lower.0)")
            #expect(high - low > 0.004,
                    "\(lower.0) -> \(upper.0) is too small a step to read as a change of plane")
        }
    }

    /// The ground is not pure black, on purpose: pure black under light text
    /// haloes, and on OLED it smears at every scroll edge.
    @Test func theGroundIsNotPureBlack() {
        #expect(MCColor.Canonical.ground != 0x000000)
        #expect(MCColor.relativeLuminance(MCColor.Canonical.ground) > 0.005)
    }

    /// Success and the accent must be told apart by hue, not only by
    /// brightness — otherwise a colourblind user reads "done" and "action" as
    /// the same state.
    @Test func successIsDistinguishableFromTheAccent() {
        let teal = MCColor.Canonical.teal, green = MCColor.Canonical.green
        let hueDistance = abs(Int((teal >> 16) & 0xFF) - Int((green >> 16) & 0xFF))
                        + abs(Int((teal >> 8) & 0xFF) - Int((green >> 8) & 0xFF))
                        + abs(Int(teal & 0xFF) - Int(green & 0xFF))
        #expect(hueDistance > 60, "teal and green are too close to read as different states")
    }

    /// Known-answer check on the ratio maths itself. If this is wrong, every
    /// assertion above is meaningless.
    @Test func contrastMathsMatchesKnownValues() {
        #expect(abs(MCColor.contrastRatio(0xFFFFFF, 0x000000) - 21.0) < 0.01)
        #expect(abs(MCColor.contrastRatio(0x000000, 0x000000) - 1.0) < 0.001)
        #expect(abs(MCColor.contrastRatio(0x777777, 0xFFFFFF) - 4.48) < 0.05)
    }
}

/// Window and column geometry, as arithmetic rather than as a hope.
///
/// The sidebar rendered its section headers as "ORAGE", "ORE", "STEM" with every
/// icon clipped, through four different attempted fixes, because the real cause
/// was not in the sidebar at all: `MCSize.windowMinWidth` was 860 while the
/// sidebar's minimum and the Dashboard hero's own minimum together needed more
/// than that. NavigationSplitView resolved the impossible constraint by
/// starving the sidebar below its stated minimum, and its contents then
/// overflowed and were clipped.
///
/// Nothing caught it because it is arithmetic between two numbers that live in
/// different files and were never compared.
@Suite("Window geometry")
struct WindowGeometryTests {
    /// What the Dashboard hero genuinely occupies: the 128pt ring, the copy
    /// column's floor, the metric column, their spacings and the page padding.
    /// Kept explicit so that widening the hero fails here rather than silently
    /// squeezing the sidebar.
    private let detailMinimum: CGFloat = 128 + 32 + 220 + 16 + 230 + (24 * 2)

    @Test func theWindowIsWideEnoughForBothColumnsAtTheirMinimums() {
        let required = MCSize.sidebarMin + detailMinimum
        #expect(MCSize.windowMinWidth >= required,
                "window minimum \(MCSize.windowMinWidth) is under the \(required) the two columns need at their minimums — the split view resolves that by starving the sidebar")
    }

    @Test func theDefaultWindowIsAtLeastTheMinimum() {
        #expect(MCSize.windowDefaultWidth >= MCSize.windowMinWidth)
        #expect(MCSize.windowDefaultHeight >= MCSize.windowMinHeight)
    }

    /// The column bounds must be a coherent range, and the ideal must sit
    /// inside it — an ideal outside min…max is silently ignored.
    @Test func sidebarColumnBoundsAreCoherent() {
        #expect(MCSize.sidebarMin <= MCSize.sidebarIdeal)
        #expect(MCSize.sidebarIdeal <= MCSize.sidebarMax)
    }

    /// A sidebar wide enough to matter, capped so a dragged divider cannot turn
    /// it into half the window.
    @Test func theSidebarStaysASidebar() {
        #expect(MCSize.sidebarMin >= 180)
        #expect(MCSize.sidebarMax <= MCSize.windowMinWidth / 2)
    }
}

/// Motion is a system or it is not worth having.
///
/// Before these, seventeen animation call sites used eight distinct durations
/// across four curve families — `.smooth(0.4)`, `.smooth(0.45)`, `.smooth(0.3)`,
/// `.easeOut(0.9)`, `.easeOut(0.6)`, `.easeOut(0.35)`, `.easeOut(0.18)`,
/// `.spring(0.45, 0.62)` — with no way to change how the app feels without
/// finding all of them, and no way to tell an intentional difference from a
/// forgotten one.
@Suite("Motion system")
struct MotionSystemTests {
    private let sourceRoots = ["Sources/CoreTendApp", "Sources/DesignSystem"]
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func sources() throws -> [(name: String, text: String)] {
        var out: [(String, String)] = []
        for relative in sourceRoots {
            let dir = root.appendingPathComponent(relative)
            for name in try SourceTree.swiftFiles(under: dir)
                where name.hasSuffix(".swift") {
                out.append((name, try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)))
            }
        }
        return out
    }

    /// No view may invent its own curve. The tokens are named by intent, so a
    /// raw curve at a call site means either a duration nobody chose or an
    /// intent the system does not yet have a name for — both worth stopping on.
    @Test func noViewDeclaresItsOwnAnimationCurve() throws {
        // `Tokens.swift` defines the curves; `TimelineView(.animation(...))` is
        // a scheduler, not an animation.
        let forbidden = [".smooth(duration:", ".easeOut(duration:", ".easeIn(duration:",
                         ".easeInOut(duration:", ".linear(duration:", ".spring(response:"]
        for file in try sources() where file.name != "Tokens.swift" {
            for line in file.text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                for pattern in forbidden {
                    #expect(!trimmed.contains(pattern),
                            "\(file.name) declares its own curve — use an MCMotion token: \(trimmed)")
                }
            }
        }
    }

    /// Ordered the way the names claim, and — the load-bearing part — every
    /// token a user can trigger stays under the 300 ms threshold. Only
    /// `ambient`, which reports nothing and gates nothing, is allowed past it.
    ///
    /// Durations are restated here deliberately: changing one fails this, and
    /// someone confirms the ordering and the threshold still hold.
    @Test func userTriggeredMotionStaysUnderTheThreshold() {
        let response = 0.15, transition = 0.22, reveal = 0.28, ambient = 0.5
        #expect(response < transition)
        #expect(transition < reveal)
        for (name, duration) in [("response", response), ("transition", transition),
                                 ("reveal", reveal)] {
            #expect(duration < 0.3,
                    "\(name) is \(duration)s — user-triggered motion over 300ms reads as sluggish")
        }
        #expect(ambient > reveal, "ambient is not the slow one")
    }

    /// `ambient` must have exactly one user. It exists so that "this is
    /// decorative" has to be said out loud; a second call site is the moment
    /// that stops being true.
    @Test func ambientIsUsedOnlyForDecoration() throws {
        var uses: [String] = []
        for relative in ["Sources/CoreTendApp", "Sources/DesignSystem"] {
            let dir = root.appendingPathComponent(relative)
            for name in try SourceTree.swiftFiles(under: dir)
                where name.hasSuffix(".swift") && name != "Tokens.swift" {
                let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
                for line in text.split(separator: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.hasPrefix("//") else { continue }
                    if trimmed.contains("MCMotion.ambient") { uses.append(name) }
                }
            }
        }
        #expect(uses == ["Components.swift"],
                "MCMotion.ambient is used in \(uses) — it is for decoration only")
    }

    /// The stagger must not grow without bound. An ungated `index * step` makes
    /// the fortieth row of a list wait 2.4 seconds for its turn.
    @Test func staggerIsCapped() {
        #expect(MCMotion.stagger(index: 0) == 0)
        #expect(MCMotion.stagger(index: 3) > MCMotion.stagger(index: 1))
        #expect(MCMotion.stagger(index: 1000) == MCMotion.stagger(index: 6),
                "stagger is unbounded — a long list will wait on it")
        #expect(MCMotion.stagger(index: 1000) <= 0.36)
    }

    /// Reduce Motion must still be expressible for the call sites that pass an
    /// animation around rather than applying it.
    @Test func reduceMotionSuppressesAnimationEntirely() {
        #expect(MCMotion.animation(MCMotion.reveal, reduce: true) == nil)
        #expect(MCMotion.animation(MCMotion.reveal, reduce: false) != nil)
    }
}

/// Typography is a system or it is not worth having.
///
/// The token set held ten styles and views bypassed it anyway: `.font(.caption)`
/// appeared 56 times — more than any token here was used — alongside 15 uses of
/// `.caption2` at three weights, and eleven bare `.system(size: N)` literals
/// (9, 12, 13, 14, 15, 28, 30, 34). 92 uses of the system against roughly 110
/// that went around it.
///
/// That is not a discipline problem. A token set that does not name the styles
/// a codebase actually needs will be bypassed, and each bypass is a decision
/// nobody can find later.
@Suite("Typography system")
struct TypographySystemTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func sources() throws -> [(name: String, text: String)] {
        var out: [(String, String)] = []
        for relative in ["Sources/CoreTendApp", "Sources/DesignSystem"] {
            let dir = root.appendingPathComponent(relative)
            for name in try SourceTree.swiftFiles(under: dir)
                where name.hasSuffix(".swift") && name != "Typography.swift" {
                out.append((name, try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)))
            }
        }
        return out
    }

    /// No numeric point size outside the token file. A glyph size belongs to
    /// `MCIconSize`; a text size belongs to `MCFont`. A literal is neither, and
    /// is how 13, 14 and 15 all came to exist for the same job.
    /// The type system itself carried three absolute sizes — 40, 28 and 11pt —
    /// next to twelve Dynamic Type styles, so the interface scaled *partially*
    /// under a larger system text size, which is worse than either choice made
    /// consistently. The only sizes left are the sidebar's, and those mirror
    /// the system row-size setting rather than a taste.
    @Test func theTypeSystemHasNoAbsoluteSizes() throws {
        let text = try String(contentsOf: root.appendingPathComponent("Sources/DesignSystem/Typography.swift"), encoding: .utf8)
        let pattern = try NSRegularExpression(pattern: #"size:\s*\d"#)
        let range = NSRange(text.startIndex..., in: text)
        #expect(pattern.firstMatch(in: text, range: range) == nil,
                "Typography.swift hardcodes a point size")
    }

    @Test func noViewHardcodesAPointSize() throws {
        let pattern = try NSRegularExpression(pattern: #"\.system\(size:\s*\d"#)
        for file in try sources() {
            for line in file.text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                #expect(pattern.firstMatch(in: trimmed, range: range) == nil,
                        "\(file.name) hardcodes a point size — use MCFont or MCIconSize: \(trimmed)")
            }
        }
    }

    /// No raw Dynamic Type style either. `.font(.caption)` was the single most
    /// common font call in the app while `MCFont.caption` sat unused beside it.
    @Test func noViewUsesARawTextStyle() throws {
        let raw = [".font(.caption)", ".font(.caption2)", ".font(.headline)",
                   ".font(.title2)", ".font(.title3)", ".font(.footnote)",
                   ".font(.callout.weight(", ".font(.caption.weight(", ".font(.caption2.weight("]
        for file in try sources() {
            for line in file.text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                for style in raw {
                    #expect(!trimmed.contains(style),
                            "\(file.name) uses a raw text style — use an MCFont token: \(trimmed)")
                }
            }
        }
    }

    /// The icon scale must be a scale. Sizes that differ by a point are not two
    /// decisions, they are one decision typed twice.
    @Test func iconSizesAreDistinctEnoughToBeDeliberate() {
        let scale: [(String, CGFloat)] = [
            ("inline", MCIconSize.inline), ("chevron", MCIconSize.chevron),
            ("row", MCIconSize.row), ("card", MCIconSize.card),
            ("feature", MCIconSize.feature), ("hero", MCIconSize.hero),
            ("compactState", MCIconSize.compactState), ("emptyState", MCIconSize.emptyState),
            ("emptyStateProminent", MCIconSize.emptyStateProminent),
        ]
        for (lower, upper) in zip(scale, scale.dropFirst()) {
            #expect(upper.1 > lower.1, "\(upper.0) is not larger than \(lower.0)")
            #expect(upper.1 - lower.1 >= 2,
                    "\(lower.0) (\(lower.1)) and \(upper.0) (\(upper.1)) are too close to be two decisions")
        }
    }
}

/// Text must be readable on whatever it sits on, including accent fills.
///
/// The palette's contrast suite measured text colours against the *ground*. It
/// never measured a label against the fill it was printed on, and the app's
/// primary action was white on the brand teal: **1.87:1**, against a 4.5:1
/// minimum, on Scan Storage, Find Duplicates and Scan Home Folder. It looked
/// fine to anyone who already knew what the button said.
///
/// `.buttonStyle(.borderedProminent)` is what produced it: the system style
/// pairs the view's tint with a white label and never checks that the two can
/// be read together.
@Suite("Controls are the system's; the brand stays on data")
struct ControlStyleTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The custom button styles existed to fix white on brand teal (1.87:1).
    /// Controls no longer wear the brand — they use the system accent through
    /// `.borderedProminent` / `.bordered`, like every other Mac app — so the
    /// styles are gone and nothing may quietly rebuild them.
    @Test func noViewPaintsAButtonWithTheBrand() throws {
        let dir = root.appendingPathComponent("Sources/CoreTendApp")
        for name in try SourceTree.swiftFiles(under: dir) {
            let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
            for retired in ["mcPrimaryButton", "mcSecondaryButton", "mcDestructiveButton",
                            "MCPrimaryButtonStyle", "MCCard", ".mcSurface(", "MCElevation"] {
                #expect(!text.contains(retired), "\(name) uses retired API \(retired)")
            }
            for line in text.split(separator: "\n") where line.contains("buttonStyle") {
                #expect(!line.contains("MCColor.teal"), "\(name) tints a control with the brand: \(line)")
            }
        }
    }
}

@Suite("Liquid Glass adoption")
struct GlassAdoptionTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func sources() throws -> [(name: String, text: String)] {
        var out: [(String, String)] = []
        for relative in ["Sources/CoreTendApp", "Sources/DesignSystem"] {
            let dir = root.appendingPathComponent(relative)
            for name in try SourceTree.swiftFiles(under: dir)
                where name.hasSuffix(".swift") {
                out.append((name, try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)))
            }
        }
        return out
    }

    /// `glassEffect` is macOS 26 only and the deployment target is macOS 14. An
    /// ungated call does not fail to compile against a newer SDK — it fails to
    /// launch on the machines this app supports.
    @Test func glassIsOnlyCalledFromTheGatedModifier() throws {
        for file in try sources() where file.name != "Glass.swift" {
            for line in file.text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") && !trimmed.hasPrefix("///") else { continue }
                #expect(!trimmed.contains(".glassEffect("),
                        "\(file.name) calls glassEffect directly — use .mcNavigationGlass, which gates it")
            }
        }
    }

    /// Only the two navigation-layer surfaces adopt it. Every other call site
    /// would be content, which is what Apple says not to do.
    @Test func onlyNavigationSurfacesUseGlass() throws {
        let allowed: Set<String> = ["Sidebar.swift", "ModuleSubNav.swift", "Glass.swift"]
        for file in try sources() where !allowed.contains(file.name) {
            for line in file.text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Comments may name it — Components.swift explains, at length,
                // why content-layer buttons do not use it.
                guard !trimmed.hasPrefix("//") else { continue }
                #expect(!trimmed.contains("mcNavigationGlass"),
                        "\(file.name) applies glass to something that is not the navigation layer")
            }
        }
    }

    /// Both of them actually adopt it, so the modifier is not dead code that
    /// only exists to be tested.
    @Test func bothNavigationSurfacesAdoptIt() throws {
        let sources = Dictionary(uniqueKeysWithValues: try sources().map { ($0.name, $0.text) })
        for name in ["Sidebar.swift", "ModuleSubNav.swift"] {
            let text = try #require(sources[name])
            #expect(text.contains("mcNavigationGlass"), "\(name) does not adopt glass")
        }
    }

    /// The gate and its documentation must not drift apart.
    @Test func theAvailabilityGateMatchesTheDocumentedVersion() {
        #expect(MCGlassAvailability.minimumMajorVersion == 26)
        // On any machine running this suite, the reported support must match
        // what the OS actually is — a hardcoded `true` would pass silently.
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        #expect(MCGlassAvailability.isSupported == (major >= MCGlassAvailability.minimumMajorVersion))
    }

    /// Glass is transparency. Someone who turned Reduce Transparency on has
    /// said at the system level that translucent chrome is hard for them to
    /// read, and the fallback must be a real opaque surface rather than
    /// nothing.
    @Test func reduceTransparencyIsHonouredWithAnOpaqueFallback() throws {
        let sources = Dictionary(uniqueKeysWithValues: try sources().map { ($0.name, $0.text) })
        let glass = try #require(sources["Glass.swift"])
        #expect(glass.contains("accessibilityReduceTransparency"))
        #expect(glass.contains("!reduceTransparency"),
                "the effect is not actually disabled when the setting is on")
        // Both call sites must pass a fallback colour.
        for name in ["Sidebar.swift", "ModuleSubNav.swift"] {
            let text = try #require(sources[name])
            #expect(text.contains("fallback: MCColor."), "\(name) passes no opaque fallback")
        }
    }
}

/// The system's glass button styles were measured and rejected for content.
@Suite("Glass button adoption")
struct GlassButtonAdoptionTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func sources() throws -> [(name: String, text: String)] {
        var out: [(String, String)] = []
        for relative in ["Sources/CoreTendApp", "Sources/DesignSystem"] {
            let dir = root.appendingPathComponent(relative)
            for name in try SourceTree.swiftFiles(under: dir)
                where name.hasSuffix(".swift") {
                out.append((name, try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)))
            }
        }
        return out
    }

    /// No content-layer button uses a glass style.
    ///
    /// `.glassProminent` measures 11.13:1 on a flat ground — and 2.61:1 inside
    /// the Dashboard's teal-washed feature card, where the primary action
    /// actually sits, because glass samples what is behind it. That is the
    /// HIG's own rule arriving as a measurement: "Don't use Liquid Glass in the
    /// content layer."
    @Test func noContentButtonUsesAGlassStyle() throws {
        for file in try sources() {
            for line in file.text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") && !trimmed.hasPrefix("///") else { continue }
                for style in [".buttonStyle(.glassProminent)", ".buttonStyle(.glass)"] {
                    #expect(!trimmed.contains(style),
                            "\(file.name) puts glass on a content-layer button — measured 2.61:1 there")
                }
            }
        }
    }

    /// Call sites go through the role modifiers rather than naming a style, so
    /// the decision above lives in one place and can be revisited in one place.
    @Test func callSitesUseTheRoleModifiers() throws {
        for file in try sources() where file.name != "Components.swift" {
            for line in file.text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                for style in [".buttonStyle(.mcPrimary)", ".buttonStyle(.mcSecondary)",
                              ".buttonStyle(.mcDestructive)"] {
                    #expect(!trimmed.contains(style),
                            "\(file.name) names a style directly — use mcPrimaryButton() and friends")
                }
            }
        }
    }

    /// Glass stays where the HIG puts it: the navigation layer.
    @Test func glassRemainsOnTheNavigationLayer() throws {
        let sources = Dictionary(uniqueKeysWithValues: try sources().map { ($0.name, $0.text) })
        for name in ["Sidebar.swift", "ModuleSubNav.swift"] {
            #expect(sources[name]?.contains("mcNavigationGlass") == true,
                    "\(name) no longer uses glass")
        }
    }
}
