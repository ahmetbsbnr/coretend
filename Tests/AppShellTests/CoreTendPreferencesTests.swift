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
        preferences.saveLanguage("fr")
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

    func testProductionStoredLanguageRemainsSupported() {
        let preferences = CoreTendPreferences(environment: [:])

        XCTAssertEqual(preferences.resolvedLanguage(storedValue: "fr"), "fr")
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
}
