// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// Every command the app is *for* belongs in the menu bar.
///
/// The HIG: "Use the menu bar to give people easy access to all the commands
/// they need to do things in your app." CoreTend's menu bar had nine items and
/// not one of them was scanning, pausing, cancelling or moving between modules
/// — the things a person opens it to do. Those existed only as buttons inside
/// windows.
///
/// That matters beyond tidiness. The menu bar is where a keyboard-driven user
/// looks, where Help ▸ Search finds a command by name, and where macOS lets
/// someone assign their own shortcut in System Settings. A command that exists
/// only as a button has none of that.
@Suite("Menu commands")
struct MenuCommandTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Every module is reachable from the Go menu. The first version of this
    /// capped the *list* at nine to match the available digits, which quietly
    /// dropped Activity out of the menu bar entirely — the opposite of the
    /// point.
    @Test func everyModuleIsListedInTheGoMenu() throws {
        let text = try source("Sources/CoreTendApp/MenuCommands.swift")
        #expect(text.contains("SidebarGroup.visibleModules.enumerated()"))
        #expect(!text.contains("visibleModules.prefix(9)"),
                "the Go menu caps its list rather than its shortcuts")
        #expect(text.contains("index < 9"), "the shortcut cap is gone")
    }

    /// Eight destinations, nine digits: every module now has a shortcut, and
    /// the cap in MenuCommands is a guard for the day a ninth-plus module is
    /// added rather than something a user can currently hit. This used to
    /// assert the opposite (ten modules, so the cap was load-bearing); the
    /// architecture pass that merged Activity into the Record and folded three
    /// lenses into Explore is what changed it.
    @Test func everyModuleHasADigit() {
        #expect(SidebarGroup.visibleModules.count <= 9,
                "a module past the ninth has no ⌘-digit; decide whether that is acceptable")
    }

    /// Scan commands cross a boundary commands cannot hold a reference across,
    /// so they post. Each name must exist, or a menu item is a no-op.
    @Test func theScanCommandNotificationsExist() {
        #expect(Notification.Name.mcStartScan.rawValue == "mc.startScan")
        #expect(Notification.Name.mcPauseOrResumeScan.rawValue == "mc.pauseOrResumeScan")
        #expect(Notification.Name.mcCancelScan.rawValue == "mc.cancelScan")
    }

    /// Every screen with scan controls also answers the menu, or a module gains
    /// a button and silently lacks its command.
    @Test func everyScanScreenAnswersTheMenu() throws {
        for file in ["CleanupView.swift", "DuplicatesView.swift", "MyClutterView.swift"] {
            let text = try source("Sources/CoreTendApp/\(file)")
            guard text.contains("MCScanControls(") else { continue }
            #expect(text.contains(".scanCommands("),
                    "\(file) has scan controls but does not answer the Scan menu")
        }
    }

    /// Pause and Resume are one item, not two that are mutually disabled: the
    /// scan is either running or paused, and a menu showing both with one
    /// greyed out asks the reader to work out which.
    @Test func pauseAndResumeAreOneToggle() throws {
        let text = try source("Sources/CoreTendApp/MenuCommands.swift")
        #expect(text.contains("menu.scan.pause_resume"))
        #expect(!text.contains("menu.scan.resume"), "pause and resume are separate items again")
    }

    @Test func theMenuLabelsAreLocalised() throws {
        for lang in ["Base", "fr"] {
            let url = root.appendingPathComponent(
                "Sources/CoreTendApp/Resources/\(lang).lproj/Localizable.strings")
            let table = try PropertyListSerialization.propertyList(
                from: try Data(contentsOf: url), format: nil) as? [String: Any] ?? [:]
            for key in ["menu.go", "menu.scan", "menu.scan.start",
                        "menu.scan.pause_resume", "menu.scan.cancel"] {
                #expect(table[key] != nil, "\(lang) is missing \(key)")
            }
        }
    }
}

/// The shortcuts screen is the only place a person can read the whole set, so
/// it has to match the menus rather than approximate them.
///
/// It listed "↩ start scan", "P pause", "R resume" — the bare keys a scan
/// screen answers while it is focused — as if they were app-wide, and omitted
/// every ⌘-shortcut the menus actually bind: ⌘R, ⌘P, ⌘., ⌘1–⌘8, ⌘/, ⌃⌘S, ⇧⌘E.
@Suite("The shortcuts screen matches the menus")
struct ShortcutCatalogueTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    @Test func everyMenuShortcutIsDocumented() throws {
        let listed = KeyboardShortcutCatalogue.groups
            .flatMap(\.shortcuts).map(\.keys).joined(separator: " ")
        for keys in ["⌘R", "⌘P", "⌘.", "⌘K", "⌘/", "⌃⌘S", "⇧⌘E", "⇧⌘U", "⌘,"] {
            #expect(listed.contains(keys), "the shortcuts screen omits \(keys)")
        }
        #expect(listed.contains("⌘1"), "the shortcuts screen omits the Go shortcuts")
    }

    /// Every documented shortcut names a real string. A key typo here shows a
    /// raw key to the one audience guaranteed to be reading carefully.
    @Test func everyDocumentedShortcutHasALabel() throws {
        let defined = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: root.appendingPathComponent(
                "Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings")),
            format: nil) as? [String: String] ?? [:]
        for group in KeyboardShortcutCatalogue.groups {
            #expect(defined[group.titleKey] != nil, "no string for \(group.titleKey)")
            for shortcut in group.shortcuts {
                #expect(defined[shortcut.titleKey] != nil, "no string for \(shortcut.titleKey)")
            }
        }
    }
}
