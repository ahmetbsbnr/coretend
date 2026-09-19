// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

/// A short word naming a state: Reversible, Refused, Failed, Protected.
///
/// The app built these by hand in five places as `ink.opacity(0.18)` behind
/// the same ink. Measured, that construction does not work: the blend sits too
/// close to the ink, and the worst pairing — slate on a dark raised surface —
/// came to 3.67:1. The opacity that would fix it is 0.05, which is not a pill
/// any more. Tinting a label with its own colour is simply the wrong shape.
///
/// A solid semantic fill with the appearance's on-accent ink measures 5.19:1
/// at worst across every state in both appearances, and reads as a badge
/// rather than as a faint smudge.
public struct MCStatusTag: View {
    public enum Tone {
        case success, attention, failure, inert, accent

        var fill: Color {
            switch self {
            case .success: MCTheme.success
            case .attention: MCTheme.warning
            case .failure: MCTheme.danger
            case .inert: MCColor.graphite
            case .accent: MCColor.teal
            }
        }
    }

    private let text: String
    private let tone: Tone

    public init(_ text: String, tone: Tone) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(MCFont.badge)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tone.fill, in: Capsule())
            .foregroundStyle(MCColor.onAccent)
            .accessibilityLabel(text)
    }
}
