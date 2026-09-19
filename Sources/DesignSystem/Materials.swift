// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import AppKit

/// Real system materials, via AppKit, because SwiftUI cannot express the one
/// that matters here.
///
/// ## Why this exists
///
/// The sidebar already asked for `glassEffect`. It rendered as a flat opaque
/// panel anyway, and the reason was not the glass call — it was that
/// `MainWindow` painted `MCColor.background` across the whole split view.
/// Every vibrancy effect on macOS samples *something*; an opaque fill sitting
/// between the material and everything behind it means there is nothing left
/// to sample, so the material resolves to its own flat tint. The app was
/// paying for a material and drawing a rectangle.
///
/// `glassEffect` would not have been the right call even unblocked. It samples
/// content **inside the window**. A Mac sidebar samples the **desktop behind
/// the window** — that is what makes it read as a layer of the system rather
/// than a panel of the app, and the only API that does it is
/// `NSVisualEffectView` with `.behindWindow` blending. So this is AppKit, on
/// purpose, per the standing instruction to use the framework that produces
/// the correct result rather than the one that keeps the file in SwiftUI.
///
/// ## Reduce Transparency
///
/// Someone who turns that setting on has said at the system level that
/// translucent chrome is hard for them to read. `NSVisualEffectView` does
/// honour it on its own, but it honours it by substituting a **system** opaque
/// colour, which is not CoreTend's ground and lands the sidebar on a grey that
/// belongs to no palette in this app. The view is therefore skipped entirely
/// in that case and an owned opaque surface is used instead — same decision
/// the setting asks for, in the app's own colours.
public struct MCVisualEffect: NSViewRepresentable {
    private let material: NSVisualEffectView.Material
    private let blending: NSVisualEffectView.BlendingMode
    private let emphasized: Bool

    public init(material: NSVisualEffectView.Material,
                blending: NSVisualEffectView.BlendingMode = .behindWindow,
                emphasized: Bool = false) {
        self.material = material
        self.blending = blending
        self.emphasized = emphasized
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .followsWindowActiveState
        view.isEmphasized = emphasized
        return view
    }

    public func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
        view.isEmphasized = emphasized
    }
}

/// A navigation surface: the real material where it is allowed to work, an
/// owned opaque ground where it is not.
private struct MCNavigationSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let material: NSVisualEffectView.Material
    let fallback: Color

    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency {
                fallback
            } else {
                MCVisualEffect(material: material, blending: .behindWindow)
            }
        }
    }
}

public extension View {
    /// The sidebar's surface. `.sidebar` is the material macOS uses for its
    /// own, so CoreTend's sidebar sits at the same depth as every other Mac
    /// app's rather than approximating one.
    func mcSidebarSurface() -> some View {
        modifier(MCNavigationSurface(material: .sidebar,
                                     fallback: MCColor.secondaryBackground))
    }

    /// A surface for chrome that meets the titlebar — the toolbar's underlay
    /// and anything pinned beneath it.
    func mcHeaderSurface() -> some View {
        modifier(MCNavigationSurface(material: .headerView,
                                     fallback: MCColor.secondaryBackground))
    }
}

// MARK: - Window

/// Makes the hosting window able to show a behind-window material at all.
///
/// A window whose `isOpaque` is true composites an opaque backing store before
/// the material ever samples, so `.behindWindow` degrades silently to
/// `.withinWindow` — no error, no warning, just a flat panel. The detail
/// column paints its own opaque canvas, so clearing the window's own
/// background costs nothing there: the only region left unpainted is the one
/// that wants the material.
public struct MCWindowConfigurator: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { Self.configure(view.window) }
        return view
    }

    public func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { Self.configure(view.window) }
    }

    static func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        // The toolbar and the sidebar are one surface, with no seam where the
        // titlebar ends. This is what stops the sidebar reading as a panel
        // parked underneath a separate bar.
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
    }
}

public extension View {
    /// Applies `MCWindowConfigurator` without affecting layout.
    func mcConfigureWindow() -> some View {
        background(MCWindowConfigurator().frame(width: 0, height: 0))
    }
}

// MARK: - Accent ink

/// The ink that stays legible on a filled accent.
///
/// A macOS sidebar selection is a solid fill in the user's accent colour, and
/// the user's accent can be Yellow. White on Yellow measures about 1.6:1 —
/// unreadable, and not fixable by choosing a nicer white. The ink is therefore
/// chosen from the accent's own luminance at draw time, which is what makes a
/// solid selection safe across all seven system accents plus any custom one.
public enum MCAccentInk {
    /// Relative luminance per WCAG, from the accent as it resolves right now.
    public static func ink(on accent: NSColor) -> Color {
        guard let rgb = accent.usingColorSpace(.sRGB) else { return .white }
        func channel(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channel(rgb.redComponent)
            + 0.7152 * channel(rgb.greenComponent)
            + 0.0722 * channel(rgb.blueComponent)
        // Contrast against white is (1.05)/(L+0.05); against black (L+0.05)/0.05.
        // They cross at L ≈ 0.179, so that is the switch point rather than a
        // guessed midpoint.
        return luminance > 0.179 ? Color.black : Color.white
    }

    /// The ink for the current system accent.
    public static var onCurrentAccent: Color {
        ink(on: NSColor.controlAccentColor)
    }
}
