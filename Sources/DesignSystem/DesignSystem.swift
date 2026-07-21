import SwiftUI

// MacCare Local design system — Orbital Ecology.
// Tokens: Tokens.swift / Colors.swift / Typography.swift
// Brand:  CoreBloom.swift   Components: Components.swift

/// Card container used across all module screens.
/// Falls back to an opaque surface under Reduce Transparency, and a
/// stronger, wider border under Increase Contrast (the default 0.6-opacity
/// hairline is deliberately subtle and fails to read as a boundary once the
/// system's contrast preference says subtle isn't wanted).
public struct MCCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
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
            .background {
                if reduceTransparency {
                    shape.fill(MCColor.elevatedBackground)
                } else {
                    shape.fill(.regularMaterial)
                        .overlay(shape.fill(Color.primary.opacity(0.035)))
                }
            }
            .overlay(shape.strokeBorder(MCColor.separator.opacity(increaseContrast ? 1.0 : 0.6),
                                         lineWidth: increaseContrast ? 1.5 : 1))
    }
}

/// Human-readable byte formatting shared by all views.
public func mcFormatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
