// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

// CoreTend design system — Porcelain / Slate / Teal, shared with the portfolio.
// Tokens: Tokens.swift / Colors.swift / Typography.swift
// Brand:  CoreBloom.swift   Components: Components.swift

/// Human-readable byte formatting shared by all views.
public func mcFormatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
