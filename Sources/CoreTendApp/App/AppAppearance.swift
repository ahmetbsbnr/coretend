// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

// Appearance policy: follow the system; captures may pin one in test mode.

import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence

@MainActor
/// CoreTend follows the Mac's appearance.
///
/// It used to pin `.darkAqua` and ship a single palette, on the reasoning that
/// colour is the loudest thing an app says about itself and CoreTend should
/// say one thing. That reasoning survives — and it is satisfied by owning both
/// palettes, derived from the same brand hues, rather than by refusing one of
/// them. See `MCPalette`: Light is warm paper and a deep teal, not
/// `NSColor.windowBackgroundColor`.
///
/// Pinning also meant a user who runs their Mac in Light Mode got exactly one
/// window that ignored them, which is not a taste decision made confidently —
/// it is a preference of the app's overriding a preference of its user's.
enum AppAppearance {
    /// Nil: resolve from the system. Every token in `MCPalette` re-resolves at
    /// draw time, so the switch needs no work beyond not fighting it.
    static func apply() {
        // A capture may pin an appearance so a screenshot can say which one it
        // is. Only in test mode; a user never sees this path.
        NSApplication.shared.appearance = CaptureHarness.requestedAppearance
            .map { NSAppearance(named: $0.name) } ?? nil
    }
}
