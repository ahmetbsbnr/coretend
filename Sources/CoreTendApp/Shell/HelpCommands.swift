// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

// Help menu.

import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence

struct CoreTendHelpCommands: Commands {
    private let site = URL(string: "https://coretend.ahmetbsbnr.com")!
    private let repository = URL(string: "https://github.com/ahmetbsbnr/coretend")!

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            // A SettingsLink rather than a navigation: the Settings window is
            // where updates live now, and SwiftUI opens it for us rather than
            // us reaching for a stringly-typed selector.
            SettingsLink {
                Text(L("updates.check_now"))
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
        }
        CommandGroup(after: .toolbar) {
            Button(L("palette.open")) {
                NotificationCenter.default.post(name: .mcShowCommandPalette, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command])
        }
        // Every item here was a hardcoded English string. The app ships in
        // French and English and localizes 540 keys; the Help menu — the one
        // menu a confused user opens — was not among them.
        CommandGroup(replacing: .help) {
            Button(L("menu.help.app")) {
                NSWorkspace.shared.open(site.appending(path: "support#documentation"))
            }
            Button(L("menu.help.install")) {
                NSWorkspace.shared.open(site.appending(path: "support"))
            }
            // Was: open the website's support page, which lists no shortcuts
            // at all. A menu item that names a thing and does not show it
            // costs the user the trip to a browser to find that out.
            Button(L("menu.help.shortcuts")) {
                NotificationCenter.default.post(name: .mcShowKeyboardShortcuts, object: nil)
            }
            .keyboardShortcut("/", modifiers: [.command])
            Divider()
            Button(L("menu.help.report")) {
                NSWorkspace.shared.open(repository.appending(path: "issues"))
            }
            Button(L("menu.help.security")) {
                NSWorkspace.shared.open(site.appending(path: "support#security"))
            }
            Button(L("menu.help.about")) {
                NSWorkspace.shared.open(site.appending(path: "en/"))
            }
        }
    }
}

/// Menu-bar icon content. Polls at a slow, low-idle-cost cadence (independent
/// of whether the panel is open) purely to know whether an attention badge
/// should show — never duplicates the panel's metric collection pipeline.
