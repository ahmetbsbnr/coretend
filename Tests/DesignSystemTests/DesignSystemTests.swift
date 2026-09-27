import AppKit
import SwiftUI
import XCTest
@testable import DesignSystem

final class DesignSystemTests: XCTestCase {
    func testHexParsingMatchesComponents() {
        let teal = RGB(hex: 0x0B6E6C)
        XCTAssertEqual(teal.red, 11.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(teal.green, 110.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(teal.blue, 108.0 / 255, accuracy: 0.0001)
    }

    func testContrastRatioMatchesWCAGReferencePoints() {
        XCTAssertEqual(RGB(hex: 0x000000).contrast(with: RGB(hex: 0xFFFFFF)), 21, accuracy: 0.01)
        XCTAssertEqual(RGB(hex: 0x777777).contrast(with: RGB(hex: 0x777777)), 1, accuracy: 0.0001)
    }

    private let backgrounds = [Palette.canvas, Palette.sidebar, Palette.surface, Palette.raisedSurface]

    func testTextRolesMeetBodyContrastOnEveryBackgroundInBothAppearances() {
        for appearance in Appearance.allCases {
            for background in backgrounds {
                for role in [Palette.ink, Palette.secondaryInk, Palette.tertiaryInk, Palette.accent, Palette.caution, Palette.danger] {
                    let ratio = role.value(for: appearance).contrast(with: background.value(for: appearance))
                    XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(role.name) on \(background.name) in \(appearance) is \(ratio):1")
                }
            }
        }
    }

    func testControlOutlinesAndFocusMeetNonTextContrastOnEveryBackground() {
        for appearance in Appearance.allCases {
            for background in backgrounds {
                for role in [Palette.strongSeparator, Palette.focus] {
                    let ratio = role.value(for: appearance).contrast(with: background.value(for: appearance))
                    XCTAssertGreaterThanOrEqual(ratio, 3, "\(role.name) on \(background.name) in \(appearance) is \(ratio):1")
                }
            }
        }
    }

    func testTextOnAccentFillMeetsBodyContrastInBothAppearances() {
        for appearance in Appearance.allCases {
            let ratio = Palette.onAccent.value(for: appearance).contrast(with: Palette.accent.value(for: appearance))
            XCTAssertGreaterThanOrEqual(ratio, 4.5, "on-accent in \(appearance) is \(ratio):1")
        }
    }

    /// The UI guide (Documentation/Design/UI-guide.md § 2) is the source of these values.
    func testPaletteMatchesTheSerreGuide() {
        let guide: [(PaletteRole, UInt32, UInt32)] = [
            (Palette.canvas, 0xE7EFE4, 0x0F2019), (Palette.sidebar, 0xDCE7D8, 0x0B1913),
            (Palette.surface, 0xF4F8F1, 0x14291F), (Palette.raisedSurface, 0xFFFFFF, 0x183126),
            (Palette.deep, 0xD3E0CF, 0x0A1510), (Palette.ink, 0x10261C, 0xEEF1E6),
            (Palette.secondaryInk, 0x35503F, 0xC3CDB9), (Palette.tertiaryInk, 0x4F6557, 0x8FA088),
            (Palette.separator, 0xBFD0C1, 0x2C4A37), (Palette.strongSeparator, 0x65826D, 0x5F8A6C),
            (Palette.accent, 0x2C6E35, 0x9BE36D), (Palette.onAccent, 0xF4F8F1, 0x0B1913),
            (Palette.caution, 0x8A5A00, 0xE8B64A), (Palette.danger, 0xA9431C, 0xE98A63),
            (Palette.focus, 0x2C6E35, 0x9BE36D),
        ]
        for (role, light, dark) in guide {
            XCTAssertEqual(role.light, RGB(hex: light), "\(role.name) light")
            XCTAssertEqual(role.dark, RGB(hex: dark), "\(role.name) dark")
        }
    }

    func testMotionTokensFollowTheSerreGuideAndReduceMotionRemovesAnimation() {
        let guide: [(MotionToken, Double)] = [(.press, 0.09), (.quick, 0.16), (.standard, 0.28), (.grow, 0.48), (.bloom, 1.2)]
        XCTAssertEqual(MotionToken.allCases.count, guide.count)
        for (token, duration) in guide {
            XCTAssertEqual(token.duration, duration, "\(token)")
            for curve in MotionCurve.allCases {
                XCTAssertNil(token.animation(curve, reduceMotion: true), "\(token) \(curve) under Reduce Motion")
                XCTAssertNotNil(token.animation(curve, reduceMotion: false))
            }
        }
    }

    func testSerreTypefacesShipWithMacOS() {
        for name in CoreTendTypography.requiredFontNames {
            XCTAssertNotNil(NSFont(name: name, size: 14), "\(name) is not installed")
        }
    }

    func testLeafCornersAreAsymmetricAsTheGuideSays() {
        XCTAssertEqual(LeafCorner.control.radii.large, 16); XCTAssertEqual(LeafCorner.control.radii.small, 5)
        XCTAssertEqual(LeafCorner.parcel.radii.large, 20); XCTAssertEqual(LeafCorner.parcel.radii.small, 7)
        XCTAssertEqual(LeafCorner.sheet.radii.large, 22); XCTAssertEqual(LeafCorner.sheet.radii.small, 8)
    }
}

final class SerreDrawingTests: XCTestCase {
    private let box = CGRect(x: 0, y: 0, width: 24, height: 24)

    func testEveryGlyphIsDrawnInsideItsBoxAndDiffersFromTheOthers() {
        var outlines = Set<String>()
        for glyph in SerreGlyph.allCases {
            let path = SerreGlyphShape(glyph: glyph).path(in: box)
            XCTAssertFalse(path.isEmpty, "\(glyph) is empty")
            let bounds = path.boundingRect
            XCTAssertTrue(box.insetBy(dx: -0.5, dy: -0.5).contains(bounds), "\(glyph) leaves its box: \(bounds)")
            XCTAssertGreaterThan(bounds.width * bounds.height, 60, "\(glyph) is too small to read")
            outlines.insert(path.description)
        }
        XCTAssertEqual(outlines.count, SerreGlyph.allCases.count, "two glyphs share a drawing")
    }

    func testGlyphsScaleWithTheirFrame() {
        let small = SerreGlyphShape(glyph: .overview).path(in: box).boundingRect
        let large = SerreGlyphShape(glyph: .overview).path(in: CGRect(x: 0, y: 0, width: 48, height: 48)).boundingRect
        XCTAssertEqual(large.width, small.width * 2, accuracy: 0.01)
    }

    func testRiskLeavesDifferByShapeNotOnlyByColor() {
        let shapes = RiskLevel.allCases.map { RiskLeafShape(level: $0).path(in: CGRect(x: 0, y: 0, width: 12, height: 12)).description }
        XCTAssertEqual(Set(shapes).count, RiskLevel.allCases.count)
    }

    func testLogoGerminationEndsInTheStillFinalState() {
        let final = SerreLogoState.grown
        XCTAssertEqual(final.seedDrop, 0); XCTAssertEqual(final.stem, 1)
        XCTAssertEqual(final.firstLeaf, 1); XCTAssertEqual(final.secondLeaf, 1)
        let seed = SerreLogoState.seed
        XCTAssertEqual(seed.stem, 0); XCTAssertEqual(seed.firstLeaf, 0); XCTAssertEqual(seed.secondLeaf, 0)
        XCTAssertGreaterThan(seed.seedDrop, 0)
        XCTAssertEqual(SerreLogo.germinationSteps.map(\.delay), SerreLogo.germinationSteps.map(\.delay).sorted(), "steps out of order")
        let total = SerreLogo.germinationSteps.map { $0.delay + $0.duration }.max() ?? 0
        XCTAssertLessThanOrEqual(total, 1.35, "germination is longer than the guide's 1.3 s")
    }
}

/// Renders every glyph, risk leaf and germination step to PNG for a visual check.
/// Runs only when CORETEND_RENDER_DIR names an output folder.
final class SerreRenderSheet: XCTestCase {
    @MainActor
    func testRenderSheet() throws {
        guard let folder = ProcessInfo.processInfo.environment["CORETEND_RENDER_DIR"] else {
            throw XCTSkip("set CORETEND_RENDER_DIR to render the sheet")
        }
        let steps: [SerreLogoState] = [
            .seed,
            SerreLogoState(seedDrop: 0, seedScale: 1, stem: 0.5, firstLeaf: 0, secondLeaf: 0),
            SerreLogoState(seedDrop: 0, seedScale: 1, stem: 1, firstLeaf: 0.5, secondLeaf: 0.2),
            .grown,
        ]
        for scheme in [ColorScheme.light, .dark] {
            let sheet = VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 22) { ForEach(Array(SerreGlyph.allCases.enumerated()), id: \.offset) { SerreIcon($0.element, size: 36) } }
                HStack(spacing: 22) { ForEach(Array(SerreGlyph.allCases.enumerated()), id: \.offset) { SerreIcon($0.element, size: 18) } }
                HStack(spacing: 18) { ForEach(RiskLevel.allCases, id: \.self) { RiskLeaf($0, size: 28) } }
                HStack(spacing: 24) { ForEach(Array(steps.enumerated()), id: \.offset) { SerreLogo(size: 96, frozenAt: $0.element) } }
            }
            .padding(28)
            .foregroundStyle(Palette.ink.color)
            .background(Palette.canvas.color)
            .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: sheet)
            renderer.scale = 2
            // Palette colours resolve against the drawing NSAppearance, not SwiftUI's colorScheme.
            var rendered: NSImage?
            NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance { rendered = renderer.nsImage }
            let image = try XCTUnwrap(rendered)
            let data = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation))?.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("serre-sheet-\(scheme == .dark ? "dark" : "light").png"))
        }
    }
}
