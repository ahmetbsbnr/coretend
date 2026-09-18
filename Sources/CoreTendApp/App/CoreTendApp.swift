// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence

/// CoreTend renders in its own appearance, not the system's.
///
/// This is a product decision, not a technical one. The app is a single
/// designed surface — one canvas colour, one elevation ladder, one accent —
/// and every value in `MCColor` is tuned against the Slate ground it was
/// designed on. Following the system light/dark switch meant maintaining two
/// complete palettes, each of which had to independently clear contrast
/// minimums, and shipping a product whose identity changed depending on a
/// setting elsewhere on the Mac.
///
/// What this costs, stated plainly rather than discovered later: a user who
/// runs their Mac in Light appearance now gets one dark window among light
/// ones, and users who prefer light interfaces for visual-comfort reasons
/// have no in-app alternative. The mitigation is that the owned palette is
/// held to a higher contrast bar than the system default would enforce —
/// `DesignSystem` documents the measured ratios — and macOS's own Increase
/// Contrast and Reduce Transparency settings are still honoured, because
/// those are accessibility settings rather than taste settings.
///
/// Forced at launch before any window exists, so no view ever renders in the
/// inherited appearance first and then swaps.
/// Selects the module a test launch opens on, so a visual capture does not have
/// to drive the sidebar through the accessibility API.
///
/// The capture script used to find the sidebar row by walking
/// `outline 1 of scroll area 1 of group 1 of splitter group 1 of …` and calling
/// `select`. That coupled every screenshot to one specific AppKit view
/// hierarchy: replacing the `List` with CoreTend's own sidebar broke every
/// capture at once, and the AX tree is in any case flaky across rapid
/// relaunches — `entire contents` intermittently returns nothing.
///
/// A launch argument is deterministic, has no timing, and survives any future
/// change to how the sidebar is built.
///
/// Gated behind the same validated two-key test marker as the store and
/// filesystem fixtures, so a normal launch can never be steered by an
/// environment variable.
public struct CoreTendApp: App {
    public init() {
        AppAppearance.apply()
    }
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true
    // Same UserDefaults key LocalizationManager reads/writes. Observing it
    // here — not just inside LocalizationManager, which isn't itself
    // Observable — is what makes a language change re-render the whole
    // window immediately rather than only on next launch.
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue

    /// Core Bloom menu-bar template (adapts to menu bar appearance).
    static let menuBarImage: NSImage? = {
        guard let path = Bundle.main.path(forResource: "MenuBarTemplate", ofType: "png"),
              let image = NSImage(contentsOfFile: path) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }()

    public var body: some Scene {
        WindowGroup("CoreTend") {
            MainWindow()
                .frame(minWidth: MCSize.windowMinWidth, minHeight: MCSize.windowMinHeight)
                .id(appLanguageRaw)
        }
        .windowStyle(.automatic)
        // `.frame(minWidth:)` above constrains the *view*, not the window. The
        // window was freely resizable below it, and the view then overflowed —
        // which is what produced a 360pt-wide window whose sidebar rendered
        // its section headers as "ORAGE", "ORE", "STEM" with every icon cut
        // off the left edge. The minimum has to be expressed to the window
        // too, or it is only a suggestion the layout system then has to
        // violate.
        //
        // This is the same failure as the three layout bugs already fixed in
        // the views: something declares a size its container does not honour.
        // Here the container was the window itself.
        .windowResizability(.contentMinSize)
        .defaultSize(width: MCSize.windowDefaultWidth, height: MCSize.windowDefaultHeight)
        .commands {
            CoreTendHelpCommands()
            CoreTendNavigationCommands()
        }

        // Settings is a scene, not a sidebar row.
        //
        // It was module eleven, sitting at the bottom of the sidebar — which
        // the HIG warns against twice over. "Avoid putting critical
        // information or actions at the bottom of a sidebar. People often
        // relocate a window in a way that hides its bottom edge", and that is
        // not theoretical: at the Large sidebar size the row is cut off by the
        // window edge on a 1000 pt window.
        //
        // And no Mac app puts its preferences in a sidebar. ⌘, opens a
        // Settings window; that is where people look, and declaring the scene
        // is what makes the standard menu item appear and the shortcut work
        // without wiring either by hand.
        Settings {
            MCSettingsView()
                .id(appLanguageRaw)
                .frame(minWidth: 620, minHeight: 520)
        }

        MenuBarExtra(isInserted: $menuBarEnabled) {
            MenuBarView()
                .id(appLanguageRaw)
        } label: {
            MenuBarLabel()
            Text(verbatim: "CoreTend")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Official help destinations for builds after 0.9.0. These commands are a
/// source-branch improvement and are not claimed to exist in the tagged
/// 0.9.0 binary.
