// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation

/// A declared context menu must contain something.
///
/// Two separate instances of the same defect reached the running app: the
/// "Inspect" action was silently dropped from Integrity during a rebuild, and
/// both Record and Duplicates declared `contextMenu(forSelectionType:)` whose
/// body was `EmptyView()` — so a right-click on a journal entry or a duplicate
/// group opened an empty grey rectangle. Neither was caught by anything,
/// because a menu with no items is perfectly valid SwiftUI.
///
/// Structural on purpose: right-click cannot be driven from this environment
/// (AppleScript cannot produce one reliably, and the XCUITest runner is killed
/// before bootstrapping without an interactive Accessibility grant), so the
/// guard protects the property whose absence produced the bug rather than
/// simulating the gesture.
@Suite("Context menus carry actions")
struct ContextMenuContractTests {
    private func appSources() throws -> [(name: String, text: String)] {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/CoreTendApp")
        let names = try FileManager.default.subpathsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".swift") }
        return try names.map { ($0, try String(contentsOf: dir.appendingPathComponent($0), encoding: .utf8)) }
    }

    @Test func noContextMenuRendersAnEmptyBody() throws {
        for file in try appSources() {
            let lines = file.text.split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() where line.contains(".contextMenu") {
                // Look at the few lines that make up the menu's body.
                let body = lines[index..<min(index + 4, lines.count)].joined(separator: "\n")
                let where_ = "\(file.name):\(index + 1) declares a context menu with no actions"
                #expect(!body.contains("EmptyView()"), "\(where_)")
            }
        }
    }
}
