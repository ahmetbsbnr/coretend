// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation

/// The window must have more than one focusable region.
///
/// This guards a defect that was found by driving the running app and could
/// not be seen by reading a view: the sidebar was a `.focusable()` container
/// and the only focusable region in the content, so it took first responder at
/// launch and never released it. Tab did nothing, clicking a list did not move
/// focus, and the arrow keys therefore always changed *module* — the Record
/// journal, the Cleanup list and the Duplicates groups were unreachable from
/// the keyboard.
///
/// The test is deliberately structural rather than a simulated key press: a UI
/// test that drives real focus is exactly the fragile kind. What it protects is
/// the one property whose absence caused the defect — that the detail column
/// declares a focus section of its own — plus the absence of the specific
/// mistake made while fixing it.
@Suite("Window focus chain")
struct WindowFocusContractTests {
    private var mainWindow: String {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            return try String(contentsOf: root
                .appendingPathComponent("Sources/CoreTendApp/App/MainWindow.swift"), encoding: .utf8)
        }
    }

    @Test func theDetailColumnIsItsOwnFocusSection() throws {
        #expect(try mainWindow.contains(".focusSection()"),
                "the detail column declares no focus section — keyboard focus cannot leave the sidebar")
    }

    /// The first attempt at the fix made the detail `.focusable()` and
    /// intercepted Tab, returning `.handled`. That broke the trap but parked
    /// focus on an empty container and swallowed the very key AppKit needed to
    /// complete the move, so the journal still never saw an arrow.
    @Test func tabIsNotSwallowedByTheWindow() throws {
        // Comment lines stripped first: the source explains why that
        // interception was removed, and a contract about *code* must not be
        // tripped by the comment describing the contract.
        let text = try mainWindow
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(!text.contains("onKeyPress(.tab)"),
                "MainWindow intercepts Tab — AppKit needs it to move focus between sections")
    }

    /// The sidebar answers arrow keys only while it holds focus. Unconditional,
    /// it consumed arrows meant for whatever list the user was actually in.
    @Test func theSidebarOnlyAnswersArrowsWhenFocused() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sidebar = try String(contentsOf: root
            .appendingPathComponent("Sources/CoreTendApp/Sidebar.swift"), encoding: .utf8)
        #expect(sidebar.contains("guard focused else { return }"),
                "the sidebar answers arrow keys even when it is not the focused region")
    }
}
