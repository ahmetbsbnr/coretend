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
            for name in try FileManager.default.contentsOfDirectory(atPath: dir.path)
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

    /// Reveal is the slowest and response the fastest, or the names mean
    /// nothing. Checked by duration because an Animation is otherwise opaque.
    @Test func theTokensAreOrderedTheWayTheirNamesClaim() {
        // Durations restated here deliberately: if a token's duration changes,
        // this fails and someone confirms the ordering still holds.
        let reveal = 0.4, transition = 0.25, response = 0.15
        #expect(response < transition)
        #expect(transition < reveal)
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
            for name in try FileManager.default.contentsOfDirectory(atPath: dir.path)
                where name.hasSuffix(".swift") && name != "Typography.swift" {
                out.append((name, try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)))
            }
        }
        return out
    }

    /// No numeric point size outside the token file. A glyph size belongs to
    /// `MCIconSize`; a text size belongs to `MCFont`. A literal is neither, and
    /// is how 13, 14 and 15 all came to exist for the same job.
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
@Suite("On-accent contrast")
struct OnAccentContrastTests {
    private let onAccent = MCColor.Canonical.ground

    /// Every fill a label is printed on must carry that label at 4.5:1.
    @Test func labelsAreReadableOnEveryAccentFill() {
        for (name, fill) in [
            ("teal", MCColor.Canonical.teal),
            ("tealDeep", MCColor.Canonical.tealDeep),
            ("coral", MCColor.Canonical.coral),
            ("amber", MCColor.Canonical.amber),
            ("green", MCColor.Canonical.green),
        ] {
            let ratio = MCColor.contrastRatio(onAccent, fill)
            #expect(ratio >= 4.5, "onAccent on \(name) is \(ratio):1, under the 4.5:1 text minimum")
        }
    }

    /// The regression, stated as a fact so it cannot be reintroduced by someone
    /// deciding white looks better.
    @Test func whiteOnTealIsUnreadableAndIsNotWhatWeUse() {
        let white: UInt32 = 0xFFFFFF
        #expect(MCColor.contrastRatio(white, MCColor.Canonical.teal) < 2.0,
                "if this ever passes, the teal changed and the comment explaining onAccent is stale")
        #expect(MCColor.contrastRatio(onAccent, MCColor.Canonical.teal) > 9.0)
    }

    /// The pressed state must stay readable too — a button is most often read
    /// at the moment it is being pressed.
    @Test func thePressedFillIsAlsoReadable() {
        #expect(MCColor.contrastRatio(onAccent, MCColor.Canonical.tealDeep) >= 4.5)
    }
}

/// Destructive actions must not wear the primary action's clothes.
@Suite("Button style assignment")
struct ButtonStyleAssignmentTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func sources() throws -> [(name: String, text: String)] {
        var out: [(String, String)] = []
        for relative in ["Sources/CoreTendApp", "Sources/DesignSystem"] {
            let dir = root.appendingPathComponent(relative)
            for name in try FileManager.default.contentsOfDirectory(atPath: dir.path)
                where name.hasSuffix(".swift") {
                out.append((name, try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)))
            }
        }
        return out
    }

    /// The system prominent style is banned outright. It is where the 1.87:1
    /// label came from, and it also made "Move to Trash" and "Uninstall" look
    /// exactly like "Scan Storage" — the button that deletes files rendered
    /// identically to the one that starts a scan.
    @Test func noViewUsesTheSystemProminentStyle() throws {
        for file in try sources() {
            for line in file.text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") && !trimmed.hasPrefix("///") else { continue }
                #expect(!trimmed.contains(".buttonStyle(.borderedProminent)"),
                        "\(file.name) uses the system prominent style — use .mcPrimary or .mcDestructive")
            }
        }
    }

    /// Coral must be distinguishable from teal without colour — the two fills
    /// differ in luminance as well as hue, so a greyscale or colourblind reader
    /// still sees two different buttons.
    @Test func destructiveAndPrimaryDifferWithoutColour() {
        let teal = MCColor.relativeLuminance(MCColor.Canonical.teal)
        let coral = MCColor.relativeLuminance(MCColor.Canonical.coral)
        #expect(abs(teal - coral) > 0.08,
                "teal and coral fills are too close in luminance to tell apart in greyscale")
    }
}
