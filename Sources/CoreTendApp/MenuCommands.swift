// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

extension Notification.Name {
    static let mcStartScan = Notification.Name("mc.startScan")
    static let mcPauseOrResumeScan = Notification.Name("mc.pauseOrResumeScan")
    static let mcCancelScan = Notification.Name("mc.cancelScan")
}

/// Navigation and scanning, in the menu bar.
///
/// The HIG on designing for macOS: "Use the menu bar to give people easy access
/// to **all** the commands they need to do things in your app." CoreTend's menu
/// bar had nine items, none of which was a command the app is actually for.
/// Scanning, pausing, cancelling and moving between modules — the things a
/// person opens CoreTend to do — existed only as buttons inside windows.
///
/// That matters beyond tidiness. The menu bar is where a keyboard-driven user
/// looks, where Help ▸ Search finds a command by name, and where macOS lets
/// someone assign their own shortcut in System Settings. A command that exists
/// only as a button has none of that.
///
/// ## Why these post notifications
///
/// Commands live in the `Scene`, outside any window's view hierarchy, so they
/// cannot hold a reference to the scan view model of whichever module is on
/// screen. Posting is the standard way across that boundary, and it is what
/// `.mcNavigate` already does.
///
/// Only the visible module receives them: SwiftUI builds the detail column for
/// the current selection and no other, so exactly one scan view model is
/// subscribed at a time. Each handler still guards on its own phase, because
/// "only one exists" is a property of the current routing rather than a
/// guarantee.
struct CoreTendNavigationCommands: Commands {
    var body: some Commands {
        CommandMenu(L("menu.go")) {
            // Every module is listed. Only the first nine get ⌘1…⌘9, because
            // that is how many digits there are — and the cap applies to the
            // *shortcut*, not to the item. Capping the list was the first
            // version of this and it quietly dropped Activity out of the menu
            // bar entirely, which is the opposite of what this menu is for.
            ForEach(Array(SidebarGroup.visibleModules.enumerated()), id: \.element) { index, module in
                let item = Button(module.label) {
                    NotificationCenter.default.post(name: .mcNavigate, object: module)
                }
                if index < 9 {
                    item.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                } else {
                    item
                }
            }
        }

        CommandMenu(L("menu.scan")) {
            Button(L("menu.scan.start")) {
                NotificationCenter.default.post(name: .mcStartScan, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            // One item that toggles, not two that are mutually disabled: the
            // scan is either running or paused, and a menu showing both with
            // one greyed out asks the reader to work out which.
            Button(L("menu.scan.pause_resume")) {
                NotificationCenter.default.post(name: .mcPauseOrResumeScan, object: nil)
            }
            .keyboardShortcut("p", modifiers: .command)

            Button(L("menu.scan.cancel")) {
                NotificationCenter.default.post(name: .mcCancelScan, object: nil)
            }
            .keyboardShortcut(".", modifiers: .command)
        }
    }
}

/// Wires a scan screen to the Scan menu.
///
/// One declaration per screen, mirroring `MCScanControls`, so a module cannot
/// gain a button and forget the menu item or the reverse.
extension View {
    func scanCommands(start: @escaping () -> Void,
                      pauseOrResume: @escaping () -> Void,
                      cancel: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .mcStartScan)) { _ in start() }
            .onReceive(NotificationCenter.default.publisher(for: .mcPauseOrResumeScan)) { _ in
                pauseOrResume()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mcCancelScan)) { _ in cancel() }
    }
}
