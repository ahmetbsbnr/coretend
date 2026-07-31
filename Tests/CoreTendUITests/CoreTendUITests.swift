import XCTest

@MainActor
final class CoreTendUITests: XCTestCase {
    func testFirstLaunchShowsWindowWhenAppPathIsProvided() throws {
        guard let rawPath = ProcessInfo.processInfo.environment["CORETEND_UI_APP_PATH"],
              !rawPath.isEmpty else {
            throw XCTSkip("Set CORETEND_UI_APP_PATH to a built CoreTend.app for XCUIAutomation.")
        }

        let app = XCUIApplication(url: URL(fileURLWithPath: rawPath))
        app.launchEnvironment["CORETEND_TEST_MODE"] = "1"
        app.launchEnvironment["CORETEND_TEST_STORE_DIR"] = NSTemporaryDirectory() + "/coretend-ui-\(UUID().uuidString)"
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
    }
}
