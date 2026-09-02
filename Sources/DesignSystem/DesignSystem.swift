import SwiftUI

// CoreTend design system — Paper / Ink / Cobalt, shared with the portfolio.
// Tokens: Tokens.swift / Colors.swift / Typography.swift
// Brand:  CoreBloom.swift   Components: Components.swift

/// Card container used across module screens.
/// The surface is deliberately solid rather than glassy: Paper / Ink / Cobalt
/// should read as a product interface, not a translucent marketing panel.
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

/// Human-readable byte formatting shared by all views.
public func mcFormatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
