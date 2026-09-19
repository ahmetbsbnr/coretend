// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
@testable import DesignSystem

/// Every pairing, in every appearance, against the floor it actually has to
/// clear.
///
/// A light palette that has not been measured is an intention, not a palette.
/// This runs the same check across four combinations — light, dark, and the
/// Increase Contrast variant of each — because a token only edited in one of
/// them is the normal way a theme rots.
///
/// The floors are WCAG 2.1: 4.5:1 for body text, 3:1 for large text and for
/// the non-text parts of a control that carry meaning.
@Suite("Palette contrast in every appearance")
struct AppearancePaletteTests {

    private struct Mode: CustomStringConvertible {
        let dark: Bool, highContrast: Bool
        var description: String {
            "\(dark ? "dark" : "light")\(highContrast ? " + increase contrast" : "")"
        }
    }
    private static let modes = [
        Mode(dark: false, highContrast: false), Mode(dark: true, highContrast: false),
        Mode(dark: false, highContrast: true), Mode(dark: true, highContrast: true),
    ]

    private func ratio(_ fg: MCPaletteColor, on bg: MCPaletteColor, _ mode: Mode) -> Double {
        MCColor.contrastRatio(fg.value(dark: mode.dark, highContrast: mode.highContrast),
                              bg.value(dark: mode.dark, highContrast: mode.highContrast))
    }

    private func check(_ name: String, _ fg: MCPaletteColor,
                       on bg: MCPaletteColor, atLeast floor: Double) {
        for mode in Self.modes {
            let r = ratio(fg, on: bg, mode)
            #expect(r >= floor,
                    "\(name) in \(mode): \(String(format: "%.2f", r)):1, needs \(floor):1")
        }
    }

    /// Body text on each of the three surfaces it is allowed to sit on.
    @Test func textClearsTheBodyFloorEverywhere() {
        for (surfaceName, surface) in [("ground", MCPalette.ground),
                                       ("sunken", MCPalette.sunken),
                                       ("raised", MCPalette.raised),
                                       ("raisedHigh", MCPalette.raisedHigh)] {
            check("primary on \(surfaceName)", MCPalette.textPrimary, on: surface, atLeast: 4.5)
            check("secondary on \(surfaceName)", MCPalette.textSecondary, on: surface, atLeast: 4.5)
            check("tertiary on \(surfaceName)", MCPalette.textTertiary, on: surface, atLeast: 4.5)
        }
    }

    /// The tertiary tier used to be documented as deliberately below the floor.
    /// It was then used for the Record's timestamps, where the time is the only
    /// carrier of meaning. The escape hatch is gone; this is what keeps it gone.
    @Test func thereIsNoTierBelowTheFloor() {
        for mode in Self.modes {
            #expect(ratio(MCPalette.textTertiary, on: MCPalette.ground, mode) >= 4.5)
        }
    }

    /// Signal colours have to be readable as text, because each of them labels
    /// something — a state pill, an error line, a caution note.
    @Test func signalColoursAreReadableAsText() {
        for (name, colour) in [("teal", MCPalette.teal), ("amber", MCPalette.amber),
                               ("coral", MCPalette.coral), ("green", MCPalette.green),
                               ("slate", MCPalette.slate)] {
            check("\(name) on ground", colour, on: MCPalette.ground, atLeast: 4.5)
            check("\(name) on raised", colour, on: MCPalette.raised, atLeast: 4.5)
        }
    }

    /// The label on a filled accent control, measured on the fill it sits on.
    /// White on the dark teal is 1.87:1, and shipped.
    @Test func theAccentLabelIsLegibleOnItsOwnFill() {
        check("onAccent on teal", MCPalette.onAccent, on: MCPalette.teal, atLeast: 4.5)
    }

    /// A divider is not text, but it has to be visible or it is not a divider.
    @Test func bordersSeparate() {
        for (name, surface) in [("ground", MCPalette.ground), ("raised", MCPalette.raised)] {
            check("border on \(name)", MCPalette.border, on: surface, atLeast: 1.25)
        }
    }

    /// Increase Contrast has to actually increase contrast. A variant copied
    /// from the base value makes the setting a silent no-op, which is the
    /// failure mode that looks like success.
    @Test func increaseContrastRaisesEveryTextPairing() {
        for (name, fg) in [("primary", MCPalette.textPrimary),
                           ("secondary", MCPalette.textSecondary),
                           ("tertiary", MCPalette.textTertiary)] {
            for dark in [true, false] {
                let normal = ratio(fg, on: MCPalette.ground, Mode(dark: dark, highContrast: false))
                let raised = ratio(fg, on: MCPalette.ground, Mode(dark: dark, highContrast: true))
                let label = dark ? "dark" : "light"
                #expect(raised > normal,
                        "\(name) (\(label)): increase contrast gives \(raised):1 versus \(normal):1")
            }
        }
    }

    /// The elevation ladder must be a ladder. If two steps resolve to the same
    /// value, a card on a panel reads as one flat field.
    @Test func elevationStepsAreDistinct() {
        for mode in Self.modes {
            let steps = [MCPalette.ground, MCPalette.sunken,
                         MCPalette.raised, MCPalette.raisedHigh]
                .map { $0.value(dark: mode.dark, highContrast: mode.highContrast) }
            #expect(Set(steps).count == steps.count, "elevation collapsed in \(mode): \(steps)")
        }
    }
}

/// A status pill is a solid fill, not a tint of its own ink.
///
/// Five screens built pills as `ink.opacity(0.18)` behind the same ink. That
/// construction measures 3.67:1 at its worst (slate on a dark raised surface),
/// and the opacity that would clear 4.5:1 is 0.05 — which is not a pill. A
/// solid semantic fill with the appearance's on-accent ink measures 5.19:1 at
/// worst across every state in both appearances.
@Suite("Status tags are legible on their own fill")
struct StatusTagContrastTests {
    private func ratio(_ ink: MCPaletteColor, on fill: MCPaletteColor, dark: Bool, contrast: Bool) -> Double {
        MCColor.contrastRatio(ink.value(dark: dark, highContrast: contrast),
                              fill.value(dark: dark, highContrast: contrast))
    }

    @Test func everyToneCarriesItsLabel() {
        let tones: [(String, MCPaletteColor)] = [
            ("success", MCPalette.green), ("attention", MCPalette.amber),
            ("failure", MCPalette.coral), ("inert", MCPalette.slate),
            ("accent", MCPalette.teal),
        ]
        for (name, fill) in tones {
            for dark in [true, false] {
                for contrast in [true, false] {
                    let r = ratio(MCPalette.onAccent, on: fill, dark: dark, contrast: contrast)
                    #expect(r >= 4.5,
                            "\(name) pill in \(dark ? "dark" : "light")\(contrast ? " + contrast" : ""): \(r):1")
                }
            }
        }
    }

    /// The construction that was replaced, kept as a measurement so nobody
    /// reintroduces it believing it works.
    @Test func tintingALabelWithItsOwnColourWouldNotWork() {
        let ink = MCPalette.slate.dark
        let surface = MCPalette.raised.dark
        func blend(_ a: Double) -> UInt32 {
            var out: UInt32 = 0
            for shift in [16, 8, 0] {
                let f = Double((ink >> UInt32(shift)) & 0xFF), b = Double((surface >> UInt32(shift)) & 0xFF)
                out |= UInt32((f * a + b * (1 - a)).rounded()) << UInt32(shift)
            }
            return out
        }
        #expect(MCColor.contrastRatio(ink, blend(0.18)) < 4.5)
    }
}
