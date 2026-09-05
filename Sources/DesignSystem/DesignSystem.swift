// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import Foundation

// CoreTend design system — Porcelain / Slate / Teal, shared with the portfolio.
// Tokens: Tokens.swift / Colors.swift / Typography.swift
// Brand:  CoreBloom.swift   Components: Components.swift

/// Card container used across module screens.
/// The surface is deliberately solid rather than glassy: Porcelain / Slate /
/// Teal should read as a product interface, not a translucent marketing panel.
public struct MCCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        // Read directly (not via @Environment — macOS SwiftUI has no
        // accessibilityIncreaseContrast environment key); Observation
        // tracks this read and re-renders the card when the system
        // setting changes, same effect as an environment value.
        let increaseContrast = MCAccessibilityState.shared.increaseContrast
        let shape = RoundedRectangle(cornerRadius: MCRadius.card)
        content
            .padding(MCSpacing.md)
            .background(shape.fill(MCColor.elevatedBackground))
            .overlay(shape.strokeBorder(MCColor.separator.opacity(increaseContrast ? 1.0 : 0.8),
                                         lineWidth: increaseContrast ? 1.5 : 1))
            .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 2)
    }
}

/// The locale CoreTend formats numbers, byte counts and dates in.
///
/// The app has an *in-app* language override (Settings ▸ Language) that does
/// not change `Locale.current`. Byte counts formatted against the process
/// locale therefore showed "3.9 GB" (period, "GB") even for a user who chose
/// French. `CoreTendApp` sets this to match the chosen language at launch and
/// on every change, and every byte value in the product goes through
/// `mcFormatBytes`, so the whole UI stays in one locale.
public enum MCFormatting {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _locale: Locale = .autoupdatingCurrent

    public static var locale: Locale {
        get { lock.withLock { _locale } }
        set { lock.withLock { _locale = newValue } }
    }
}

/// Human-readable, locale-aware byte formatting shared by every view.
///
/// Uses `ByteCountFormatStyle` (which honours a `locale`), not
/// `ByteCountFormatter` (which does not): French renders "3,9 Go" / "664,7 Mo",
/// English "3.9 GB" / "664.7 MB". Never concatenate a unit string by hand.
public func mcFormatBytes(_ bytes: Int64) -> String {
    bytes.formatted(.byteCount(style: .file).locale(MCFormatting.locale))
}
