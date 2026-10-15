import Foundation

/// The interface languages (decision 0007): the first one macOS prefers among these, English
/// otherwise. French keeps its own tables; the others are looked up by key, or by the English text
/// for strings written in the code, and fall back to English when a translation is missing.
public enum UILanguage: String, CaseIterable, Sendable {
    case en, fr, de, es, it, ja

    public static func resolve(setting: String, preferred: [String] = Locale.preferredLanguages) -> UILanguage {
        if let forced = UILanguage(rawValue: setting) { return forced }
        for language in preferred {
            let code = String(language.prefix(2))
            if let match = UILanguage(rawValue: code) { return match }
        }
        return .en
    }

    /// The locale numbers, sizes and dates are written in.
    public var locale: Locale {
        switch self {
        case .en: Locale(identifier: "en_US")
        case .fr: Locale(identifier: "fr_FR")
        case .de: Locale(identifier: "de_DE")
        case .es: Locale(identifier: "es_ES")
        case .it: Locale(identifier: "it_IT")
        case .ja: Locale(identifier: "ja_JP")
        }
    }
}

public extension ProductCopy {
    /// The language of this run, set once at launch (from `CoreTendPreferences.language`).
    nonisolated(unsafe) static var current: UILanguage = .resolve(setting: CoreTendPreferences().language)

    /// The language a call means: French when `french` is set, otherwise the current language unless
    /// it is French (a caller passing `french: false` asks for the non-French text).
    static func language(french: Bool) -> UILanguage {
        if french { return .fr }
        return current == .fr ? .en : current
    }

    /// A string written in the code as a French/English pair. Other languages find their
    /// translation by the English text; `%1$@`-style placeholders are filled from `arguments`.
    static func inline(_ fr: String, _ en: String, french: Bool, _ arguments: CVarArg...) -> String {
        let language = language(french: french)
        let template: String
        switch language {
        case .fr: template = fr
        case .en: template = en
        default: template = inlineTranslations[language]?[en] ?? en
        }
        return arguments.isEmpty ? template : String(format: template, locale: language.locale, arguments: arguments)
    }

    /// Tables for the languages besides English and French, by key.
    static let keyedTranslations: [UILanguage: [String: String]] = [
        .de: ProductCopyGerman.keyed, .es: ProductCopySpanish.keyed, .it: ProductCopyItalian.keyed, .ja: ProductCopyJapanese.keyed
    ]

    /// Tables for the languages besides English and French, by English text.
    static let inlineTranslations: [UILanguage: [String: String]] = [
        .de: ProductCopyGerman.inline, .es: ProductCopySpanish.inline, .it: ProductCopyItalian.inline, .ja: ProductCopyJapanese.inline
    ]
}
