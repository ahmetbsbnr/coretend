import Foundation

/// Application preferences are host-persistent only in normal launches.
/// Any declared fixture mode reads overrides from the process environment and never touches CFPreferences.
public struct CoreTendPreferences {
    private let environment: [String: String]
    public let usesPersistentStorage: Bool

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
        usesPersistentStorage = environment["CORETEND_TEST_MODE"] == nil
            && environment["CORETEND_TEST_STORE_DIR"] == nil
    }

    public var lastDestination: String? {
        if !usesPersistentStorage { return environment["CORETEND_TEST_LAST_DESTINATION"] }
        return UserDefaults.standard.string(forKey: "coretend.lastDestination")
    }

    public var language: String {
        if !usesPersistentStorage { return environment["CORETEND_TEST_LANGUAGE"] ?? "system" }
        return UserDefaults.standard.string(forKey: "coretend.language") ?? "system"
    }

    public func resolvedLanguage(storedValue: String?) -> String {
        let candidate = usesPersistentStorage ? (storedValue ?? language) : language
        return ["system", "en", "fr"].contains(candidate) ? candidate : "system"
    }

    public var onboardingCompleted: Bool {
        if !usesPersistentStorage { return environment["CORETEND_TEST_ONBOARDING_COMPLETED"] == "1" }
        return UserDefaults.standard.bool(forKey: "coretend.onboarding.completed")
    }

    public var recentFilesEnabled: Bool {
        if !usesPersistentStorage { return environment["CORETEND_TEST_RECENT_FILES_ENABLED"] == "1" }
        return UserDefaults.standard.bool(forKey: "coretend.recentFiles.enabled")
    }

    public func saveLastDestination(_ value: String) {
        guard usesPersistentStorage else { return }
        UserDefaults.standard.set(value, forKey: "coretend.lastDestination")
    }

    public func saveLanguage(_ value: String) {
        guard usesPersistentStorage else { return }
        UserDefaults.standard.set(value, forKey: "coretend.language")
    }

    public func saveOnboardingCompleted(_ value: Bool) {
        guard usesPersistentStorage else { return }
        UserDefaults.standard.set(value, forKey: "coretend.onboarding.completed")
    }

    public func saveRecentFilesEnabled(_ value: Bool) {
        guard usesPersistentStorage else { return }
        UserDefaults.standard.set(value, forKey: "coretend.recentFiles.enabled")
    }
}
