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
            "CORETEND_TEST_RECENT_FILES_ENABLED": "1"
        ])

        XCTAssertFalse(preferences.usesPersistentStorage)
        XCTAssertEqual(preferences.lastDestination, "performance")
        XCTAssertEqual(preferences.language, "fr")
        XCTAssertTrue(preferences.onboardingCompleted)
        XCTAssertTrue(preferences.recentFilesEnabled)
    }

    func testAnyStoreOverrideDisablesPersistentPreferencesFailClosed() {
        let preferences = CoreTendPreferences(environment: ["CORETEND_TEST_STORE_DIR": "/fixture/store"])

        XCTAssertFalse(preferences.usesPersistentStorage)
        XCTAssertNil(preferences.lastDestination)
        XCTAssertEqual(preferences.language, "system")
        XCTAssertFalse(preferences.onboardingCompleted)
        XCTAssertFalse(preferences.recentFilesEnabled)
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

        XCTAssertEqual(preferences.lastDestination, "overview")
        XCTAssertEqual(preferences.language, "system")
        XCTAssertFalse(preferences.onboardingCompleted)
        XCTAssertFalse(preferences.recentFilesEnabled)
    }

    func testProductionPreferenceProfileUsesPersistentStorage() {
        XCTAssertTrue(CoreTendPreferences(environment: [:]).usesPersistentStorage)
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
}
