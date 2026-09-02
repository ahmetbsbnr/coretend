// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppKit
import Observation

/// Bridges macOS system accessibility settings that SwiftUI does not expose
/// as @Environment keys on macOS (unlike Reduce Motion/Transparency/
/// Differentiate Without Color, which are real SwiftUI environment values).
/// "Increase Contrast" is AppKit-only (NSWorkspace); this makes it usable
/// the same way — read `MCAccessibilityState.shared.increaseContrast`
/// directly in a view's `body` and SwiftUI's Observation tracking re-renders
/// that view when the system setting changes, no environment plumbing needed.
@MainActor
@Observable
public final class MCAccessibilityState {
    public static let shared = MCAccessibilityState()

    public private(set) var increaseContrast: Bool

    private init() {
        increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // queue: .main guarantees this runs on the main thread, but the
            // closure type itself isn't @MainActor — hop explicitly so the
            // isolated mutation below is statically sound under Swift 6.
            Task { @MainActor in
                self?.increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            }
        }
    }
}
