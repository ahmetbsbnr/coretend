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

    @Test func motionDurationsAreReasonable() {
        #expect(MCMotion.quick < MCMotion.standard)
        #expect(MCMotion.standard < MCMotion.gentle)
        #expect(MCMotion.gentle < 1.0) // no slow, decorative animation
    }

    @Test func reduceMotionSuppressesAnimation() {
        #expect(MCMotion.animation(.default, reduce: true) == nil)
        #expect(MCMotion.animation(.default, reduce: false) != nil)
    }
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
    /// This assertion is the exact inverse of the one it replaces.
    ///
    /// It used to require that every brand colour *differ* between the aqua
    /// and darkAqua appearances, because the palette was two palettes. CoreTend
    /// now renders in one owned appearance, so a colour that still changes
    /// under the system switch is a colour that escaped the migration — it
    /// would render differently for a user in Light appearance than the values
    /// the contrast suite measures, making those measurements false.
    @Test func brandColoursDoNotFollowTheSystemAppearance() {
        for (name, color) in [
            ("teal", MCColor.teal), ("tealBright", MCColor.tealBright),
            ("tealDeep", MCColor.tealDeep), ("tealWash", MCColor.tealWash),
            ("graphite", MCColor.graphite), ("amber", MCColor.amber),
            ("coral", MCColor.coral), ("success", MCColor.success),
            ("background", MCColor.background), ("secondaryBackground", MCColor.secondaryBackground),
            ("elevatedBackground", MCColor.elevatedBackground),
            ("elevatedHighBackground", MCColor.elevatedHighBackground),
            ("separator", MCColor.separator), ("textPrimary", MCColor.textPrimary),
            ("textSecondary", MCColor.textSecondary), ("textTertiary", MCColor.textTertiary),
        ] {
            #expect(resolved(color, .aqua) == resolved(color, .darkAqua),
                    "\(name) still changes with the system appearance")
        }
    }

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
