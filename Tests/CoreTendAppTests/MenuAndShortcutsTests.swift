// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

@Suite("Menus and keyboard shortcuts")
struct MenuAndShortcutsTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    private func strings(_ lang: String) throws -> [String: Any] {
        let url = root.appendingPathComponent("Sources/CoreTendApp/Resources/\(lang).lproj/Localizable.strings")
        return try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url), format: nil) as? [String: Any] ?? [:]
    }

    /// Every label the Finder menu bar shows must come from the strings table.
    ///
    /// All six Help items shipped as hardcoded English — in an app that
    /// localizes 540 keys and ships in French. The Help menu is the one menu a
    /// confused user opens, so it was the worst possible place for it, and no
    /// test looked at menus at all.
    @Test func noMenuLabelIsHardcoded() throws {
        let text = try source("Sources/CoreTendApp/CoreTendApp.swift")
        // Only the Commands section: elsewhere in this file, a literal may be
        // a notification name or an identifier.
        guard let start = text.range(of: "struct CoreTendHelpCommands"),
              let end = text.range(of: "/// Menu-bar icon content")
        else {
            Issue.record("could not locate the commands section — this test needs updating")
            return
        }
        let commands = String(text[start.lowerBound..<end.lowerBound])
        for line in commands.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("Button(\"") else { continue }
            Issue.record("hardcoded menu label: \(trimmed)")
        }
    }

    /// The shortcuts screen and both strings tables must agree. A shortcut
    /// documented with a missing key renders as its own key name in a window
    /// whose entire purpose is to be read.
    @Test func everyShortcutLabelExistsInBothLanguages() throws {
        let base = try strings("Base"), french = try strings("fr")
        for key in KeyboardShortcutCatalogue.allKeys + ["shortcuts.title", "common.done"] {
            #expect(base[key] != nil, "missing from Base: \(key)")
            #expect(french[key] != nil, "missing from fr: \(key)")
        }
    }

    /// The catalogue must not drift into fiction. Every scan-scoped shortcut it
    /// claims has to correspond to a real binding — the failure mode of a
    /// hand-written shortcut list is that it documents what the app used to do.
    ///
    /// Stronger than it was: the pause/resume/cancel cluster used to be written
    /// out in seven views, so this searched all seven and passed if *any* of
    /// them still had the binding. It now lives in one component, and binding
    /// it more than once would mean two controls competing for the same bare
    /// key — so the count is asserted, not just the presence.
    @Test func documentedScanShortcutsAreBoundExactlyOnce() throws {
        let dir = root.appendingPathComponent("Sources/CoreTendApp")
        var occurrences: [String: [String]] = [:]
        for name in try FileManager.default.contentsOfDirectory(atPath: dir.path)
            where name.hasSuffix(".swift") {
            let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
            for chord in [#"keyboardShortcut("p", modifiers: [])"#,
                          #"keyboardShortcut("r", modifiers: [])"#] {
                let count = text.components(separatedBy: chord).count - 1
                if count > 0 { occurrences[chord, default: []].append(contentsOf: Array(repeating: name, count: count)) }
            }
        }
        for chord in [#"keyboardShortcut("p", modifiers: [])"#,
                      #"keyboardShortcut("r", modifiers: [])"#] {
            let sites = occurrences[chord] ?? []
            #expect(sites.count == 1,
                    "\(chord) is bound \(sites.count) time(s) in \(Set(sites).sorted()) — a bare key must have one owner")
            #expect(sites.first == "ScanControls.swift",
                    "\(chord) moved out of the shared component")
        }
    }

    /// Escape stays per-view: a cancel button belongs to the thing it cancels,
    /// and several screens have their own (a sheet, a preview) beyond the scan.
    @Test func escapeCancelIsStillBound() throws {
        let dir = root.appendingPathComponent("Sources/CoreTendApp")
        var found = false
        for name in try FileManager.default.contentsOfDirectory(atPath: dir.path)
            where name.hasSuffix(".swift") {
            let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
            if text.contains("keyboardShortcut(.cancelAction)") { found = true }
        }
        #expect(found, "Escape (cancel) is documented but bound nowhere")
    }

    /// Space Lens keeps its own navigation shortcut.
    @Test func spaceLensNavigationShortcutIsBound() throws {
        let text = try source("Sources/CoreTendApp/SpaceLensView.swift")
        #expect(text.contains(#"keyboardShortcut("[", modifiers: .command)"#))
    }

    @Test func appWideShortcutsAreBound() throws {
        let app = try source("Sources/CoreTendApp/CoreTendApp.swift")
        #expect(app.contains(#"keyboardShortcut("k", modifiers: [.command])"#))
        #expect(app.contains(#"keyboardShortcut("u", modifiers: [.command, .shift])"#))
        #expect(app.contains(#"keyboardShortcut("/", modifiers: [.command])"#))
    }

    /// Help ▸ Keyboard Shortcuts must open the shortcuts screen. It used to
    /// open the website's support page, which lists no shortcuts at all.
    @Test func helpShortcutsOpensTheShortcutsScreenNotTheWebsite() throws {
        let app = try source("Sources/CoreTendApp/CoreTendApp.swift")
        guard let range = app.range(of: #"Button(L("menu.help.shortcuts"))"#) else {
            Issue.record("the Keyboard Shortcuts menu item is gone")
            return
        }
        let following = String(app[range.upperBound...].prefix(200))
        #expect(following.contains("mcShowKeyboardShortcuts"))
        #expect(!following.contains("NSWorkspace"), "it opens a browser again")
    }

    /// No duplicate key combination inside one scope — two actions on one
    /// chord means one of them silently never fires.
    @Test func noScopeBindsTheSameChordTwice() {
        for group in KeyboardShortcutCatalogue.groups {
            let keys = group.shortcuts.map(\.keys)
            #expect(Set(keys).count == keys.count, "duplicate chord in \(group.titleKey): \(keys)")
        }
    }
}

/// Settings is a scene, not a sidebar row.
@Suite("Settings placement")
struct SettingsPlacementTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func app() throws -> String {
        try String(contentsOf: root.appendingPathComponent("Sources/CoreTendApp/CoreTendApp.swift"),
                   encoding: .utf8)
    }

    /// Declaring the `Settings` scene is what makes "Settings…" appear in the
    /// app menu with ⌘, bound, without wiring either by hand.
    @Test func theSettingsSceneExists() throws {
        #expect(try app().contains("Settings {"))
    }

    /// It was module eleven, at the bottom of the sidebar — which the HIG warns
    /// against ("People often relocate a window in a way that hides its bottom
    /// edge"), and which was not theoretical: at the Large sidebar size the row
    /// was cut off by the window edge.
    @Test func settingsIsNotAModule() {
        #expect(!ModuleID.allCases.contains { String(describing: $0) == "settings" })
        for group in SidebarGroup.all {
            #expect(!group.modules.contains { String(describing: $0) == "settings" })
        }
    }

    /// Every place that used to navigate to the settings module must open the
    /// scene. A leftover `.mcNavigate` to a case that no longer exists would
    /// not compile; a leftover one to *another* module would compile and send
    /// the user somewhere wrong.
    @Test func nothingNavigatesToASettingsModule() throws {
        #expect(!(try app().contains("ModuleID.settings")))
    }

    /// `SettingsLink` is the supported way and is used wherever there is a view
    /// to hold it: the Help menu, the menu-bar panel, the update badge.
    @Test func settingsLinkIsUsedWhereAViewExists() throws {
        let text = try app()
        #expect(text.components(separatedBy: "SettingsLink").count - 1 >= 3,
                "a place that should open Settings is still doing it another way")
    }

    /// The command palette invokes closures, not views, so it cannot hold a
    /// link. Its stringly-typed selector is isolated and guarded so a macOS
    /// that renames it makes the entry do nothing rather than crash.
    @Test func theSelectorFallbackIsIsolatedAndGuarded() throws {
        let window = try String(
            contentsOf: root.appendingPathComponent("Sources/CoreTendApp/SettingsWindow.swift"),
            encoding: .utf8)
        #expect(window.contains("showSettingsWindow:"))
        // The name changed once already, before macOS 13.
        #expect(window.contains("showPreferencesWindow:"),
                "only one selector name is tried — it has been renamed before")
        #expect(window.contains("@discardableResult"))
        // And nowhere else may reach for it — in code. The comment in
        // CoreTendApp.swift explaining why the palette cannot use SettingsLink
        // names the selector on purpose.
        let codeOnly = try app()
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(!codeOnly.contains("showSettingsWindow"),
                "the selector is reached for outside SettingsWindow.swift")
    }
}
