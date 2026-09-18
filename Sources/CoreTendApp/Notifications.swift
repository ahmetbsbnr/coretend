// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// App-wide navigation and presentation requests. Posted from places that
/// cannot hold a reference to the window — menu commands, other modules —
/// and received once, by MainWindow.
extension Notification.Name {
    static let mcNavigate = Notification.Name("mc.navigate")
    static let mcShowOnboarding = Notification.Name("mc.showOnboarding")
    static let mcShowCommandPalette = Notification.Name("mc.showCommandPalette")
    /// Asks the Record to run its CSV export. Posted by File › Export Record.
    static let mcExportRecord = Notification.Name("mc.exportRecord")
    static let mcShowKeyboardShortcuts = Notification.Name("mc.showKeyboardShortcuts")
}
