import Foundation

/// The three choices offered to the user — "match the system" plus each
/// language CoreTend actually ships (en/fr are the only two with complete,
/// parity-checked string tables; adding a third only means adding another
/// case here plus its own .lproj, no architecture change).
public enum AppLanguage: String, CaseIterable, Sendable {
    case system, en, fr

    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .en: "en"
        case .fr: "fr"
        }
    }
}

/// Owns the runtime language override lookup. Plain, `Sendable`, no actor
/// isolation — `L()` is called from many contexts, not all of them
/// MainActor, and UserDefaults reads are already thread-safe, so there is
/// nothing here that actually needs main-actor confinement.
enum LocalizationManager {
    private static let storageKey = "appLanguage"

    static var language: AppLanguage {
        language(fromStoredValue: UserDefaults.standard.string(forKey: storageKey))
    }

    /// Pure parsing keeps fallback behavior testable without mutating the
    /// process-wide UserDefaults domain while other Xcode tests run.
    static func language(fromStoredValue value: String?) -> AppLanguage {
        AppLanguage(rawValue: value ?? "system") ?? .system
    }

    /// The specific-language bundle to look strings up in, or nil to fall
    /// back to Bundle.module's own (system-driven) resolution. English has
    /// no "en.lproj" folder — it's the development-language content, which
    /// SwiftPM/Foundation places in "Base.lproj" — so .en resolves there
    /// instead of a folder that doesn't exist.
    static func bundle(for language: AppLanguage) -> Bundle? {
        guard let identifier = language.localeIdentifier else { return nil }
        let folderName = identifier == "en" ? "Base" : identifier
        guard let path = Bundle.module.path(forResource: folderName, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return nil }
        return bundle
    }

    static func string(forKey key: String) -> String {
        string(forKey: key, language: language)
    }

    /// Explicit-language lookup is used by tests and exports that must be
    /// deterministic regardless of the test host's AppleLanguages setting.
    static func string(forKey key: String, language: AppLanguage) -> String {
        (bundle(for: language) ?? Bundle.module).localizedString(forKey: key, value: key, table: "Localizable")
    }
}

/// Looks up a localized string from the app's Localizable.strings
/// (Base/fr), honoring the user's in-app language override if one is set.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = LocalizationManager.string(forKey: key)
    if args.isEmpty { return format }
    return String(format: format, arguments: args)
}
