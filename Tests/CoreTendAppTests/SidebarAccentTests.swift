// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp
@testable import DesignSystem

/// The sidebar follows the user's accent, not the brand's.
///
/// An earlier version painted the selection in brand teal, reasoning that the
/// app should own its colour. The HIG's sidebar page, updated 8 June 2026, says
/// the opposite: "When they [change the system accent color], they expect all
/// sidebar icons to appear in that color."
///
/// The green pill that prompted all of this was the system working as designed.
/// The native fix was to make the *icon* follow the accent too, not to take the
/// accent away.
@Suite("Sidebar accent")
struct SidebarAccentTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The seven accents macOS offers, as sRGB. Listed so the wash can be
    /// checked against all of them rather than against whichever one this
    /// machine happens to be set to.
    private let systemAccents: [(String, UInt32)] = [
        ("red", 0xFF5257), ("orange", 0xF7821B), ("yellow", 0xFFC600),
        ("green", 0x62BA46), ("blue", 0x007AFF), ("purple", 0xA550A7),
        ("pink", 0xF74F9E),
    ]

    /// The selected row's label must stay readable on the wash, for every
    /// accent — not just the one the developer happens to use.
    ///
    /// Verified in the running app at four accents (red, green, blue, pink):
    /// 11.95, 10.83, 12.28 and 11.95 to one. This computes the same thing for
    /// all seven without launching anything.
    @Test func theSelectedLabelIsReadableOnEveryAccent() {
        let ground = MCColor.Canonical.sunken
        for (name, accent) in systemAccents {
            let wash = blend(accent, over: ground, alpha: 0.18)
            let ratio = MCColor.contrastRatio(MCColor.Canonical.textPrimary, wash)
            #expect(ratio >= 4.5, "\(name): label on the selection wash is \(ratio):1")
        }
    }

    /// And the accent itself must be visible as the marker and the glyph.
    @Test func theAccentIsVisibleAgainstTheSidebarGround() {
        for (name, accent) in systemAccents {
            let ratio = MCColor.contrastRatio(accent, MCColor.Canonical.sunken)
            #expect(ratio >= 3.0, "\(name) marker on the sidebar ground is \(ratio):1")
        }
    }

    /// The brand teal must not reappear in the sidebar's selection.
    @Test func theSidebarDoesNotForceTheBrandAccent() throws {
        let text = try String(
            contentsOf: root.appendingPathComponent("Sources/CoreTendApp/Sidebar.swift"),
            encoding: .utf8)
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//") && !trimmed.hasPrefix("///") else { continue }
            #expect(!trimmed.contains("MCColor.teal"),
                    "the sidebar forces the brand accent again: \(trimmed)")
        }
        #expect(text.contains("Color.accentColor"))
    }

    /// Teal stays everywhere the app genuinely owns the pixels. If it vanished
    /// from the app entirely, the reversal went too far.
    @Test func theBrandAccentSurvivesOutsideTheSidebar() throws {
        let dir = root.appendingPathComponent("Sources/CoreTendApp")
        let users = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".swift") && $0 != "Sidebar.swift" }
            .filter { try! String(contentsOf: dir.appendingPathComponent($0), encoding: .utf8)
                        .contains("MCColor.teal") }
        #expect(users.count >= 3, "the brand accent has been removed from the app, not just the sidebar")
    }

    /// Simple source-over composite, which is what `.opacity` on a fill does.
    private func blend(_ top: UInt32, over bottom: UInt32, alpha: Double) -> UInt32 {
        var out: UInt32 = 0
        for shift in [16, 8, 0] {
            let t = Double((top >> UInt32(shift)) & 0xFF)
            let b = Double((bottom >> UInt32(shift)) & 0xFF)
            let v = UInt32((t * alpha + b * (1 - alpha)).rounded())
            out |= min(v, 255) << UInt32(shift)
        }
        return out
    }
}
