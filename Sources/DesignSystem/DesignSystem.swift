// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

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
        // One surface implementation for the whole app — see `mcSurface`. This
        // type is now just "a raised surface with standard padding".
        content
            .padding(MCSpacing.md)
            .mcSurface(.raised)
    }
}

/// Human-readable byte formatting shared by all views.
public func mcFormatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
