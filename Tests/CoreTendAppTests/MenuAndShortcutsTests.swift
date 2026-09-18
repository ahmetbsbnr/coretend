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
    /// claims has to correspond to a real binding in a view — the failure mode
    /// of a hand-written shortcut list is that it documents what the app used
    /// to do.
    @Test func documentedScanShortcutsAreActuallyBound() throws {
        let views = ["CleanupView", "DuplicatesView", "SpaceLensView",
                     "MyClutterView", "SimilarImagesView", "CloudCleanupView"]
        var combined = ""
        for view in views {
            combined += try source("Sources/CoreTendApp/\(view).swift")
        }
        #expect(combined.contains(#"keyboardShortcut("p", modifiers: [])"#), "P (pause) is documented but not bound")
        #expect(combined.contains(#"keyboardShortcut("r", modifiers: [])"#), "R (resume) is documented but not bound")
        #expect(combined.contains("keyboardShortcut(.cancelAction)"), "Escape (cancel) is documented but not bound")
        #expect(combined.contains(#"keyboardShortcut("[", modifiers: .command)"#), "⌘[ is documented but not bound")
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
