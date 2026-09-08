// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// LocalizedText — a language-independent description of a user-facing string.
//
// Detectors and the risk model produce these instead of pre-rendered English.
// The app (`DeepScanView`) resolves `key` against `Localizable.strings` and
// substitutes `args` (paths, counts, sizes, tool names) — none of which are
// translated. `DeepScanCore` stays deterministic and UI-language-independent.
//
// A plain-English `fallback` is carried too, for non-localized consumers
// (the QA harness, logs) and as a safety net.

import Foundation

public struct LocalizedText: Sendable, Codable, Hashable {
    /// e.g. "deepscan.reason.dev_build_output"
    public let key: String
    /// Ordered substitution values. NOT translated (paths, counts, tool names).
    public let args: [String]
    /// Plain English, already substituted. Used when no string table is available.
    public let fallback: String

    public init(_ key: String, args: [String] = [], fallback: String) {
        self.key = key
        self.args = args
        self.fallback = fallback
    }

    /// Convenience for call sites that only have English (kept minimal).
    public static func literal(_ english: String) -> LocalizedText {
        LocalizedText("deepscan.literal", args: [english], fallback: english)
    }
}
