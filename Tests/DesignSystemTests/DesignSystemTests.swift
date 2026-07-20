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
        for color in [MCColor.coreMint, MCColor.ionViolet, MCColor.solarAmber, MCColor.pulseCoral] {
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
        #expect(plist?["CFBundleIconFile"] as? String == "AppIcon")
        let version = plist?["CFBundleShortVersionString"] as? String ?? ""
        #expect(version.compare("0.4.0", options: .numeric) != .orderedAscending)
    }
}

@Suite("Cleanup fragment motif")
struct FragmentTests {
    @Test func fractionClampsToUnitRange() {
        let over = MCFragmentSpec(id: "a", label: "A", fraction: 1.4, selection: .all, tint: MCColor.storage)
        let under = MCFragmentSpec(id: "b", label: "B", fraction: -0.2, selection: .none, tint: MCColor.storage)
        #expect(over.fraction == 1)
        #expect(under.fraction == 0)
    }

    @Test func accessibilityDescriptionCountsSelectedGroups() {
        let fragments = [
            MCFragmentSpec(id: "a", label: "A", fraction: 0.5, selection: .all, tint: MCColor.storage),
            MCFragmentSpec(id: "b", label: "B", fraction: 0.3, selection: .none, tint: MCColor.protection),
            MCFragmentSpec(id: "c", label: "C", fraction: 0.2, selection: .partial, tint: MCColor.performance),
        ]
        #expect(MCFragmentView.accessibilityDescription(fragments: fragments) == "3 categories, 2 with items selected.")
        #expect(MCFragmentView.accessibilityDescription(fragments: []) == "No categories found yet.")
    }
}
