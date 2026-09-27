import AppKit
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
