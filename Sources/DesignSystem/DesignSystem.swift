import SwiftUI

// MacCare Local design system — Orbital Ecology.
// Tokens: Tokens.swift / Colors.swift / Typography.swift
// Brand:  CoreBloom.swift   Components: Components.swift

/// Card container used across all module screens.
/// Falls back to an opaque surface under Reduce Transparency.
public struct MCCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
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
            .overlay(shape.strokeBorder(MCColor.separator.opacity(0.6), lineWidth: 1))
    }
}

/// Human-readable byte formatting shared by all views.
public func mcFormatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
