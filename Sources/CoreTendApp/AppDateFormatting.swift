// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// Dates rendered in the language the user chose inside CoreTend.
///
/// `Date.formatted(date:time:)` and every Foundation formatter follow
/// `Locale.current`, which is the *system* locale. CoreTend's in-app language
/// picker changes which string table `L()` reads and nothing else, so on an
/// English Mac with French selected the interface read French and every date in
/// it read English: "Déplacé vers la Corbeille · Feb 2, 2026".
///
/// Measured on a system set to `en_US`, launching with `-AppleLanguages "(fr)"`
/// does not move `Locale.current` either — it stays `en_US` — so nothing about
/// the process environment fixes this. The locale has to be passed explicitly,
/// which is what this type exists to do.
///
/// Every date the interface shows should go through here. A `.formatted(date:)`
/// call anywhere in CoreTendApp is a date that will be wrong for anyone whose
/// system language differs from their chosen app language.
enum AppDateFormatting {

    /// How much of a date to show. Named for intent rather than for the
    /// Foundation style it happens to map to, so call sites read as decisions.
    enum Style {
        /// "2 févr. 2026" — a date in a list, where the year still matters.
        case dayMonthYear
        /// "2 févr. 2026 à 14:03" — an audit record, where the time is evidence.
        case dayMonthYearWithTime
        /// "lundi 2 février 2026" — a section heading for one day's activity.
        case fullDay
        /// "14:03" — a row already sitting under a day heading, where
        /// repeating the date on every line would be noise. Only ever correct
        /// inside a view that groups by day; on its own it is ambiguous.
        case timeOnly
    }

    /// The locale to format in: the chosen app language, or the system's when
    /// the user has not overridden it.
    static func locale(for language: AppLanguage = LocalizationManager.language) -> Locale {
        language.localeIdentifier.map(Locale.init(identifier:)) ?? Locale.current
    }

    static func string(
        _ date: Date,
        style: Style,
        language: AppLanguage = LocalizationManager.language
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale(for: language)
        switch style {
        case .dayMonthYear:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        case .dayMonthYearWithTime:
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        case .fullDay:
            formatter.dateStyle = .full
            formatter.timeStyle = .none
        case .timeOnly:
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        }
        return formatter.string(from: date)
    }
}
