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

    func testTextRolesMeetBodyContrastOnCanvasInBothAppearances() {
        for appearance in Appearance.allCases {
            let canvas = Palette.canvas.value(for: appearance)
            for role in [Palette.ink, Palette.secondaryInk, Palette.accent, Palette.caution, Palette.danger] {
                let ratio = role.value(for: appearance).contrast(with: canvas)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(role.name) in \(appearance) is \(ratio):1")
            }
        }
    }

    func testTextOnAccentFillMeetsBodyContrastInBothAppearances() {
        for appearance in Appearance.allCases {
            let ratio = Palette.onAccent.value(for: appearance).contrast(with: Palette.accent.value(for: appearance))
            XCTAssertGreaterThanOrEqual(ratio, 4.5, "on-accent in \(appearance) is \(ratio):1")
        }
    }

    func testMotionDurationsFollowTheSpecAndReduceMotionRemovesAnimation() {
        // Observatoire spec: view transitions 180–280 ms; quick stays immediate feedback.
        XCTAssertEqual(MotionToken.quick.duration, 0.15)
        XCTAssertEqual(MotionToken.standard.duration, 0.24)
        XCTAssertEqual(MotionToken.gentle.duration, 0.28)
        for token in MotionToken.allCases {
            XCTAssertNil(token.animation(reduceMotion: true))
            XCTAssertNotNil(token.animation(reduceMotion: false))
        }
    }
}
