import XCTest
@testable import AppShell

final class CoreTendPreferencesTests: XCTestCase {
    func testFixtureProfileReadsOnlyExplicitOverrides() {
        let preferences = CoreTendPreferences(environment: [
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": "/fixture/store",
            "CORETEND_TEST_LAST_DESTINATION": "performance",
            "CORETEND_TEST_LANGUAGE": "fr",
            "CORETEND_TEST_ONBOARDING_COMPLETED": "1",
            "CORETEND_TEST_RECENT_FILES_ENABLED": "1",
            "CORETEND_TEST_MENU_BAR_ENABLED": "1"
        ])

        XCTAssertFalse(preferences.usesPersistentStorage)
        XCTAssertEqual(preferences.lastDestination, "performance")
        XCTAssertEqual(preferences.language, "fr")
        XCTAssertTrue(preferences.onboardingCompleted)
        XCTAssertTrue(preferences.recentFilesEnabled)
        XCTAssertTrue(preferences.menuBarEnabled)
    }

    func testAnyStoreOverrideDisablesPersistentPreferencesFailClosed() {
        let preferences = CoreTendPreferences(environment: ["CORETEND_TEST_STORE_DIR": "/fixture/store"])

        XCTAssertFalse(preferences.usesPersistentStorage)
        XCTAssertNil(preferences.lastDestination)
        XCTAssertEqual(preferences.language, "system")
        XCTAssertFalse(preferences.onboardingCompleted)
        XCTAssertFalse(preferences.recentFilesEnabled)
        XCTAssertFalse(preferences.menuBarEnabled)
    }

    func testFixturePreferenceWritesAreNoOps() {
        let preferences = CoreTendPreferences(environment: [
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": "/fixture/store",
            "CORETEND_TEST_LAST_DESTINATION": "overview"
        ])

        preferences.saveLastDestination("record")
        preferences.saveOnboardingCompleted(true)
        preferences.saveRecentFilesEnabled(true)
        preferences.saveMenuBarEnabled(true)

        XCTAssertEqual(preferences.lastDestination, "overview")
        XCTAssertEqual(preferences.language, "system")
        XCTAssertFalse(preferences.onboardingCompleted)
        XCTAssertFalse(preferences.recentFilesEnabled)
        XCTAssertFalse(preferences.menuBarEnabled)
    }

    func testProductionPreferenceProfileUsesPersistentStorage() {
        XCTAssertTrue(CoreTendPreferences(environment: [:]).usesPersistentStorage)
    }

    func testMenuBarPreferencePersistsInAnInjectedDefaultsSuite() throws {
        let suiteName = "CoreTend.Tests.MenuBar.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initial = CoreTendPreferences(environment: [:], defaults: defaults)
        XCTAssertFalse(initial.menuBarEnabled)
        initial.saveMenuBarEnabled(true)

        let reopened = CoreTendPreferences(environment: [:], defaults: defaults)
        XCTAssertTrue(reopened.menuBarEnabled)
    }

    func testFixtureLanguageOverrideWinsOverStoredLanguage() {
        let preferences = CoreTendPreferences(environment: [
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": "/fixture/store",
            "CORETEND_TEST_LANGUAGE": "fr"
        ])

        XCTAssertEqual(preferences.resolvedLanguage(storedValue: "en"), "fr")
    }

    func testFixtureLanguageDoesNotReadStoredLanguageWhenNoOverrideExists() {
        let preferences = CoreTendPreferences(environment: ["CORETEND_TEST_MODE": "1"])

        XCTAssertEqual(preferences.resolvedLanguage(storedValue: "en"), "system")
    }

    func testProductionLanguageFollowsTheSystemAndIgnoresAStoredChoice() {
        let preferences = CoreTendPreferences(environment: [:])

        XCTAssertEqual(preferences.resolvedLanguage(storedValue: "fr"), "system")
        XCTAssertEqual(preferences.resolvedLanguage(storedValue: nil), "system")
    }

    func testSystemLanguageIsFrenchOnlyWhenMacOSPrefersFrench() {
        XCTAssertTrue(AppLanguage.usesFrench("system", preferred: ["fr-FR", "en-US"]))
        XCTAssertTrue(AppLanguage.usesFrench("system", preferred: ["fr-CA"]))
        XCTAssertFalse(AppLanguage.usesFrench("system", preferred: ["de-DE", "fr-FR"]))
        XCTAssertFalse(AppLanguage.usesFrench("system", preferred: ["tr-TR"]))
        XCTAssertFalse(AppLanguage.usesFrench("system", preferred: []))
        XCTAssertTrue(AppLanguage.usesFrench("fr", preferred: ["en-US"]))
    }

    func testAppearanceOverrideAppliesOnlyInFixtureMode() {
        XCTAssertEqual(CoreTendPreferences(environment: ["CORETEND_TEST_MODE": "1", "CORETEND_TEST_APPEARANCE": "dark"],
                                           defaults: UserDefaults(suiteName: "coretend.appearance.fixture")!).fixtureAppearance, .dark)
        XCTAssertEqual(CoreTendPreferences(environment: ["CORETEND_TEST_MODE": "1", "CORETEND_TEST_APPEARANCE": "light"],
                                           defaults: UserDefaults(suiteName: "coretend.appearance.fixture")!).fixtureAppearance, .light)
        XCTAssertNil(CoreTendPreferences(environment: ["CORETEND_TEST_MODE": "1", "CORETEND_TEST_APPEARANCE": "sepia"],
                                         defaults: UserDefaults(suiteName: "coretend.appearance.fixture")!).fixtureAppearance)
        XCTAssertNil(CoreTendPreferences(environment: ["CORETEND_TEST_APPEARANCE": "dark"],
                                         defaults: UserDefaults(suiteName: "coretend.appearance.fixture")!).fixtureAppearance)
    }

    func testStoreCaptureHooksApplyOnlyToFixtureLaunches() {
        let fixture = CoreTendPreferences(environment: [
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_SCAN_ROOT": "/fixture/home/Greenhouse",
            "CORETEND_TEST_CLEANUP_RULE": "cleanup.usercaches",
            "CORETEND_TEST_WINDOW_SIZE": "1440x900"
        ], defaults: UserDefaults(suiteName: "coretend.capture.fixture")!)
        XCTAssertEqual(fixture.fixtureScanRoot?.path, "/fixture/home/Greenhouse")
        XCTAssertEqual(fixture.fixtureCleanupRule, "cleanup.usercaches")
        XCTAssertEqual(fixture.fixtureWindowSize?.width, 1440)
        XCTAssertEqual(fixture.fixtureWindowSize?.height, 900)

        // A normal launch ignores the same variables: no folder is ever opened by itself.
        let normal = CoreTendPreferences(environment: [
            "CORETEND_TEST_SCAN_ROOT": "/private/tmp/elsewhere",
            "CORETEND_TEST_CLEANUP_RULE": "cleanup.usercaches",
            "CORETEND_TEST_WINDOW_SIZE": "1440x900"
        ], defaults: UserDefaults(suiteName: "coretend.capture.normal")!)
        XCTAssertNil(normal.fixtureScanRoot)
        XCTAssertNil(normal.fixtureCleanupRule)
        XCTAssertNil(normal.fixtureWindowSize)

        let malformed = CoreTendPreferences(environment: ["CORETEND_TEST_MODE": "1", "CORETEND_TEST_WINDOW_SIZE": "wide"],
                                            defaults: UserDefaults(suiteName: "coretend.capture.malformed")!)
        XCTAssertNil(malformed.fixtureWindowSize)
    }
}
