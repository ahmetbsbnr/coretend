import Foundation

public enum FixtureAppearance: String, Sendable { case light, dark }
public enum AppearancePreference: String, CaseIterable, Sendable { case system, light, dark }

/// Application preferences are host-persistent only in normal launches.
/// Any declared fixture mode reads overrides from the process environment and never touches CFPreferences.
public struct CoreTendPreferences {
    private let environment: [String: String]
    private let defaults: UserDefaults
    public let usesPersistentStorage: Bool

    public init(environment: [String: String] = ProcessInfo.processInfo.environment, defaults: UserDefaults = .standard) {
        self.environment = environment
        self.defaults = defaults
        usesPersistentStorage = environment["CORETEND_TEST_MODE"] == nil
            && environment["CORETEND_TEST_STORE_DIR"] == nil
    }

    public var lastDestination: String? {
        if !usesPersistentStorage { return environment["CORETEND_TEST_LAST_DESTINATION"] }
        return defaults.string(forKey: "coretend.lastDestination")
    }

    public var language: String {
        if !usesPersistentStorage { return environment["CORETEND_TEST_LANGUAGE"] ?? "system" }
        return defaults.string(forKey: "coretend.language") ?? "system"
    }

    public var appearance: AppearancePreference {
        guard usesPersistentStorage else { return .system }
        return defaults.string(forKey: "coretend.appearance").flatMap(AppearancePreference.init(rawValue:)) ?? .system
    }

    public func resolvedLanguage(storedValue: String?) -> String {
        let candidate = usesPersistentStorage ? (storedValue ?? language) : language
        return ["system", "en", "fr"].contains(candidate) ? candidate : "system"
    }

    public var onboardingCompleted: Bool {
        if !usesPersistentStorage { return environment["CORETEND_TEST_ONBOARDING_COMPLETED"] == "1" }
        return defaults.bool(forKey: "coretend.onboarding.completed")
    }

    public var recentFilesEnabled: Bool {
        if !usesPersistentStorage { return environment["CORETEND_TEST_RECENT_FILES_ENABLED"] == "1" }
        return defaults.bool(forKey: "coretend.recentFiles.enabled")
    }

    /// Fixture-only appearance override so light and dark qualification never changes the host setting.
    public var fixtureAppearance: FixtureAppearance? {
        guard !usesPersistentStorage else { return nil }
        return environment["CORETEND_TEST_APPEARANCE"].flatMap(FixtureAppearance.init(rawValue:))
    }

    /// Fixture-only: a folder a destination opens by itself, so captures show the screen in use.
    /// Never read in a normal launch.
    public var fixtureScanRoot: URL? {
        guard !usesPersistentStorage, let path = environment["CORETEND_TEST_SCAN_ROOT"], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Fixture-only: the first window's size in points ("1440x900"), for store captures.
    public var fixtureWindowSize: (width: Double, height: Double)? {
        guard !usesPersistentStorage, let value = environment["CORETEND_TEST_WINDOW_SIZE"] else { return nil }
        let parts = value.split(separator: "x").compactMap { Double($0) }
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    /// Fixture-only: the Cleanup rule opened with `fixtureScanRoot`.
    public var fixtureCleanupRule: String? {
        guard !usesPersistentStorage else { return nil }
        return environment["CORETEND_TEST_CLEANUP_RULE"]
    }

    public var menuBarEnabled: Bool {
        if !usesPersistentStorage { return environment["CORETEND_TEST_MENU_BAR_ENABLED"] == "1" }
        return defaults.bool(forKey: "coretend.menuBar.enabled")
    }

    public func saveLastDestination(_ value: String) {
        guard usesPersistentStorage else { return }
        defaults.set(value, forKey: "coretend.lastDestination")
    }

    public func saveLanguage(_ value: String) {
        guard usesPersistentStorage else { return }
        defaults.set(value, forKey: "coretend.language")
    }

    public func saveAppearance(_ value: AppearancePreference) {
        guard usesPersistentStorage else { return }
        defaults.set(value.rawValue, forKey: "coretend.appearance")
    }

    public func saveOnboardingCompleted(_ value: Bool) {
        guard usesPersistentStorage else { return }
        defaults.set(value, forKey: "coretend.onboarding.completed")
    }

    public func saveRecentFilesEnabled(_ value: Bool) {
        guard usesPersistentStorage else { return }
        defaults.set(value, forKey: "coretend.recentFiles.enabled")
    }

    public func saveMenuBarEnabled(_ value: Bool) {
        guard usesPersistentStorage else { return }
        defaults.set(value, forKey: "coretend.menuBar.enabled")
    }
}
