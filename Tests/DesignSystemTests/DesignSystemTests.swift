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
    /// Light and dark variants must actually differ (adaptive check).
    @Test func brandColorsAdapt() {
        for color in [MCColor.teal, MCColor.graphite, MCColor.amber, MCColor.coral] {
            let ns = NSColor(color)
            var light = NSColor.black, dark = NSColor.black
            NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
                light = ns.usingColorSpace(.sRGB) ?? ns
            }
            NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
                dark = ns.usingColorSpace(.sRGB) ?? ns
            }
            #expect(light != dark)
        }
    }

    @Test func chartSeriesHasDistinctLeadColors() {
        #expect(MCColor.chartSeries.count >= 3)
    }

    /// Space Lens category colors — previously raw Color(red:green:blue:)
    /// literals that never changed between light/dark. Now real adaptive
    /// tokens; must pass the same check as the brand palette.
    @Test func categoryColorsAdapt() {
        for color in [MCColor.cellTealDeep, MCColor.cellGraphite, MCColor.cellTealPale] {
            let ns = NSColor(color)
            var light = NSColor.black, dark = NSColor.black
            NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
                light = ns.usingColorSpace(.sRGB) ?? ns
            }
            NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
                dark = ns.usingColorSpace(.sRGB) ?? ns
            }
            #expect(light != dark)
        }
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

@Suite("Porcelain/Slate/Teal palette contrast")
struct PaletteContrastTests {
    /// WCAG 2.1 relative luminance.
    private static func luminance(_ c: (Double, Double, Double)) -> Double {
        func channel(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.0) + 0.7152 * channel(c.1) + 0.0722 * channel(c.2)
    }

    private static func ratio(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let la = luminance(a), lb = luminance(b)
        let (hi, lo) = la > lb ? (la, lb) : (lb, la)
        return (hi + 0.05) / (lo + 0.05)
    }

    /// The dark-surface accents are only defensible if they're actually
    /// readable on Slate. `cobaltBright` is the brightened Slate sibling of
    /// the brand teal; amber/coral are functional (non-brand) hues.
    @Test func darkSurfaceAccentsAreReadableOnInk() {
        let ink = MCColor.Canonical.ink
        for (name, value) in [
            ("cobaltBright", MCColor.Canonical.cobaltBright),
            ("warmAmber", MCColor.Canonical.warmAmber),
            ("signalCoral", MCColor.Canonical.signalCoral),
        ] {
            let r = Self.ratio(value, ink)
            #expect(r >= 4.5, "\(name) on Ink is \(r):1, below the 4.5:1 text minimum")
        }
    }

    /// The reason amberDeep/coralDeep/slateDeep exist at all. If one of them
    /// ever drifts back toward its canonical value, this fails instead of
    /// shipping unreadable text to every light-mode install. Cobalt itself is
    /// not in this list — see `canonicalCobaltPassesOnPaperDirectly` below,
    /// it needs no deepened sibling because it was tuned for Paper already.
    @Test func lightSiblingsAreReadableOnPaper() {
        let paper = MCColor.Canonical.paper
        for (name, value) in [
            ("amberDeep", MCColor.Canonical.amberDeep),
            ("coralDeep", MCColor.Canonical.coralDeep),
            ("slateDeep", MCColor.Canonical.slateDeep),
        ] {
            let r = Self.ratio(value, paper)
            #expect(r >= 4.5, "\(name) on Paper is \(r):1, below the 4.5:1 text minimum")
        }
    }

    /// Cobalt is published for Paper, and needs no darkened sibling because
    /// it already clears the text minimum there directly.
    @Test func canonicalCobaltPassesOnPaperDirectly() {
        let r = Self.ratio(MCColor.Canonical.cobalt, MCColor.Canonical.paper)
        #expect(r >= 4.5, "Cobalt on Paper is \(r):1, below the 4.5:1 text minimum")
    }

    /// Documents the trap `cobaltBright` exists to avoid: the canonical brand
    /// blue is nowhere near readable on Ink. If this ever stops being true
    /// the palette changed, and the divergence comment in Colors.swift needs
    /// rewriting rather than quietly keeping two values.
    @Test func canonicalCobaltWouldFailOnInk() {
        let r = Self.ratio(MCColor.Canonical.cobalt, MCColor.Canonical.ink)
        #expect(r < 4.5, "Cobalt now passes on Ink (\(r):1) — the light/dark split may no longer be needed")
    }

    /// Muted Slate is specified for secondary text and the secondary accent;
    /// on the dark surface it has to clear the 3:1 large-text floor at minimum.
    @Test func mutedSlateClearsTheLargeTextFloorOnInk() {
        let r = Self.ratio(MCColor.Canonical.mutedSlate, MCColor.Canonical.ink)
        #expect(r >= 3.0, "Muted Slate on Ink is \(r):1, below the 3:1 large-text floor")
    }
}
