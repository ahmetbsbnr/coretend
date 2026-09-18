// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppKit

/// Opens the Settings scene from a place that is not a view.
///
/// `SettingsLink` is the supported way and is used everywhere it can be — the
/// Help menu, the menu-bar panel, the update badge. The command palette cannot
/// use it: its entries are closures, invoked after the palette has already
/// dismissed itself, so there is no view to be a link.
///
/// `showSettingsWindow:` is the responder-chain action the `Settings` scene
/// installs. It is the only way to reach that window from outside a view, and
/// it is a stringly-typed selector, so it is isolated here and guarded: a
/// future macOS that renames it makes this do nothing, which is a palette entry
/// that fails to open a window rather than a process that stops.
@MainActor
enum MCSettingsWindow {
    /// The selector name has changed once already — it was
    /// `showPreferencesWindow:` before macOS 13 — so both are tried, newest
    /// first.
    static let candidateSelectors = ["showSettingsWindow:", "showPreferencesWindow:"]

    @discardableResult
    static func open() -> Bool {
        for name in candidateSelectors {
            let selector = Selector((name))
            if NSApp.sendAction(selector, to: nil, from: nil) { return true }
        }
        return false
    }
}
