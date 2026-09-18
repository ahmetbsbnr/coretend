// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import DesignSystem

/// The sidebar must follow the user's chosen row size.
///
/// System Settings ▸ Appearance ▸ "Sidebar icon size" is a legibility setting,
/// not a decorative one, and every app using a standard `List` with
/// `.listStyle(.sidebar)` follows it for free. Replacing that `List` with a
/// hand-built sidebar lost the behaviour silently: rows were fixed at 13 pt
/// text and a 14 pt glyph, so someone who enlarged their sidebar icons
/// system-wide got no change at all.
///
/// That is the predictable cost of taking over a system control without first
/// enumerating what the system was doing, and these tests are what makes the
/// replacement honest.
@Suite("Sidebar metrics")
struct SidebarMetricsTests {

    /// An absent key is not size zero. `integer(forKey:)` returns 0 for a key
    /// nobody has ever set, and a fresh account that never touched the setting
    /// must get the system default rather than a zero-height row.
    @Test func anUnsetPreferenceFallsBackToMedium() {
        let suite = "coretend.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(MCSidebarMetrics.read(defaults) == .medium)
    }

    @Test func eachSystemValueMapsToItsSize() {
        let suite = "coretend.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for (value, expected) in [(1, MCSidebarMetrics.Size.small),
                                  (2, .medium), (3, .large)] {
            defaults.set(value, forKey: MCSidebarMetrics.defaultsKey)
            #expect(MCSidebarMetrics.read(defaults) == expected)
        }
    }

    /// A value macOS does not define must not produce a size. Guessing would
    /// mean a future fourth option renders at an arbitrary scale.
    @Test func anUnknownValueFallsBackRatherThanGuessing() {
        let suite = "coretend.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for value in [0, 4, 99, -1] {
            defaults.set(value, forKey: MCSidebarMetrics.defaultsKey)
            #expect(MCSidebarMetrics.read(defaults) == .medium, "value \(value)")
        }
    }

    /// The whole point: every metric must actually change between sizes. A
    /// setting that is read and then ignored is worse than one that is not
    /// read, because it looks handled.
    @Test func everyMetricGrowsWithTheSize() {
        let sizes = MCSidebarMetrics.Size.allCases.sorted { $0.rawValue < $1.rawValue }
        for (smaller, larger) in zip(sizes, sizes.dropFirst()) {
            #expect(larger.textSize > smaller.textSize, "text does not grow")
            #expect(larger.iconSize > smaller.iconSize, "icon does not grow")
            #expect(larger.rowPadding > smaller.rowPadding, "padding does not grow")
            #expect(larger.sectionSize > smaller.sectionSize, "section header does not grow")
        }
    }

    /// The glyph tracks the label rather than scaling independently, so a row
    /// stays a row at every setting instead of becoming an icon with a caption.
    @Test func theGlyphStaysProportionalToTheLabel() {
        for size in MCSidebarMetrics.Size.allCases {
            let ratio = size.iconSize / size.textSize
            #expect(ratio > 0.9 && ratio < 1.25,
                    "\(size): glyph/label ratio \(ratio) is out of proportion")
        }
    }

    /// Large must be large enough to be worth choosing. Someone who picks it
    /// has a legibility reason, and a two-point difference does not answer it.
    @Test func largeIsMeaningfullyLargerThanSmall() {
        #expect(MCSidebarMetrics.Size.large.textSize - MCSidebarMetrics.Size.small.textSize >= 3)
    }
}
