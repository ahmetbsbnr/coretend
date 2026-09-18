// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// The shortcuts CoreTend actually binds.
///
/// Help ▸ Keyboard Shortcuts used to open the website's support page, which
/// does not list any shortcuts. A menu item that names a thing and then does
/// not show it is worse than no menu item: the user spends the trip to the
/// browser finding out.
///
/// The catalogue is a value rather than a view so a test can assert it against
/// the bindings actually present in the source — a shortcut that is documented
/// here and removed from a view, or added to a view and never documented here,
/// is the failure mode this screen invites.
struct KeyboardShortcut2: Identifiable, Equatable {
    let keys: String
    let titleKey: String
    var id: String { keys + titleKey }
}

enum KeyboardShortcutCatalogue {
    struct Group: Identifiable, Equatable {
        let titleKey: String
        let shortcuts: [KeyboardShortcut2]
        var id: String { titleKey }
    }

    /// Grouped by where the shortcut applies, because "⌘K" and "P" are not the
    /// same kind of thing: one works anywhere, the other only while a scan is
    /// running, and a flat list hides that distinction.
    static let groups: [Group] = [
        Group(titleKey: "shortcuts.group.app", shortcuts: [
            KeyboardShortcut2(keys: "⌘K", titleKey: "palette.open"),
            KeyboardShortcut2(keys: "⇧⌘U", titleKey: "updates.check_now"),
            KeyboardShortcut2(keys: "⌘,", titleKey: "menubar.settings"),
            KeyboardShortcut2(keys: "⌘W", titleKey: "shortcuts.close_window"),
            KeyboardShortcut2(keys: "⌘Q", titleKey: "menubar.quit"),
        ]),
        Group(titleKey: "shortcuts.group.scan", shortcuts: [
            KeyboardShortcut2(keys: "↩", titleKey: "shortcuts.start_scan"),
            KeyboardShortcut2(keys: "P", titleKey: "common.pause"),
            KeyboardShortcut2(keys: "R", titleKey: "common.resume"),
            KeyboardShortcut2(keys: "⎋", titleKey: "common.cancel"),
        ]),
        Group(titleKey: "shortcuts.group.spacelens", shortcuts: [
            KeyboardShortcut2(keys: "⌘[", titleKey: "shortcuts.go_up"),
            KeyboardShortcut2(keys: "→", titleKey: "shortcuts.descend"),
            KeyboardShortcut2(keys: "⎋", titleKey: "shortcuts.close_preview"),
        ]),
        Group(titleKey: "shortcuts.group.sidebar", shortcuts: [
            KeyboardShortcut2(keys: "↑ ↓", titleKey: "shortcuts.move_module"),
        ]),
    ]

    /// Every localization key this screen renders, so a parity test can check
    /// them without enumerating the structure twice.
    static var allKeys: [String] {
        groups.flatMap { [$0.titleKey] + $0.shortcuts.map(\.titleKey) }
    }
}

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("shortcuts.title")).font(MCFont.pageTitle)
                Spacer()
                Button(L("common.done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("shortcuts.done")
            }
            .padding(MCSpacing.lg)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: MCSpacing.lg) {
                    ForEach(KeyboardShortcutCatalogue.groups) { group in
                        VStack(alignment: .leading, spacing: MCSpacing.xs) {
                            Text(L(group.titleKey))
                                .font(MCFont.sidebarSection)
                                .foregroundStyle(MCColor.textTertiary)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(group.shortcuts) { shortcut in
                                HStack(spacing: MCSpacing.md) {
                                    Text(shortcut.keys)
                                        .font(MCFont.monoBody)
                                        .foregroundStyle(MCColor.teal)
                                        .frame(minWidth: 56, alignment: .leading)
                                    Text(L(shortcut.titleKey))
                                        .foregroundStyle(MCColor.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                // Read as one sentence: "Command K, open the
                                // command palette", not two separate stops.
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(MCSpacing.lg)
            }
        }
        .frame(width: 460, height: 520)
        .background(MCColor.background)
        .accessibilityIdentifier("shortcuts.root")
    }
}
