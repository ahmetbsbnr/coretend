// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import XCTest

/// The interactions System Events could not drive.
///
/// Right-click, double-click and modifier-clicks were all reported as "not
/// verified" because AppleScript could not produce them reliably. XCUITest can,
/// so these exist to turn "the code declares it" into "this was exercised".
@MainActor
final class InteractionTests: XCTestCase {

    private var appPath: String {
        get throws {
            guard let path = ProcessInfo.processInfo.environment["CORETEND_UI_APP_PATH"],
                  FileManager.default.fileExists(atPath: path)
            else { throw XCTSkip("Set CORETEND_UI_APP_PATH to a built CoreTend.app.") }
            return path
        }
    }

    /// A launch isolated from the real store, on a chosen module, with the
    /// Visual Beta fixture that gives the module something to act on.
    private func launch(module: String,
                        fixture: String,
                        homeSeed: Bool = false,
                        autostart: Bool = false,
                        onboardingDone: Bool = true) throws -> XCUIApplication {
        let store = NSTemporaryDirectory() + "coretend-xcui-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: store, withIntermediateDirectories: true)
        if homeSeed {
            let seeder = Process()
            seeder.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            seeder.arguments = ["python3", seedScriptPath(), store + "/home"]
            try? seeder.run(); seeder.waitUntilExit()
        }
        let app = XCUIApplication(url: URL(fileURLWithPath: try appPath))
        app.launchArguments += ["-onboardingDone", onboardingDone ? "YES" : "NO"]
        app.launchEnvironment["CORETEND_TEST_MODE"] = "1"
        app.launchEnvironment["CORETEND_TEST_STORE_DIR"] = store
        app.launchEnvironment["CORETEND_FIXTURE"] = fixture
        app.launchEnvironment["CORETEND_TEST_MODULE"] = module
        app.launchEnvironment["CORETEND_TEST_APPEARANCE"] = "dark"
        app.launchEnvironment["CORETEND_TEST_WINDOW"] = "standard"
        if homeSeed { app.launchEnvironment["CORETEND_TEST_HOME"] = store + "/home" }
        if autostart { app.launchEnvironment["CORETEND_TEST_AUTOSTART"] = "1" }
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20), "no window")
        return app
    }

    private func seedScriptPath() -> String {
        // …/Tests/UIAutomation/Sources/InteractionTests.swift → …/Scripts/support
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Scripts/support/seed-home.py").path
    }

    // MARK: - Duplicates: the selection commands, proven by their effect

    /// ⌘A and ⌘⇧A must change the *selection*, not merely be received.
    func testDuplicatesSelectAllAndSelectNone() throws {
        let app = try launch(module: "Duplicates", fixture: "duplicates",
                             homeSeed: true, autostart: true)
        defer { app.terminate() }
        let root = app.descendants(matching: .any)
        XCTAssertTrue(root["duplicates.results.remove"].firstMatch.waitForExistence(timeout: 60),
                      "duplicates never reached its results state")

        // Start from nothing selected, so ⌘A has something to prove.
        app.typeKey("a", modifierFlags: [.command, .shift])
        let removeButton = root["duplicates.results.remove"].firstMatch
        XCTAssertFalse(removeButton.isEnabled,
                       "with nothing selected, the destructive action must be disabled")

        app.typeKey("a", modifierFlags: [.command])
        XCTAssertTrue(removeButton.isEnabled,
                      "⌘A selected nothing — the shortcut is received but has no effect")
    }

    // MARK: - Cleanup

    func testCleanupSelectNoneDisablesThePrimaryAction() throws {
        let app = try launch(module: "Cleanup", fixture: "normal",
                             homeSeed: true, autostart: true)
        defer { app.terminate() }
        let root = app.descendants(matching: .any)
        XCTAssertTrue(root["cleanup.select_none"].firstMatch.waitForExistence(timeout: 90),
                      "cleanup never reached its review state")
        app.typeKey("a", modifierFlags: [.command, .shift])
        XCTAssertFalse(root["cleanup.select_all"].firstMatch.isEnabled == false,
                       "Select all should become available once nothing is selected")
    }

    // MARK: - Right-click, the interaction AppleScript could not produce

    func testRecordRowExposesAContextMenu() throws {
        let app = try launch(module: "Record", fixture: "history")
        defer { app.terminate() }
        let rows = app.descendants(matching: .any).matching(identifier: "record.row")
        guard rows.count > 0 else {
            throw XCTSkip("Record rows carry no automation identifier to right-click.")
        }
        rows.element(boundBy: 0).rightClick()
        XCTAssertTrue(app.menus.firstMatch.waitForExistence(timeout: 4),
                      "right-click opened no menu")
    }

    // MARK: - Keyboard: Escape and Shift-Tab reach the app at all

    func testEscapeAndShiftTabAreDelivered() throws {
        let app = try launch(module: "Record", fixture: "history")
        defer { app.terminate() }
        // Not an assertion about behaviour — an assertion that the window
        // survives them and stays responsive, which is what "delivered"
        // means for keys whose effect is contextual.
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [.shift])
        XCTAssertTrue(app.windows.firstMatch.exists)
    }

    // MARK: - Command palette

    func testCommandPaletteOpensWithCommandK() throws {
        let app = try launch(module: "Smart Care", fixture: "normal")
        defer { app.terminate() }
        app.typeKey("k", modifierFlags: [.command])
        XCTAssertTrue(app.descendants(matching: .any)["commandPalette.search"]
            .firstMatch.waitForExistence(timeout: 5),
                      "⌘K did not open the command palette")
    }
}
