// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import SwiftUI
@testable import DesignSystem

@Suite("Locale-aware byte formatting")
struct ByteFormattingTests {

    /// Restore the shared locale after each case so suites stay independent.
    private func withLocale(_ locale: Locale, _ body: () -> Void) {
        let previous = MCFormatting.locale
        MCFormatting.locale = locale
        defer { MCFormatting.locale = previous }
        body()
    }

    @Test func englishUsesAPeriodDecimalAndAsciiUnits() {
        withLocale(Locale(identifier: "en_US")) {
            let g = mcFormatBytes(3_900_000_000)
            #expect(g.contains("3.9"))
            #expect(g.hasSuffix("GB"))
            let m = mcFormatBytes(664_700_000)
            #expect(m.contains("664.7"))
            #expect(m.hasSuffix("MB"))
        }
    }

    @Test func frenchUsesACommaDecimalAndFrenchUnits() {
        withLocale(Locale(identifier: "fr_FR")) {
            let g = mcFormatBytes(3_900_000_000)
            #expect(g.contains("3,9"))
            #expect(!g.contains("3.9"))       // no period decimal
            #expect(g.hasSuffix("Go"))
            #expect(!g.contains("GB"))

            #expect(mcFormatBytes(3_750_000_000).contains("3,75"))
            #expect(mcFormatBytes(1_430_000_000).contains("1,43"))

            let m = mcFormatBytes(664_700_000)
            #expect(m.contains("664,7"))
            #expect(m.hasSuffix("Mo"))
        }
    }

    @Test func theUnitIsNeverAHandConcatenatedAsciiString() {
        // Regression guard: reverting to `"\(x) GB"` fails here in French.
        withLocale(Locale(identifier: "fr_FR")) {
            #expect(!mcFormatBytes(2_000_000_000).contains("GB"))
            #expect(!mcFormatBytes(2_000_000).contains("MB"))
        }
    }

    @Test func changingTheSharedLocaleChangesEveryFutureFormat() {
        let previous = MCFormatting.locale
        defer { MCFormatting.locale = previous }
        MCFormatting.locale = Locale(identifier: "en_US")
        #expect(mcFormatBytes(3_900_000_000).contains("3.9"))
        MCFormatting.locale = Locale(identifier: "fr_FR")
        #expect(mcFormatBytes(3_900_000_000).contains("3,9"))
    }
}

@Suite("MCFlowLayout — wrapping geometry")
struct MCFlowLayoutTests {
    private func run(_ sizes: [CGSize], width: CGFloat, spacing: CGFloat = 8) -> (origins: [CGPoint], size: CGSize) {
        MCFlowLayout.arrange(sizes: sizes, maxWidth: width, spacing: spacing, lineSpacing: spacing)
    }

    @Test func fitsOnOneLineWhenThereIsRoom() {
        let box = CGSize(width: 100, height: 20)
        let out = run([box, box, box], width: 420)
        #expect(out.origins.allSatisfy { $0.y == 0 })
        #expect(abs(out.size.height - 20) < 0.5)
    }

    @Test func wrapsToANewLineWhenTheNextChildWouldOverflow() {
        let box = CGSize(width: 100, height: 20)
        let out = run([box, box, box, box], width: 210)
        #expect(out.size.height > 20)
        #expect(out.origins.contains { $0.y > 0 })
        #expect(out.size.width <= 210 + 0.5)
    }

    @Test func aSingleChildWiderThanTheBoundStillDoesNotWrap() {
        let out = run([CGSize(width: 80, height: 18)], width: 40)
        #expect(out.origins == [.zero])
        #expect(abs(out.size.height - 18) < 0.5)
    }

    @Test func emptyInputIsZeroSized() {
        let out = run([], width: 300)
        #expect(out.origins.isEmpty)
        #expect(out.size.height == 0)
    }
}
