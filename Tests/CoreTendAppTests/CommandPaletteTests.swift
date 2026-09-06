// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

@Suite("Command palette filtering")
struct CommandPaletteTests {
    @Test("empty query matches everything")
    func emptyQueryMatchesAll() {
        #expect(paletteMatches(label: "Space Lens", query: ""))
        #expect(paletteMatches(label: "Space Lens", query: "   "))
    }

    @Test("case- and diacritic-insensitive substring match")
    func caseAndDiacriticInsensitive() {
        #expect(paletteMatches(label: "Space Lens", query: "space"))
        #expect(paletteMatches(label: "Réglages", query: "reglages"))
        #expect(!paletteMatches(label: "Space Lens", query: "zzz"))
    }

    @Test("every sidebar destination has a non-empty label and icon")
    func everyModuleHasLabelAndIcon() {
        let modules = SidebarGroup.visibleModules
        for module in modules {
            #expect(!module.label.isEmpty)
            #expect(!module.systemImage.isEmpty)
        }
        // .myClutter/.cloudCleanup/.performance were reconnected to the "more"
        // sidebar group in the 2026-08-09 dead-module audit — each does
        // something unique (large/old-files finder, cloud sync-state
        // analysis, broken-LaunchAgent detection) so they were kept and
        // re-wired rather than deleted. See Documentation/Audits/
        // SESSION_2026-08-09_AUDIT.md.
        #expect(modules == [
            .smartCare, .cleanup, .spaceLens, .duplicates, .applications, .developer, .timeline, .recoveryPlan, .apfs,
            .myClutter, .cloudCleanup, .performance,
            .privacyLab, .protection, .myActivity, .restoreCenter, .settings,
        ])
        #expect(Set(modules.map(\.rawValue)).count == modules.count)
    }
}

/// The palette must be a transient, outside-click-dismissable overlay — NOT
/// a document-modal `.sheet` (which ignores outside clicks) — and its
/// trigger must live in CoreTend's own header band, not the extreme
/// top-right macOS toolbar slot against the rounded window corner.
@Suite("Command palette — presentation & trigger placement")
struct CommandPalettePresentationTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func appSource() throws -> String {
        try String(contentsOf: root.appendingPathComponent("Sources/CoreTendApp/CoreTendApp.swift"), encoding: .utf8)
    }

    @Test func paletteIsAnOverlayNotASheet() throws {
        let s = try appSource()
        #expect(!s.contains(".sheet(isPresented: $showCommandPalette)"),
                "the palette must not be a document-modal sheet")
        #expect(s.contains("CommandPaletteOverlay(isPresented: $showCommandPalette"))
        #expect(s.contains(".overlay {"))
        #expect(s.contains("if showCommandPalette {"))
    }

    @Test func backdropConsumesTheDismissalClickAndCloses() throws {
        let s = try appSource()
        // A filled, hit-testable backdrop with its own tap handler: the
        // outside click lands here, is consumed (no click-through to the
        // control beneath), and closes.
        #expect(s.contains("struct CommandPaletteOverlay"))
        #expect(s.contains("Color.black.opacity(0.18)"))
        #expect(s.contains(".contentShape(Rectangle())"))
        #expect(s.contains(".onTapGesture { close() }"))
        #expect(s.contains("commandPalette.backdrop"))
    }

    @Test func escapeHasExactlyOneOwner() throws {
        let s = try appSource()
        // `.onExitCommand` on the overlay is the single Escape owner; the
        // previous pass's competing handlers (field `.onKeyPress(.escape)`,
        // `.keyboardShortcut(.cancelAction)` on the ✕) are gone.
        #expect(!s.contains(".onKeyPress(.escape)"))
        // Exactly one live Escape handler wiring in the palette code.
        let occurrences = s.components(separatedBy: ".onExitCommand { close() }").count - 1
        #expect(occurrences == 1)
    }

    @Test func triggerLivesInAHeaderBandNotTheToolbarCorner() throws {
        let s = try appSource()
        #expect(s.contains(".safeAreaInset(edge: .top, spacing: 0) { paletteHeader }"))
        #expect(s.contains("commandPalette.trigger"))
        // Uses spacing tokens, not arbitrary pixel offsets.
        #expect(s.contains(".padding(.trailing, MCSpacing.page)"))
        // The old extreme-trailing toolbar item is gone.
        #expect(!s.contains("Label(L(\"palette.open\"), systemImage: \"command\")"))
    }

    /// Regression: the `.sheet` → `.overlay` migration broke keyboard focus.
    /// A plain `.onAppear { searchFocused = true }` is dropped because the
    /// overlay opens inside a `withAnimation` and isn't in the key window's
    /// responder chain yet — the search field never gets the caret and the
    /// keyboard-driven palette is dead. Focus must be requested after a
    /// one-runloop deferral.
    @Test func searchFieldFocusIsDeferredNotSetInOnAppear() throws {
        let s = try appSource()
        guard let r = s.range(of: "struct CommandPaletteView") else {
            Issue.record("CommandPaletteView not found"); return
        }
        let view = String(s[r.lowerBound...])
        #expect(!view.contains(".onAppear { searchFocused = true }"),
                "focus must not be set synchronously in onAppear")
        #expect(view.contains("Task.sleep") && view.contains("searchFocused = true"),
                "focus must be requested after a deferral (Task.sleep)")
        #expect(view.contains(".focused($searchFocused)"))
    }
}

@Suite("Command palette — localization parity for the a11y strings")
struct CommandPaletteLocalizationTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func strings(_ lproj: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(
            "Sources/CoreTendApp/Resources/\(lproj)/Localizable.strings"), encoding: .utf16)
    }

    @Test func newKeysExistInBothLanguages() throws {
        let base = try strings("Base.lproj")
        let fr = try strings("fr.lproj")
        for key in ["palette.open.a11y", "palette.close.a11y"] {
            #expect(base.contains("\"\(key)\""), "Base missing \(key)")
            #expect(fr.contains("\"\(key)\""), "fr missing \(key)")
        }
        #expect(base.contains("\"palette.open.a11y\" = \"Open command palette\";"))
        #expect(fr.contains("\"palette.open.a11y\" = \"Ouvrir la palette de commandes\";"))
    }
}
