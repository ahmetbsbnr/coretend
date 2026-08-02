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

    func testIntegrityActivityAndSettingsExposeAutomationIdentifiers() throws {
        let app = try launchApp()
        defer { app.terminate() }

        let integrity = app.descendants(matching: .any)["sidebar.Protection"].firstMatch
        XCTAssertTrue(integrity.waitForExistence(timeout: 8))
        integrity.click()
        XCTAssertTrue(app.descendants(matching: .any)["integrity.root"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["integrity.downloads"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["integrity.inspector"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["integrity.login_items"].firstMatch.waitForExistence(timeout: 8))

        let activity = app.descendants(matching: .any)["sidebar.My Activity"].firstMatch
        XCTAssertTrue(activity.waitForExistence(timeout: 8))
        activity.click()
        XCTAssertTrue(app.descendants(matching: .any)["activity.root"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["activity.range"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["activity.filter"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["activity.safety_log"].firstMatch.waitForExistence(timeout: 8))

        let settings = app.descendants(matching: .any)["sidebar.Settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.click()
        XCTAssertTrue(app.descendants(matching: .any)["settings.root"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["settings.language"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["settings.menu_bar"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["settings.dry_run"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["settings.exclusions.add"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["settings.diagnostic.export"].firstMatch.waitForExistence(timeout: 8))
    }

    func testCloseAndRelaunchPreservesIsolatedDashboardAccess() throws {
        let storePath = NSTemporaryDirectory() + "/coretend-ui-relaunch-\(UUID().uuidString)"
        let app = try launchApp(storePath: storePath)
        XCTAssertTrue(app.descendants(matching: .any)["dashboard.root"].firstMatch.waitForExistence(timeout: 8))
        app.terminate()

        let relaunched = try launchApp(storePath: storePath)
        defer { relaunched.terminate() }
        XCTAssertTrue(relaunched.windows.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(relaunched.descendants(matching: .any)["dashboard.root"].firstMatch.waitForExistence(timeout: 8))
    }

    private func launchApp(onboardingDone: Bool = true, locale: String? = nil, storePath: String? = nil) throws -> XCUIApplication {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CORETEND_XCUI_UI_TEST_BUNDLE"] == "1" else {
            throw XCTSkip("SwiftPM emits CoreTendUITests as a unit-test bundle; XCUIApplication requires a native Xcode UI-test target. Artifact UI is verified with the isolated capture harness.")
        }
        guard let rawPath = environment["CORETEND_UI_APP_PATH"],
              !rawPath.isEmpty, FileManager.default.fileExists(atPath: rawPath) else {
            throw XCTSkip("Set CORETEND_UI_APP_PATH to a built CoreTend.app for XCUIAutomation.")
        }

        let app = XCUIApplication(url: URL(fileURLWithPath: rawPath))
        app.launchArguments += ["-onboardingDone", onboardingDone ? "YES" : "NO"]
        app.launchArguments += ["-onboardingStep", "0"]
        if let locale {
            app.launchArguments += ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale]
        }
        app.launchEnvironment["CORETEND_TEST_MODE"] = "1"
        app.launchEnvironment["CORETEND_TEST_STORE_DIR"] = storePath ?? NSTemporaryDirectory() + "/coretend-ui-\(UUID().uuidString)"
        app.launch()
        return app
    }
}
