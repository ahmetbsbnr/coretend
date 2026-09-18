// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

/// Liquid Glass, applied only where Apple says it belongs.
///
/// macOS 26 introduced `glassEffect`, and Apple's guidance is narrow and
/// specific: glass is for **the navigation layer that floats above content**.
/// Not content, not full-screen backgrounds, not scrollable views, and never
/// glass on top of glass — a glass surface cannot sample another glass surface,
/// so stacking them produces a muddy rectangle rather than depth.
///
/// CoreTend therefore uses it in exactly two places: the sidebar, and the
/// pinned sub-navigation bar. Both are chrome the content scrolls beneath.
/// Cards, rows, panels and empty states stay opaque — they are content, and
/// making them translucent would make an app about reading numbers harder to
/// read.
///
/// ## Availability
///
/// The deployment target is macOS 14, so every call is gated. Below macOS 26
/// the surface falls back to the material it used before, which is not a
/// degraded experience — it is what the app looked like, and it looked fine.
///
/// ## Reduce Transparency
///
/// Glass is transparency. Someone who has turned that setting on has said, at
/// the system level, that translucent chrome is hard for them to read. The
/// effect is disabled for them and an opaque surface is used instead —
/// `glassEffect`'s own `isEnabled` parameter exists for exactly this.
public extension View {
    /// Applies Liquid Glass to a navigation-layer surface on macOS 26+.
    ///
    /// - Parameters:
    ///   - shape: The glass shape. Chrome that meets a window edge should pass
    ///     a rectangle; a floating element should pass its own rounded shape.
    ///   - fallback: The opaque colour used below macOS 26, and whenever
    ///     Reduce Transparency is on.
    func mcNavigationGlass<S: Shape>(in shape: S, fallback: Color) -> some View {
        modifier(MCNavigationGlassModifier(shape: shape, fallback: fallback))
    }
}

private struct MCNavigationGlassModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    let fallback: Color

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(fallback, in: shape)
        }
    }
}

/// Whether this build is running somewhere Liquid Glass exists.
///
/// Exposed so a test can assert the gating is present rather than inferring it,
/// and so a diagnostic report can say which rendering path a user is on when
/// they describe what they are seeing.
public enum MCGlassAvailability {
    public static var isSupported: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    /// The minimum macOS version that has `glassEffect`. Stated once so the
    /// gate and its documentation cannot drift apart.
    public static let minimumMajorVersion = 26
}
