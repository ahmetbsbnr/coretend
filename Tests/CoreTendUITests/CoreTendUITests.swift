import XCTest

@MainActor
final class CoreTendUITests: XCTestCase {
    func testFirstLaunchShowsWindowWhenAppPathIsProvided() throws {
        let app = try launchApp()
        defer { app.terminate() }

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
    }

    func testOnboardingCanBeSkippedFromFreshPreferences() throws {
        let app = try launchApp(onboardingDone: false)
        defer { app.terminate() }

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.root"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.language"].firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.step"].firstMatch.waitForExistence(timeout: 4))
        app.descendants(matching: .any)["onboarding.skip"].firstMatch.click()
        XCTAssertTrue(app.descendants(matching: .any)["dashboard.root"].firstMatch.waitForExistence(timeout: 8))
    }

    func testPrimarySidebarDestinationsNavigate() throws {
        let app = try launchApp()
        defer { app.terminate() }

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
        let destinations = [
            ("sidebar.Smart Care", "dashboard.root"),
            ("sidebar.Cleanup", "storage.root"),
            ("sidebar.Space Lens", "spacelens.root"),
            ("sidebar.Duplicates", "duplicates.root"),
            ("sidebar.Applications", "applications.root"),
            ("sidebar.Protection", "integrity.root"),
            ("sidebar.My Activity", "activity.root"),
            ("sidebar.Settings", "settings.root"),
        ]
        for (sidebarID, rootID) in destinations {
            let item = app.descendants(matching: .any)[sidebarID].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 4), "Missing \(sidebarID)")
            item.click()
            XCTAssertTrue(app.descendants(matching: .any)[rootID].firstMatch.waitForExistence(timeout: 4), "Missing \(rootID)")
        }
    }

    func testEnglishAndFrenchLaunchWithIsolatedPreferences() throws {
        for locale in ["en", "fr"] {
            let app = try launchApp(locale: locale)
            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8), "Missing window for \(locale)")
            XCTAssertTrue(app.descendants(matching: .any)["dashboard.root"].firstMatch.waitForExistence(timeout: 8), "Missing dashboard for \(locale)")
            app.terminate()
        }
    }

    func testPrimaryScanControlsExposeAutomationIdentifiers() throws {
        let app = try launchApp()
        defer { app.terminate() }

        let expectedControls = [
            ("sidebar.Cleanup", "storage.scan.start"),
            ("sidebar.Space Lens", "spacelens.scan.home"),
            ("sidebar.Duplicates", "duplicates.scan.start"),
        ]

        for (sidebarID, controlID) in expectedControls {
            let item = app.descendants(matching: .any)[sidebarID].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 4), "Missing \(sidebarID)")
            item.click()
            XCTAssertTrue(app.descendants(matching: .any)[controlID].firstMatch.waitForExistence(timeout: 4), "Missing \(controlID)")
        }
    }

    func testApplicationControlsExposeAutomationIdentifiers() throws {
        let app = try launchApp()
        defer { app.terminate() }

        let applications = app.descendants(matching: .any)["sidebar.Applications"].firstMatch
        XCTAssertTrue(applications.waitForExistence(timeout: 8))
        applications.click()

        XCTAssertTrue(app.descendants(matching: .any)["applications.search"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["applications.grouping"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["applications.list"].firstMatch.waitForExistence(timeout: 8))
    }

    private func launchApp(onboardingDone: Bool = true, locale: String? = nil) throws -> XCUIApplication {
        guard let rawPath = ProcessInfo.processInfo.environment["CORETEND_UI_APP_PATH"],
              !rawPath.isEmpty else {
            throw XCTSkip("Set CORETEND_UI_APP_PATH to a built CoreTend.app for XCUIAutomation.")
        }

        let app = XCUIApplication(url: URL(fileURLWithPath: rawPath))
        app.launchArguments += ["-onboardingDone", onboardingDone ? "YES" : "NO"]
        app.launchArguments += ["-onboardingStep", "0"]
        if let locale {
            app.launchArguments += ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale]
        }
        app.launchEnvironment["CORETEND_TEST_MODE"] = "1"
        app.launchEnvironment["CORETEND_TEST_STORE_DIR"] = NSTemporaryDirectory() + "/coretend-ui-\(UUID().uuidString)"
        app.launch()
        return app
    }
}
