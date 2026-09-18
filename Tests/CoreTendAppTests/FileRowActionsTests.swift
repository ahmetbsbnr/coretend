// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// A row's actions are declared once and offered two ways.
///
/// macOS 27 brought `swipeActions` to the Mac, and it is the right gesture for
/// a long file list — a swipe reveals what you can do to a row without three
/// permanent icon buttons crowding every one of them.
///
/// But a swipe is a pointer gesture. Someone on a keyboard, using VoiceOver, or
/// driving the Mac with Switch Control cannot perform it, and an action
/// reachable only by swiping is an action those people do not have.
@Suite("File row actions")
struct FileRowActionsTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// The load-bearing rule: every swipe action is also a context-menu action,
    /// because they come from one array. Two lists that must agree is a pair
    /// that eventually disagrees, and the failure is silent — the swipe keeps
    /// working while the menu quietly lacks what someone needed.
    @Test func swipeAndMenuAreBuiltFromOneDeclaration() throws {
        let text = try source("Sources/CoreTendApp/FileRowActions.swift")
        #expect(text.contains(".swipeActions("))
        #expect(text.contains(".contextMenu"))
        // Both iterate the same `actions`.
        #expect(text.components(separatedBy: "ForEach(actions").count - 1 >= 2,
                "swipe and menu do not both iterate the same array")
    }

    /// Swipe actions are macOS 27. Below that the context menu is the only
    /// affordance — which is what the app has always had, so nothing is lost.
    @Test func theSwipeIsGatedAndTheMenuIsNot() throws {
        let text = try source("Sources/CoreTendApp/FileRowActions.swift")
        #expect(text.contains("#available(macOS 27.0, *)"))
        guard let menuRange = text.range(of: ".contextMenu"),
              let gateRange = text.range(of: "#available(macOS 27.0, *)") else {
            Issue.record("expected both a context menu and an availability gate")
            return
        }
        #expect(menuRange.lowerBound < gateRange.lowerBound,
                "the context menu appears to be inside the availability gate")
    }

    @Test func inspectionOffersQuickLookAndReveal() {
        var previewed: URL?
        let actions = FileRowAction.inspection(for: URL(fileURLWithPath: "/tmp/x.txt")) {
            previewed = $0
        }
        #expect(actions.map(\.id) == ["quicklook", "reveal"])
        actions.first { $0.id == "quicklook" }?.perform()
        #expect(previewed?.path == "/tmp/x.txt")
    }

    /// Excluding is deliberately not an inspection action: it carries state the
    /// row must show — "already excluded" is a different control, not a
    /// disabled action — and it has two variants, this file or its folder.
    @Test func excludingIsNotFoldedIntoTheRowActions() {
        let actions = FileRowAction.inspection(for: URL(fileURLWithPath: "/tmp/x")) { _ in }
        #expect(!actions.contains { $0.id.contains("exclude") })
    }

    /// Every list that adopted this must have dropped the two permanent icon
    /// buttons, or the row is now offering the same action three ways.
    @Test func adoptingListsDroppedTheirInlineInspectionButtons() throws {
        for file in ["MyClutterView.swift", "DuplicatesView.swift", "SimilarImagesView.swift"] {
            let text = try source("Sources/CoreTendApp/\(file)")
            #expect(text.contains(".fileRowActions("), "\(file) did not adopt the shared actions")
            #expect(!text.contains(#"Image(systemName: "eye")"#),
                    "\(file) still has an inline Quick Look button")
        }
    }

    /// Both labels must exist in both languages: a swipe action rendering its
    /// own key is a gesture that reveals gibberish.
    @Test func theActionLabelsAreLocalised() throws {
        for lang in ["Base", "fr"] {
            let url = root.appendingPathComponent(
                "Sources/CoreTendApp/Resources/\(lang).lproj/Localizable.strings")
            let table = try PropertyListSerialization.propertyList(
                from: try Data(contentsOf: url), format: nil) as? [String: Any] ?? [:]
            for key in ["clutter.quick_look", "common.reveal_in_finder"] {
                #expect(table[key] != nil, "\(lang) is missing \(key)")
            }
        }
    }
}
