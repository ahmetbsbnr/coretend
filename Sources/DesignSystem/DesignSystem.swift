// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

// CoreTend design system — "Instrument": graphite neutrals, one teal signal.
// Tokens: Tokens.swift / Colors.swift / Typography.swift
// Brand:  CoreBloom.swift   Components: Components.swift / Primitives.swift

/// Panel container used across module screens.
/// Flat by design: a solid panel surface and a hairline border. Depth comes
/// from the canvas → panel surface step, never from a drop shadow or glass.
public struct MCCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    public init(padding: CGFloat = MCSpacing.md, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }

    public var body: some View {
        // Read directly (not via @Environment — macOS SwiftUI has no
        // accessibilityIncreaseContrast environment key); Observation
        // tracks this read and re-renders the card when the system
        // setting changes, same effect as an environment value.
        let increaseContrast = MCAccessibilityState.shared.increaseContrast
        let shape = RoundedRectangle(cornerRadius: MCRadius.card)
        content
            .padding(padding)
            .background(shape.fill(MCColor.elevatedBackground))
            .overlay(shape.strokeBorder(increaseContrast ? MCColor.rule : MCColor.separator,
                                         lineWidth: increaseContrast ? 1.5 : 1))
    }
}

/// Human-readable byte formatting shared by all views.
public func mcFormatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
